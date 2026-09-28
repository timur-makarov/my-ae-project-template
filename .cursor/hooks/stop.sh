#!/usr/bin/env bash
# stop.sh — observe-only. Warn if an active ticket has no fresh green stamp.
# hooks.json loop_limit: 0 — do not auto-reprompt.
set -u

input=$(cat)
ROOT="${AGENTIC_ROOT:-$(pwd)}"
if [ ! -d "$ROOT/.agentic" ] && command -v git >/dev/null 2>&1; then
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$ROOT")"
fi

here="$(cd "$(dirname "$0")" && pwd)"
stamp=""
if [ -x "$ROOT/scripts/stamp-check.sh" ]; then
  stamp="$ROOT/scripts/stamp-check.sh"
elif [ -x "$here/../../scripts/stamp-check.sh" ]; then
  stamp="$here/../../scripts/stamp-check.sh"
fi

warn=""
trek_ok=0
if [ -f "$ROOT/.agentic/state/active-ticket" ] && [ -f "$ROOT/.agentic/journal/trek.jsonl" ]; then
  nn="$(tr -d '[:space:]' < "$ROOT/.agentic/state/active-ticket")"
  head="unborn"
  if command -v git >/dev/null 2>&1; then
    head="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unborn)"
  fi
  if grep -F "\"nn\":\"$nn\"" "$ROOT/.agentic/journal/trek.jsonl" | grep -F "\"head\":\"$head\"" | grep -q '"exit":0'; then
    trek_ok=1
  fi
fi
if [ "$trek_ok" -eq 0 ] && [ -f "$ROOT/.agentic/state/active-ticket" ]; then
  if [ -n "$stamp" ]; then
    if ! AGENTIC_ROOT="$ROOT" "$stamp" >/dev/null 2>&1; then
      warn="Active ticket has no fresh green verify stamp for this HEAD. Run scripts/verify.sh before claiming done. (stop hook observe-only; not a follow-up loop.)"
    fi
  else
    warn="Active ticket has no fresh green verify stamp for this HEAD. Run scripts/verify.sh before claiming done. (stop hook observe-only; not a follow-up loop.)"
  fi
fi

if [ -n "$warn" ]; then
  echo "$warn" >&2
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg ctx "$warn" '{additional_context:$ctx}'
  else
    echo '{}'
  fi
else
  echo '{}'
fi
exit 0
