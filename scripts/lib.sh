#!/usr/bin/env bash
# lib.sh — shared helpers for agentic scripts (NOT sourced by hooks).
# Scripts: source "$(dirname "$0")/lib.sh"
[ -n "${AGENTIC_LIB_SOURCED:-}" ] && return 0
AGENTIC_LIB_SOURCED=1

if [ -n "${AGENTIC_ROOT:-}" ]; then
  ROOT="$AGENTIC_ROOT"
else
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

CONFIG="${AGENTIC_CONFIG:-$ROOT/.agentic/config.yml}"
JOURNAL="$ROOT/.agentic/journal"
STATE="$ROOT/.agentic/state"
TICKETS_OPEN="$ROOT/.agentic/tickets/open"
TICKETS_CLOSED="$ROOT/.agentic/tickets/closed"

# Human-written records. Editing them never makes evidence stale.
NON_PRODUCT=(':(exclude).agentic/tickets' ':(exclude).agentic/journal')

protocol() { printf '%s: %s\n' "$1" "$2"; }

die() { echo "$1" >&2; exit "${2:-1}"; }

has_git() { git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; }

current_head() {
  git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo "unborn"
}

# Branch name; in a detached CI checkout, the PR head ref.
current_branch() {
  local b
  b="$(git -C "$ROOT" branch --show-current 2>/dev/null || true)"
  [ -z "$b" ] && b="${GITHUB_HEAD_REF:-}"
  printf '%s' "$b"
}

# "true" when a product file (anything outside tickets/ and journal/) is
# modified or untracked.
is_dirty() {
  if ! has_git; then echo true; return; fi
  if [ -n "$(git -C "$ROOT" status --porcelain --untracked-files=all -- . "${NON_PRODUCT[@]}" 2>/dev/null)" ]; then
    echo true
  else
    echo false
  fi
}

# Exit 0 when no product file differs between SHA and HEAD.
product_same() {
  local sha="$1"
  [ -n "$sha" ] && [ "$sha" != "unborn" ] || return 1
  git -C "$ROOT" diff --quiet "$sha" HEAD -- . "${NON_PRODUCT[@]}" 2>/dev/null
}

# Evidence recorded at HEAD=$1 with dirty=$2 still describes the tree.
evidence_fresh() {
  local head="$1" dirty="$2"
  [ "$dirty" = "false" ] || return 1
  [ "$(is_dirty)" = "false" ] || return 1
  product_same "$head"
}

# Changes whenever anything in the worktree changes (committed or not).
worktree_fp() {
  {
    git -C "$ROOT" rev-parse HEAD 2>/dev/null
    git -C "$ROOT" diff HEAD --binary 2>/dev/null
    git -C "$ROOT" ls-files -o --exclude-standard 2>/dev/null | while IFS= read -r f; do
      printf '%s ' "$f"
      git -C "$ROOT" hash-object "$f" 2>/dev/null
    done
  } | git hash-object --stdin
}

sha_text() { git hash-object --stdin; }
sha_file() { git hash-object "$1" 2>/dev/null || echo none; }

base_branch() {
  local b
  b="$(config_get "base_branch")"
  printf '%s' "${b:-main}"
}

# The ref to diff against: base_branch, else origin/base_branch.
# Empty when neither resolves (callers decide; in CI that is a failure).
base_ref() {
  local base cand
  base="$(base_branch)"
  for cand in "$base" "origin/$base"; do
    if git -C "$ROOT" rev-parse --verify --quiet "$cand^{commit}" >/dev/null 2>&1; then
      printf '%s' "$cand"
      return 0
    fi
  done
  return 1
}

# Files changed since the merge-base with base, plus uncommitted and untracked.
# Without a base ref: uncommitted changes only (gate.sh merge_base_ok fails CI).
diff_files() {
  has_git || return 0
  local ref mb
  if ref="$(base_ref)"; then
    mb="$(git -C "$ROOT" merge-base "$ref" HEAD 2>/dev/null || true)"
  fi
  {
    if [ -n "${mb:-}" ]; then
      git -C "$ROOT" diff --name-only "$mb" 2>/dev/null
    else
      git -C "$ROOT" diff --name-only HEAD 2>/dev/null
    fi
    git -C "$ROOT" ls-files -o --exclude-standard 2>/dev/null
  } | sort -u
}

# diff_files without tickets/ and journal/.
product_diff_files() {
  diff_files | grep -v -E '^\.agentic/(tickets|journal)/' || true
}

# Scalar from config. Nested: "verify.test", "risk.low_fast_lane", "scope.strict".
# Top-level: "base_branch".
config_get() {
  local key="$1"
  awk -v key="$key" '
    BEGIN {
      n = split(key, parts, ".")
      if (n == 1) { top = key; subkey = "" }
      else { top = parts[1]; subkey = parts[2] }
    }
    # skip comments / empty
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    # top-level scalar
    n == 1 && $0 ~ "^" top ":" {
      line = $0
      sub(/^[^:]+:[[:space:]]*/, "", line)
      sub(/[[:space:]]*#.*$/, "", line)
      gsub(/^["'\'']|["'\'']$/, "", line)
      gsub(/[[:space:]]+$/, "", line)
      print line
      exit
    }
    n == 2 && $0 ~ "^" top ":" { inblock = 1; next }
    n == 2 && inblock && /^[^[:space:]#]/ { inblock = 0 }
    n == 2 && inblock {
      if ($0 ~ "^[[:space:]]+" subkey ":") {
        line = $0
        sub(/^[[:space:]]+[^:]+:[[:space:]]*/, "", line)
        sub(/[[:space:]]*#.*$/, "", line)
        gsub(/^["'\'']|["'\'']$/, "", line)
        gsub(/[[:space:]]+$/, "", line)
        print line
        exit
      }
    }
  ' "$CONFIG"
}

# List values under a top-level YAML key ("- item" lines).
config_list() {
  local key="$1"
  awk -v key="$key" '
    $0 ~ "^" key ":" { inb=1; next }
    inb && /^[^[:space:]#]/ { inb=0 }
    inb && /^[[:space:]]*-[[:space:]]*/ {
      line=$0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      sub(/[[:space:]]*#.*$/, "", line)
      gsub(/^["'\'']|["'\'']$/, "", line)
      print line
    }
  ' "$CONFIG"
}

# Emit glob<TAB>TIER for risk_paths: (quoted or bare keys).
config_risk_paths() {
  awk '
    /^risk_paths:/ { inblock = 1; next }
    inblock && /^[^[:space:]#]/ { inblock = 0 }
    inblock && /^[[:space:]]/ {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]*#.*$/, "", line)
      if (line ~ /^["'\'']/) {
        # "glob": TIER
        glob = line
        sub(/^["'\'']/, "", glob)
        sub(/["'\''].*$/, "", glob)
        tier = line
        sub(/^.*:[[:space:]]*/, "", tier)
        gsub(/[[:space:]]+$/, "", tier)
        if (glob != "" && tier != "") print glob "\t" tier
      } else if (line ~ /:/) {
        glob = line
        sub(/:.*$/, "", glob)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", glob)
        tier = line
        sub(/^[^:]+:[[:space:]]*/, "", tier)
        gsub(/[[:space:]]+$/, "", tier)
        if (glob != "" && tier != "") print glob "\t" tier
      }
    }
  ' "$CONFIG"
}

# First YAML front-matter block between --- lines.
ticket_yaml() {
  local file="$1" key="$2"
  awk -v key="$key" '
    /^---[[:space:]]*$/ { n++; if (n == 1) next; if (n >= 2) exit }
    n == 1 && $0 ~ "^" key ":" {
      line = $0
      sub(/^[^:]+:[[:space:]]*/, "", line)
      sub(/[[:space:]]*#.*$/, "", line)
      gsub(/^["'\'']|["'\'']$/, "", line)
      gsub(/[[:space:]]+$/, "", line)
      print line
      exit
    }
  ' "$file"
}

# List values under a YAML key (indented "- item" lines).
ticket_yaml_list() {
  local file="$1" key="$2"
  awk -v key="$key" '
    /^---[[:space:]]*$/ { n++; if (n == 1) next; if (n >= 2) exit }
    n == 1 && $0 ~ "^" key ":" { inlist = 1; next }
    n == 1 && inlist && /^[a-z_]+:/ { inlist = 0 }
    n == 1 && inlist && /^[[:space:]]*-[[:space:]]*/ {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      gsub(/^["'\'']|["'\'']$/, "", line)
      print line
    }
  ' "$file"
}

# Rewrite one front-matter scalar in place.
ticket_set() {
  local file="$1" key="$2" val="$3" tmp
  tmp="$(mktemp)"
  awk -v key="$key" -v val="$val" '
    /^---[[:space:]]*$/ { n++ }
    n == 1 && !done && $0 ~ "^" key ":" { print key ": " val; done = 1; next }
    { print }
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

# Done Contract Check: commands, one per line, backticks stripped.
dc_checks() {
  awk '/^## Done Contract/{inb=1;next} /^## /{inb=0} inb && /Check:/ {print}' "$1" \
    | while IFS= read -r line; do
        cmd="${line#*Check:}"
        case "$cmd" in *\`*\`*) cmd="$(printf '%s' "$cmd" | sed -E 's/^[^`]*`([^`]*)`.*/\1/')" ;; esac
        cmd="$(printf '%s' "$cmd" | tr -d '`' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -n "$cmd" ] && printf '%s\n' "$cmd"
      done
}

dc_assertion_count() {
  awk '/^## Done Contract/{inb=1;next} /^## /{inb=0} inb && /^[0-9]+\./{c++} END{print c+0}' "$1"
}

ticket_file() {
  local nn="$1" f
  for f in "$TICKETS_OPEN"/"$nn"-*.md "$TICKETS_CLOSED"/"$nn"-*.md; do
    [ -f "$f" ] || continue
    echo "$f"
    return 0
  done
  return 1
}

ticket_title() {
  grep -m1 '^# Ticket' "$1" | sed -E 's/^# Ticket [0-9]+[[:space:]]*[—-]+[[:space:]]*//'
}

nn_pad() {
  printf '%02d' "$((10#$1))"
}

# NN of the ticket branch this worktree is on (empty off a ticket branch).
branch_nn() {
  local prefix b n
  prefix="$(config_get branch_prefix)"
  [ -z "$prefix" ] && prefix="ticket/"
  b="$(current_branch)"
  case "$b" in
    "$prefix"[0-9]*) ;;
    *) return 0 ;;
  esac
  n="${b#"$prefix"}"
  n="${n%%-*}"
  case "$n" in
    ''|*[!0-9]*) return 0 ;;
  esac
  nn_pad "$n"
}

tier_rank() {
  case "$1" in
    LOW) echo 1 ;;
    MEDIUM) echo 2 ;;
    HIGH) echo 3 ;;
    *) echo 0 ;;
  esac
}

# Gitignore-style glob vs relative path. python3 stdlib; bash fallback.
glob_match() {
  local path="$1" glob="$2"
  if command -v python3 >/dev/null 2>&1; then
    python3 -c '
import fnmatch, sys
p, g = sys.argv[1], sys.argv[2]
candidates = [g]
if not g.startswith("**/") and "/" not in g.rstrip("*"):
    candidates.append("**/" + g)
ok = any(fnmatch.fnmatch(p, c) or fnmatch.fnmatch(p.lstrip("./"), c) for c in candidates)
# also prefix form: dir/** matches dir and dir/foo
if g.endswith("/**"):
    prefix = g[:-3]
    if p == prefix or p.startswith(prefix + "/"):
        ok = True
sys.exit(0 if ok else 1)
' "$path" "$glob"
    return $?
  fi
  case "$path" in
    $glob) return 0 ;;
  esac
  if [ "${glob%/}" != "$glob" ] || [ "${glob%"/**"}" != "$glob" ]; then
    local prefix="${glob%/\*\*}"
    prefix="${prefix%/}"
    case "$path" in
      "$prefix"|"$prefix"/*) return 0 ;;
    esac
  fi
  return 1
}

path_in_scope() {
  local path="$1" scope_file="$2" g
  [ -f "$scope_file" ] || return 1
  while IFS= read -r g || [ -n "$g" ]; do
    [ -z "$g" ] && continue
    case "$g" in \#*) continue ;; esac
    glob_match "$path" "$g" && return 0
  done < "$scope_file"
  return 1
}

# Highest risk floor matching a relative path. Echoes LOW if none.
path_risk_floor() {
  local path="$1" glob tier best=1 best_name=LOW
  while IFS=$'\t' read -r glob tier; do
    [ -z "$glob" ] && continue
    if glob_match "$path" "$glob"; then
      local r
      r="$(tier_rank "$tier")"
      if [ "$r" -gt "$best" ]; then
        best="$r"
        best_name="$tier"
      fi
    fi
  done < <(config_risk_paths)
  echo "$best_name"
}

extract_test_count() {
  local text="$1"
  # pytest / unittest
  if printf '%s' "$text" | grep -Eq '[0-9]+ passed'; then
    printf '%s' "$text" | grep -Eo '[0-9]+ passed' | tail -1 | grep -Eo '[0-9]+'
    return
  fi
  # cargo
  if printf '%s' "$text" | grep -Eq 'test result:.*passed'; then
    printf '%s' "$text" | grep -Eo '[0-9]+ passed' | tail -1 | grep -Eo '[0-9]+'
    return
  fi
  # selftest: "selftest: N passed"
  if printf '%s' "$text" | grep -Eq 'selftest: [0-9]+ passed'; then
    printf '%s' "$text" | grep -Eo 'selftest: [0-9]+ passed' | tail -1 | grep -Eo '[0-9]+'
    return
  fi
  echo "null"
}

metrics_append() {
  mkdir -p "$STATE"
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  # remaining args are JSON object body without braces: "stage":"pr","nn":"01"
  printf '{"ts":"%s",%s}\n' "$ts" "$1" >> "$STATE/metrics.jsonl"
}

last_stamp() {
  local f="$STATE/verify-stamps.jsonl"
  [ -f "$f" ] || return 1
  tail -1 "$f"
}

json_get() {
  local json="$1" key="$2"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$json" | jq -r --arg k "$key" '.[$k] | if type=="object" then tojson else . end'
  else
    python3 -c 'import json,sys; d=json.loads(sys.argv[1]); v=d.get(sys.argv[2]); print(json.dumps(v) if isinstance(v, (dict,list,bool)) or v is None else v)' "$json" "$key"
  fi
}

relpath_from() {
  local p="$1"
  case "$p" in
    "$ROOT"/*) echo "${p#"$ROOT"/}" ;;
    *) echo "$p" ;;
  esac
}

# Run each line of CMDS_FILE with bash -c under a timeout, in ROOT.
# Writes {"exit":N,"head","dirty","key","results":[{"cmd","exit","secs","log"}]}
# to OUT_JSON. head/dirty describe the tree when the run started; KEY is an
# opaque caller value (e.g. a hash of the command list) that must still match.
# Prints one line per command; a failing command also prints its output tail.
run_commands() {
  local cmds_file="$1" out_json="$2" label="${3:-run}" key="${4:-}" timeout
  timeout="$(config_get limits.command_timeout_secs)"
  [ -z "$timeout" ] && timeout=900
  mkdir -p "$STATE/logs"
  python3 - "$cmds_file" "$out_json" "$label" "$timeout" "$ROOT" "$STATE/logs" \
    "$(current_head)" "$(is_dirty)" "$key" <<'PY'
import json, os, subprocess, sys, time
cmds_file, out_json, label, timeout, root, logdir, head, dirty, key = sys.argv[1:10]
timeout = int(timeout)
cmds = [l.rstrip("\n") for l in open(cmds_file) if l.strip()]
results, worst = [], 0
for i, cmd in enumerate(cmds):
    t0 = time.time()
    log = os.path.join(logdir, f"{label}-{i + 1}.log")
    try:
        p = subprocess.run(["bash", "-c", cmd], cwd=root, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, timeout=timeout)
        code, out = p.returncode, p.stdout.decode("utf-8", "replace")
    except subprocess.TimeoutExpired as e:
        code = 124
        out = (e.stdout or b"").decode("utf-8", "replace") + f"\n[timed out after {timeout}s]\n"
    secs = round(time.time() - t0, 1)
    open(log, "w").write(out)
    results.append({"cmd": cmd, "exit": code, "secs": secs, "log": log})
    if code == 0:
        print(f"{label}: ok   ({secs}s) {cmd}")
    else:
        worst = 1
        print(f"{label}: FAIL (exit {code}, {secs}s) {cmd}")
        tail = out.strip().splitlines()[-40:]
        for line in tail:
            print(f"    {line}")
        print(f"    full log: {log}")
if not cmds:
    worst = 1
    print(f"{label}: FAIL no commands to run")
json.dump({"exit": worst, "head": head, "dirty": dirty == "true", "key": key,
           "results": results}, open(out_json, "w"))
sys.exit(worst)
PY
}

# Last **Verdict:** line's enum value.
report_verdict() {
  awk '
    /^\*\*Verdict:\*\*/ || /^- \*\*Verdict:\*\*/ { last=$0 }
    END { print last }
  ' "$1" | grep -oE 'APPROVED|CHANGES_REQUESTED|REOPEN_REQUIRED' | head -1
}

# **Head:** <sha> — the commit the reviewer evaluated.
report_head() {
  grep -m1 -E '^(- )?\*\*Head:\*\*' "$1" 2>/dev/null | grep -oE '[0-9a-f]{7,40}' | head -1
}

# Commands from the report's ## Claims table (second column).
claim_commands() {
  awk '
    BEGIN { FS="|" }
    /^## Claims/ { in_table=1; next }
    in_table && /^## / { in_table=0 }
    in_table && /^\|/ {
      gsub(/\\\|/, "\001")
      if ($0 ~ /[Cc]laim/ && $0 ~ /[Cc]ommand/) next
      if ($0 ~ /^[|][-: |]+$/) next
      cmd=$3
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", cmd)
      gsub(/`/, "", cmd)
      gsub(/\001/, "|", cmd)
      if (cmd == "" || cmd == "command" || cmd ~ /^</) next
      print cmd
    }
  ' "$1"
}

# Added package names from lockfile diffs vs base...HEAD (stdout, one per line).
# If the parser finds nothing, callers keep the nonempty-list check only.
lockfile_added_names() {
  local repo="$1" base="$2"
  python3 - "$repo" "$base" <<'PY'
import re, subprocess, sys
repo, base = sys.argv[1], sys.argv[2]
try:
    diff = subprocess.check_output(
        ["git", "-C", repo, "diff", "--unified=0", f"{base}...HEAD"],
        text=True, stderr=subprocess.DEVNULL,
    )
except (subprocess.CalledProcessError, FileNotFoundError):
    sys.exit(0)
file = ""
seen = set()

def emit(name):
    if name and name not in seen:
        seen.add(name)
        print(name)

for line in diff.splitlines():
    if line.startswith("+++ "):
        rest = line[4:].strip()
        file = rest[2:] if rest.startswith("b/") else rest
        continue
    if not line.startswith("+") or line.startswith("+++"):
        continue
    t = line[1:]
    if file.endswith("package-lock.json"):
        m = re.search(r'"node_modules/(@[^"/]+/[^"/]+|[^"/]+)"', t)
        if m:
            emit(m.group(1))
    elif file.endswith("Cargo.lock") or file.endswith("poetry.lock") or file.endswith("uv.lock"):
        m = re.match(r'name = "([^"]+)"', t)
        if m:
            emit(m.group(1))
    elif file.endswith("go.sum"):
        m = re.match(r"(\S+)\s+v", t)
        if m:
            emit(m.group(1))
    elif "pnpm-lock" in file:
        m = re.search(r"/(@?[^@\s/]+(?:/[^@\s/]+)?)@", t)
        if m:
            emit(m.group(1))
    elif file.endswith("yarn.lock"):
        m = re.match(r'"?(@?[^@\s"]+)@', t)
        if m:
            emit(m.group(1))
    elif file.endswith("Gemfile.lock"):
        m = re.match(r"    (\S+) \(", t)
        if m:
            emit(m.group(1))
PY
}
