#!/usr/bin/env bash
# lib.sh — shared helpers for agentic scripts (NOT sourced by failClosed hooks).
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

protocol() { printf '%s: %s\n' "$1" "$2"; }

die() { echo "$1" >&2; exit "${2:-1}"; }

has_git() { git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; }

current_head() {
  if has_git; then
    git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo "unborn"
  else
    echo "unborn"
  fi
}

is_dirty() {
  if has_git; then
    if [ -n "$(git -C "$ROOT" status --porcelain 2>/dev/null)" ]; then
      echo true
    else
      echo false
    fi
  else
    echo true
  fi
}

base_branch() { config_get "base_branch"; }

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

ticket_file() {
  local nn="$1" f
  for f in "$TICKETS_OPEN"/"$nn"-*.md "$TICKETS_CLOSED"/"$nn"-*.md; do
    [ -f "$f" ] || continue
    echo "$f"
    return 0
  done
  return 1
}

nn_pad() {
  printf '%02d' "$((10#$1))"
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
  mkdir -p "$JOURNAL"
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  # remaining args are JSON object body without braces: "stage":"pr","nn":"01"
  printf '{"ts":"%s",%s}\n' "$ts" "$1" >> "$JOURNAL/metrics.jsonl"
}

last_stamp() {
  local f="$JOURNAL/verify-stamps.jsonl"
  [ -f "$f" ] || return 1
  tail -1 "$f"
}

json_get() {
  local json="$1" key="$2"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$json" | jq -r --arg k "$key" '.[$k] | if type=="object" then tojson else . end'
  else
    python3 -c 'import json,sys; d=json.loads(sys.argv[1]); v=d.get(sys.argv[2]); print(v if not isinstance(v, (dict,list)) else json.dumps(v))' "$json" "$key"
  fi
}

active_nn() {
  local f="$STATE/active-ticket"
  [ -f "$f" ] && tr -d '[:space:]' < "$f"
}

legal_status_transition() {
  local from="$1" to="$2" key
  [ "$from" = "$to" ] && return 0
  # Use :: not > — bash 3.2 treats > in case patterns as redirection.
  key="${from}::${to}"
  case "$key" in
    open::in-progress|open::blocked-on-alignment) return 0 ;;
    blocked-on-alignment::open|blocked-on-alignment::in-progress) return 0 ;;
    in-progress::ready-for-critic|in-progress::ready-for-review|in-progress::blocked-on-alignment|in-progress::open) return 0 ;;
    ready-for-critic::ready-for-review|ready-for-critic::in-progress) return 0 ;;
    ready-for-review::closed|ready-for-review::in-progress) return 0 ;;
    *) return 1 ;;
  esac
}

relpath_from() {
  local p="$1"
  case "$p" in
    "$ROOT"/*) echo "${p#"$ROOT"/}" ;;
    /*) echo "$p" ;;
    *) echo "$p" ;;
  esac
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
