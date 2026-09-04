#!/usr/bin/env bash
# protect.sh — preToolUse / beforeReadFile gate.
# Write|StrReplace|Delete|EditNotebook: worktree, secrets, enforcement, frozen scope.
# Read / beforeReadFile: secret/key paths only (not frozen-scope on ordinary files).
# Standalone: do not source lib.sh (failClosed must not depend on it).
set -u

input=$(cat)
ROOT="${AGENTIC_ROOT:-$(pwd)}"
if [ ! -d "$ROOT/.agentic" ] && command -v git >/dev/null 2>&1; then
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$ROOT")"
fi

allow() { echo '{"permission":"allow"}'; exit 0; }
deny() {
  local msg="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg a "$msg" '{permission:"deny", user_message:$a, agent_message:$a}'
  else
    printf '{"permission":"deny","user_message":"protect.sh requires jq","agent_message":"protect.sh requires jq (fail closed)"}\n'
  fi
  exit 0
}

if ! command -v jq >/dev/null 2>&1; then
  deny "protect.sh requires jq (fail closed)"
fi

tool="$(printf '%s' "$input" | jq -r '.tool_name // empty')"
event="$(printf '%s' "$input" | jq -r '.hook_event_name // empty')"
path="$(printf '%s' "$input" | jq -r '.tool_input.path // .tool_input.file_path // .tool_input.target_notebook // .file_path // empty')"

read_mode=0
write_mode=0
case "$tool" in
  Read) read_mode=1 ;;
  Write|StrReplace|Delete|EditNotebook) write_mode=1 ;;
esac
case "$event" in
  beforeReadFile) read_mode=1 ;;
esac
# beforeReadFile payloads often omit tool_name and use file_path.
if [ "$read_mode" -eq 0 ] && [ "$write_mode" -eq 0 ] && [ -n "$path" ]; then
  case "$event" in
    ""|beforeReadFile) read_mode=1 ;;
  esac
fi

if [ "$read_mode" -eq 0 ] && [ "$write_mode" -eq 0 ]; then
  allow
fi

[ -z "$path" ] && allow

rel="$path"
case "$path" in
  "$ROOT"/*) rel="${path#$ROOT/}" ;;
esac
rel="${rel#./}"

strict="$(awk '/^scope:/{inb=1;next} inb && /^[^[:space:]#]/{inb=0} inb && /strict:/{print $2; exit}' "$ROOT/.agentic/config.yml" 2>/dev/null || echo false)"

tier=""
nn=""
if [ -f "$ROOT/.agentic/state/active-ticket" ]; then
  nn="$(tr -d '[:space:]' < "$ROOT/.agentic/state/active-ticket")"
fi
if [ -n "$nn" ]; then
  tfile="$(ls "$ROOT/.agentic/tickets/open/$nn"-*.md "$ROOT/.agentic/tickets/closed/$nn"-*.md 2>/dev/null | head -1)"
  [ -n "$tfile" ] && tier="$(awk '/^risk_tier:/{print $2; exit}' "$tfile")"
fi

in_scope() {
  local scope="$ROOT/.agentic/state/scope-$nn.txt" g
  [ -n "$nn" ] && [ -f "$scope" ] || return 1
  while IFS= read -r g || [ -n "$g" ]; do
    [ -z "$g" ] && continue
    case "$g" in \#*) continue ;; esac
    if command -v python3 >/dev/null 2>&1; then
      python3 -c '
import fnmatch, sys
p, g = sys.argv[1], sys.argv[2]
ok = fnmatch.fnmatch(p, g)
if g.endswith("/**"):
    prefix = g[:-3]
    if p == prefix or p.startswith(prefix + "/"):
        ok = True
sys.exit(0 if ok else 1)
' "$rel" "$g" && return 0
    else
      case "$rel" in $g) return 0 ;; esac
    fi
  done < "$scope"
  return 1
}

is_example_env() {
  case "$rel" in
    .env.example|.env.sample|.env.template|*.env.example) return 0 ;;
  esac
  return 1
}

deny_secret() {
  if is_example_env; then
    return 1
  fi
  case "$rel" in
    .env|.env.*|*.pem|*.p12|*.pfx|id_rsa|id_rsa.pub|id_ed25519|id_ed25519.pub|*.key|**/credentials.json|**/secrets.yaml)
      if [ "$tier" = "HIGH" ] && in_scope; then
        return 1
      fi
      deny "Blocked: secret/key path '$rel' is file-tool-denied unless a HIGH ticket lists it in frozen scope."
      ;;
  esac
  return 1
}

# Read / beforeReadFile: secrets only. Do not apply frozen-scope to ordinary files.
if [ "$read_mode" -eq 1 ]; then
  deny_secret
  allow
fi

# Writes outside the worktree (except TMPDIR) are a common over-eager move.
tmp="${TMPDIR:-/tmp}"
tmp="${tmp%/}"
case "$path" in
  "$ROOT"/*|"$tmp"/*|/tmp/*|/var/tmp/*|/dev/null) ;;
  /*)
    deny "Blocked: file-tool path '$path' is outside the worktree. Agents may only write inside the repo (or TMPDIR)."
    ;;
esac

deny_secret

# Frozen scope file: only gate.sh implement (or HIGH+in-scope) may write it.
case "$rel" in
  .agentic/state/scope-*.txt)
    if [ "$tier" = "HIGH" ] && in_scope; then
      allow
    fi
    deny "Blocked: frozen scope file '$rel' is file-tool-denied. Rewrite it via scripts/gate.sh implement (or a HIGH ticket that lists it in scope)."
    ;;
esac

# Append-only audit history: file tools cannot mutate.
case "$rel" in
  .agentic/tickets/closed/*)
    deny "Blocked: tickets/closed/ is append-only. Close via gate.sh archive (close-authorization token)."
    ;;
  .agentic/journal/actions-*.jsonl|.agentic/journal/verify-stamps.jsonl|.agentic/journal/metrics.jsonl|.agentic/journal/lessons.md)
    deny "Blocked: journal audit files are append-only via shell >> ."
    ;;
esac

enforcement=0
case "$rel" in
  .cursor/*|scripts/*|.agentic/templates/*|.agentic/config.yml|.agentic/state/enforcement.sha256|.github/workflows/*)
    enforcement=1
    ;;
esac

if [ "$enforcement" -eq 1 ]; then
  if [ "$tier" = "HIGH" ] && in_scope; then
    allow
  fi
  deny "Blocked: enforcement-layer path '$rel' is file-tool-denied unless a HIGH ticket has it in the frozen scope. Open a HIGH ticket or edit via a scoped session."
fi

if [ -n "$nn" ] && [ -f "$ROOT/.agentic/state/scope-$nn.txt" ]; then
  in_scope || deny "Blocked: '$rel' is outside frozen scope for ticket $nn. Widen scope with a Ruling: and rewrite .agentic/state/scope-$nn.txt."
  allow
fi

if [ "$strict" = "true" ]; then
  deny "Blocked: scope.strict is true and no active scope file exists. Create a ticket and run gate.sh implement before editing."
fi

allow
