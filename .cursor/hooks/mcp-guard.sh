#!/usr/bin/env bash
# mcp-guard.sh — beforeMCPExecution + preToolUse WebFetch|WebSearch.
# Same network: budget as guard.sh. Standalone: do not source lib.sh.
set -u

input=$(cat)
ROOT="${AGENTIC_ROOT:-$(pwd)}"
if [ ! -d "$ROOT/.agentic" ] && command -v git >/dev/null 2>&1; then
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$ROOT")"
fi

deny() {
  jq -n --arg u "$1" --arg a "$1" '{ permission: "deny", user_message: $u, agent_message: $a }'
  exit 0
}
ask() {
  jq -n --arg u "$1" --arg a "$1" '{ permission: "ask", user_message: $u, agent_message: $a }'
  exit 0
}
allow() { echo '{ "permission": "allow" }'; exit 0; }

if ! command -v jq >/dev/null 2>&1; then
  printf '{"permission":"deny","user_message":"mcp-guard.sh requires jq (fail closed)","agent_message":"mcp-guard.sh requires jq (fail closed)"}\n'
  exit 0
fi

cfg() {
  local top="$1" sub="$2" val=""
  val="$(awk -v top="$top" -v subk="$sub" '
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
  ' "$ROOT/.agentic/config.yml" 2>/dev/null)"
  printf '%s' "$val"
}

ticket_field() {
  local key="$1" tfile="$2"
  [ -f "$tfile" ] || return 0
  awk -v key="$key" '
    /^---[[:space:]]*$/ { n++; if (n==1) next; if (n>=2) exit }
    n==1 && $0 ~ "^" key ":" {
      line=$0
      sub(/^[^:]+:[[:space:]]*/, "", line)
      sub(/[[:space:]]*#.*$/, "", line)
      gsub(/^["'\'']|["'\'']$/, "", line)
      print line
      exit
    }
  ' "$tfile"
}

nn=""
[ -f "$ROOT/.agentic/state/active-ticket" ] && nn="$(tr -d '[:space:]' < "$ROOT/.agentic/state/active-ticket")"
tfile=""
if [ -n "$nn" ]; then
  tfile="$(ls "$ROOT/.agentic/tickets/open/$nn"-*.md "$ROOT/.agentic/tickets/closed/$nn"-*.md 2>/dev/null | head -1)"
fi

NETWORK="$(cfg guard network)"
[ -z "$NETWORK" ] && NETWORK="ask"
META="$(cfg guard metadata)"
[ -z "$META" ] && META="deny"

tool="$(printf '%s' "$input" | jq -r '.tool_name // empty')"
blob="$(printf '%s' "$input" | jq -r '
  (.url // .mcp_server_url // empty),
  (if (.tool_input | type) == "object" then
      (.tool_input.url // .tool_input.uri // empty)
    elif (.tool_input | type) == "string" then
      .tool_input
    else empty end)
' | tr '\n' ' ')"

is_localhost_url() {
  printf '%s' "$1" | grep -Eqi '(localhost|127\.0\.0\.1|::1|0\.0\.0\.0)'
}

if [ "$META" != "allow" ]; then
  if printf '%s' "$blob $tool" | grep -Eq '169\.254\.169\.254|metadata\.google\.internal|instance-data|fd00:ec2::254'; then
    if [ "$META" = "deny" ]; then
      deny "Blocked: cloud-metadata / link-local probe (169.254.169.254)."
    else
      ask "Cloud-metadata address in MCP/WebFetch. Confirm this is intended."
    fi
  fi
fi

remote=0
printf '%s' "$tool" | grep -Eqi 'webfetch|websearch|web_fetch|web_search' && remote=1

urls="$(printf '%s' "$blob" | grep -Eo '(https?|ftp)://[^[:space:]\"'\'']+' || true)"
if [ -n "$urls" ]; then
  remote=0
  while IFS= read -r u; do
    [ -z "$u" ] && continue
    is_localhost_url "$u" || remote=1
  done <<< "$urls"
fi

printf '%s' "$tool" | grep -Eqi 'websearch|web_search' && remote=1

if [ "$remote" -eq 1 ] && [ "$NETWORK" != "allow" ]; then
  if [ "$NETWORK" = "none" ] || [ "$NETWORK" = "deny" ]; then
    deny "Blocked: ticket/config network=$NETWORK forbids remote fetch (WebFetch/WebSearch/MCP)."
  else
    ask "Remote fetch via WebFetch/WebSearch/MCP. Confirm the host is intended and the response will be treated as untrusted data."
  fi
fi

allow
