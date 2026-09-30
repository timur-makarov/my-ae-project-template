#!/usr/bin/env bash
# stop.sh — when the agent stops while the railroad still has agent work
# (gate.sh next exits 1), send it back with the NEXT line, at most
# limits.stop_followups times per run (0 = never). Cursor stop protocol;
# Claude/Codex via adapt.sh. Fails open. Standalone.
set -u

input="$(cat)"
command -v jq >/dev/null 2>&1 || { echo '{}'; exit 0; }
status="$(printf '%s' "$input" | jq -r '.status // "completed"')"
loops="$(printf '%s' "$input" | jq -r '.loop_count // 0')"
cwd="$(printf '%s' "$input" | jq -r '.cwd // .workspace_roots[0] // empty')"
[ -n "$cwd" ] && [ -d "$cwd" ] || cwd="$(pwd)"
ROOT="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$cwd")"

limit="$(awk '/^limits:/{inb=1; next} inb && /^[^[:space:]#]/{inb=0} inb && /^[[:space:]]+stop_followups:/{sub(/.*:[[:space:]]*/, ""); sub(/[[:space:]]*#.*$/, ""); print; exit}' "$ROOT/.agentic/config.yml" 2>/dev/null)"
case "$limit" in ''|*[!0-9]*) limit=0 ;; esac

if [ "$status" != "completed" ] || [ "$limit" -eq 0 ] || [ "$loops" -ge "$limit" ] || [ ! -x "$ROOT/scripts/gate.sh" ]; then
  echo '{}'
  exit 0
fi

if next="$(cd "$ROOT" && ./scripts/gate.sh next 2>&1)"; then
  echo '{}'
  exit 0
fi
jq -n --arg m "The ticket is not done. scripts/gate.sh next says:
$next
Continue with NEXT. If you cannot (needs a human decision, missing access), stop and say exactly why." '{followup_message: $m}'
exit 0
