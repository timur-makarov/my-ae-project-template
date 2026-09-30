#!/usr/bin/env bash
# audit.sh — append every agent shell command to
# .agentic/state/actions-YYYY-MM-DD.jsonl (local, gitignored). Fails open.
# Cursor's afterShellExecution sends no exit code (duration instead);
# Claude/Codex send one via adapt.sh.
input="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0
cwd="$(printf '%s' "$input" | jq -r '.cwd // .workspace_roots[0] // empty' 2>/dev/null)"
[ -n "$cwd" ] && [ -d "$cwd" ] || cwd="$(pwd)"
ROOT="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$cwd")"
[ -d "$ROOT/.agentic" ] || exit 0
mkdir -p "$ROOT/.agentic/state" 2>/dev/null || exit 0
printf '%s' "$input" | jq -c --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg cwd "$cwd" \
  '{ts: $ts, command: (.command // null), exit_code: (.exit_code // null), duration_ms: (.duration // null), cwd: $cwd, source: (.source // "cursor")}' \
  >> "$ROOT/.agentic/state/actions-$(date -u +%Y-%m-%d).jsonl" 2>/dev/null
exit 0
