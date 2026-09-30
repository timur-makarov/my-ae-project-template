#!/usr/bin/env bash
# protect.sh — file-tool guard (Cursor preToolUse / beforeReadFile protocol;
# Claude/Codex via adapt.sh).
#   Reads:  secret files (guard.secrets).
#   Writes: outside the repo and its worktrees; secrets; .agentic/state/**;
#           .agentic/tickets/closed/**. With a claimed ticket (branch ticket/NN-*
#           and a frozen scope): outside the scope, or above the ticket's tier.
#           With no claim and scope.strict: true: product files.
# Standalone: does not source scripts/lib.sh. Fails closed.
set -u

deny_raw() {
  printf '{"permission":"deny","user_message":"%s","agent_message":"%s"}\n' "$1" "$1"
  exit 0
}
command -v jq >/dev/null 2>&1 || deny_raw "Blocked: scripts/hooks/protect.sh requires jq (fail closed)."
command -v python3 >/dev/null 2>&1 || deny_raw "Blocked: scripts/hooks/protect.sh requires python3 (fail closed)."

input="$(cat)"
trap 'deny_raw "Blocked: protect.sh internal error (fail closed)."' ERR
tool="$(printf '%s' "$input" | jq -r '.tool_name // empty')"
event="$(printf '%s' "$input" | jq -r '.hook_event_name // empty')"
path="$(printf '%s' "$input" | jq -r '.tool_input.path // .tool_input.file_path // .tool_input.target_notebook // .tool_input.notebook_path // .file_path // empty')"
cwd="$(printf '%s' "$input" | jq -r '.cwd // .workspace_roots[0] // empty')"
trap - ERR

deny() { jq -n --arg m "$1" '{permission:"deny", user_message:$m, agent_message:$m}'; exit 0; }
ask() { jq -n --arg m "$1" '{permission:"ask", user_message:$m, agent_message:$m}'; exit 0; }
allow() { echo '{"permission":"allow"}'; exit 0; }

mode=""
case "$tool" in
  Read) mode=read ;;
  Write|StrReplace|Delete|EditNotebook|Edit|MultiEdit|NotebookEdit) mode=write ;;
esac
[ -z "$mode" ] && [ "$event" = "beforeReadFile" ] && mode=read
[ -z "$mode" ] && allow
[ -n "$path" ] || allow

[ -n "$cwd" ] && [ -d "$cwd" ] || cwd="$(pwd)"
case "$path" in /*) abs="$path" ;; *) abs="$cwd/$path" ;; esac
abs="$(python3 -c 'import os,sys; print(os.path.normpath(sys.argv[1]))' "$abs")"

# Nearest existing directory of the target decides which checkout it is in.
d="$(dirname "$abs")"
while [ ! -d "$d" ] && [ "$d" != "/" ]; do d="$(dirname "$d")"; done
case "$d/" in */.git/*) d="${d%%/.git/*}"; d="${d%/.git}" ;; esac
# Physical path (symlinks, ..), matching what git reports as the root.
if [ "$d" != "/" ] && dp="$(cd "$d" 2>/dev/null && pwd -P)"; then
  abs="$dp${abs#"$d"}"
  d="$dp"
fi
ws_root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$cwd")"
ROOT="$(git -C "$d" rev-parse --show-toplevel 2>/dev/null || true)"
CONFIG="${ROOT:-$ws_root}/.agentic/config.yml"

cfg() {
  awk -v top="$1" -v subk="$2" '
    $0 ~ "^" top ":" { inb=1; next }
    inb && /^[^[:space:]#]/ { inb=0 }
    inb && $0 ~ "^[[:space:]]+" subk ":" {
      line=$0
      sub(/^[[:space:]]+[^:]+:[[:space:]]*/, "", line)
      sub(/[[:space:]]*#.*$/, "", line)
      gsub(/^["'\'']|["'\'']$/, "", line)
      gsub(/[[:space:]]+$/, "", line)
      print line
      exit
    }
  ' "$CONFIG" 2>/dev/null
}

rel="$abs"
[ -n "$ROOT" ] && case "$abs" in "$ROOT"/*) rel="${abs#"$ROOT"/}" ;; esac
rel="${rel#./}"
base="$(basename "$rel")"

SECRETS="$(cfg guard secrets)"; [ -z "$SECRETS" ] && SECRETS=deny
is_secret() {
  case "$base" in
    .env.example|.env.sample|.env.template|*.env.example) return 1 ;;
    .env|.env.*|*.pem|*.p12|*.pfx|*.key|id_rsa|id_ed25519|id_ecdsa|credentials.json|secrets.yaml|secrets.yml|.netrc) return 0 ;;
  esac
  case "$abs" in */.aws/credentials|*/.kube/config|*/.ssh/*) return 0 ;; esac
  return 1
}
if is_secret && [ "$SECRETS" != "allow" ]; then
  [ "$SECRETS" = "ask" ] && ask "Secret file '$rel'. Confirm."
  deny "Blocked: '$rel' is a secret file (guard.secrets: $SECRETS). Use an .env.example for shape."
fi

[ "$mode" = "read" ] && allow

# --- writes ---------------------------------------------------------------------
same_repo() {
  [ -n "$ROOT" ] || return 1
  [ "$ROOT" = "$ws_root" ] && return 0
  local a b
  a="$(cd "$ROOT" && git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
  b="$(cd "$ws_root" && git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
  [ -n "$a" ] && [ "$a" = "$b" ]
}
if ! same_repo; then
  tmp="${TMPDIR:-/tmp}"; tmp="${tmp%/}"
  case "$abs" in
    "$tmp"/*|/tmp/*|/private/tmp/*|/var/folders/*|/private/var/folders/*|/dev/null) allow ;;
  esac
  deny "Blocked: '$abs' is outside this repo and its worktrees."
fi

case "$rel" in
  .agentic/state/*) deny "Blocked: .agentic/state/ is written only by scripts (gate.sh, verify.sh)." ;;
  .agentic/tickets/closed/*) deny "Blocked: closed tickets are history. To change shipped work, open a new ticket." ;;
  .git/*) deny "Blocked: edit .git/ through git commands, not file tools." ;;
esac

PREFIX="$(awk '/^branch_prefix:/{sub(/^[^:]+:[[:space:]]*/, ""); sub(/[[:space:]]*#.*$/, ""); gsub(/"/, ""); print; exit}' "$CONFIG" 2>/dev/null)"
[ -z "$PREFIX" ] && PREFIX="ticket/"
branch="$(git -C "$ROOT" branch --show-current 2>/dev/null || true)"
nn="$(printf '%s' "$branch" | sed -nE "s#^${PREFIX}0*([0-9]+)-.*#\1#p")"
[ -n "$nn" ] && nn="$(printf '%02d' "$((10#$nn))")"
scope="$ROOT/.agentic/state/scope-$nn.txt"

# ok | scope (outside the frozen scope) | floor:TIER (risk floor above the ticket tier)
scope_verdict() {
  python3 - "$@" <<'PY'
import fnmatch, re, sys
rel, scope, config, tier = sys.argv[1:5]
rank = {"LOW": 1, "MEDIUM": 2, "HIGH": 3}

def match(p, g):
    g = g.strip()
    if not g or g.startswith("#"):
        return False
    if g.endswith("/**") and (p == g[:-3] or p.startswith(g[:-3] + "/")):
        return True
    cands = [g] + ([] if g.startswith("**/") or "/" in g.rstrip("*") else ["**/" + g])
    return any(fnmatch.fnmatch(p, c) for c in cands)

if not any(match(rel, g) for g in open(scope)):
    print("scope")
    sys.exit()
floor, inblock = "LOW", False
for line in open(config):
    if line.startswith("risk_paths:"):
        inblock = True
        continue
    if inblock and re.match(r"^[^\s#]", line):
        break
    m = re.match(r'^\s+["\']?([^"\':]+)["\']?\s*:\s*(LOW|MEDIUM|HIGH)', line) if inblock else None
    if m and match(rel, m.group(1)) and rank[m.group(2)] > rank[floor]:
        floor = m.group(2)
print("ok" if rank[floor] <= rank.get(tier, 1) else "floor:" + floor)
PY
}

if [ -n "$nn" ] && [ -s "$scope" ]; then
  case "$rel" in .agentic/journal/*|.agentic/tickets/open/*) allow ;; esac
  tfile="$(ls "$ROOT/.agentic/tickets/open/$nn"-*.md 2>/dev/null | head -1)"
  tier="$(awk '/^risk_tier:/{print $2; exit}' "$tfile" 2>/dev/null)"
  verdict="$(scope_verdict "$rel" "$scope" "$CONFIG" "${tier:-LOW}")" || deny_raw "Blocked: protect.sh scope check failed (fail closed)."
  case "$verdict" in
    ok) allow ;;
    scope) deny "Blocked: '$rel' is outside ticket $nn's frozen scope. Revert the need, or add the glob to scope_paths and run scripts/gate.sh implement $nn --widen." ;;
    floor:*) deny "Blocked: '$rel' has risk floor ${verdict#floor:} above ticket $nn's tier ${tier:-?}. Re-tier the ticket (risk_tier) or leave the file alone." ;;
  esac
  deny_raw "Blocked: protect.sh unexpected verdict (fail closed)."
fi

if [ "$(cfg scope strict)" = "true" ]; then
  case "$rel" in .agentic/*) allow ;; esac
  while IFS= read -r g; do
    [ -z "$g" ] && continue
    python3 -c 'import fnmatch,sys; p,g=sys.argv[1:]; sys.exit(0 if fnmatch.fnmatch(p,g) or (g.endswith("/**") and (p==g[:-3] or p.startswith(g[:-3]+"/"))) else 1)' "$rel" "$g" && allow
  done < <(awk '/^ticketless_paths:/{inb=1; next} inb && /^[^[:space:]#]/{inb=0} inb && /^[[:space:]]*-/{sub(/^[[:space:]]*-[[:space:]]*/, ""); gsub(/["'\'']/, ""); print}' "$CONFIG" 2>/dev/null)
  deny "Blocked: no claimed ticket in this checkout (scope.strict: true). Claim one: scripts/gate.sh advance NN (or /agentic-task for new work)."
fi

allow
