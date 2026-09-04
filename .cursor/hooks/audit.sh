#!/usr/bin/env bash
# audit.sh — append every agent shell command + exit code to the journal.
# Zero prompt cost, complete record. One JSONL file per day.
# Fails open (silently) if jq is unavailable or the journal dir is missing.

input=$(cat)

command -v jq >/dev/null 2>&1 || exit 0

ROOT="${AGENTIC_ROOT:-$(pwd)}"
if [ ! -d "$ROOT/.agentic" ] && command -v git >/dev/null 2>&1; then
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$ROOT")"
fi

JOURNAL="$ROOT/.agentic/journal"
[ -d "$JOURNAL" ] || exit 0

printf '%s' "$input" | jq -c \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{ ts: $ts, command: (.command // null), exit_code: (.exit_code // null), cwd: (.cwd // .working_directory // null) }' \
  >> "$JOURNAL/actions-$(date -u +%Y-%m-%d).jsonl" 2>/dev/null

exit 0
