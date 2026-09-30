#!/usr/bin/env bash
# adapt.sh — run the Cursor-protocol hooks for Claude Code or Codex.
#
# Usage (from .claude/settings.json / .codex/hooks.json):
#   scripts/hooks/adapt.sh <claude|codex> <PreToolUse|PostToolUse|SessionStart|Stop>
#
# Translates the tool's hook payload into the Cursor shape the hooks speak,
# runs the hook, and translates the decision back. PreToolUse fails closed
# (exit 2 blocks the tool call in both tools); the other events fail open.
#
# "ask": Claude gets ask (its own prompt). Codex has no ask in hooks, so ask
# becomes allow and Codex's own layer — the workspace-write sandbox and the
# prompt rules in .codex/rules/ — decides, which keeps Codex no stricter than
# Cursor or Claude.
set -u

TOOL="${1:-}"
EVENT="${2:-}"
HOOKS="$(cd "$(dirname "$0")" && pwd)"

block() { echo "$1" >&2; exit 2; }
case "$TOOL" in claude|codex) ;; *) block "adapt.sh: unknown tool '$TOOL'" ;; esac

if ! command -v jq >/dev/null 2>&1; then
  [ "$EVENT" = "PreToolUse" ] && block "Blocked: agentic hooks require jq (fail closed). Install jq."
  exit 0
fi

input="$(cat)"
if [ "$EVENT" = "PreToolUse" ]; then
  trap 'block "Blocked: adapt.sh internal error (fail closed)."' ERR
fi
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
[ -n "$cwd" ] || cwd="$(pwd)"

# Cursor decision JSON -> this tool's PreToolUse output.
emit_decision() {
  local out="$1" perm msg
  perm="$(printf '%s' "$out" | jq -r '.permission // "deny"')"
  msg="$(printf '%s' "$out" | jq -r '.agent_message // .user_message // "blocked by agentic hook"')"
  case "$perm" in
    allow) exit 0 ;;
    ask)
      [ "$TOOL" = "codex" ] && exit 0
      jq -n --arg m "$msg" '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:"ask", permissionDecisionReason:$m}}'
      exit 0 ;;
    *)
      jq -n --arg m "$msg" '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:"deny", permissionDecisionReason:$m}}'
      exit 0 ;;
  esac
}

run_hook() {  # HOOK JSON -> Cursor decision JSON (deny on hook failure)
  local out
  out="$(printf '%s' "$2" | "$HOOKS/$1")" || out=""
  printf '%s' "$out" | jq -e .permission >/dev/null 2>&1 || out='{"permission":"deny","agent_message":"Blocked: hook '"$1"' failed (fail closed)."}'
  printf '%s' "$out"
}

file_check() {  # PATH [Read|Write]
  run_hook protect.sh "$(jq -n --arg p "$1" --arg t "$2" --arg c "$cwd" '{tool_name:$t, tool_input:{path:$p}, cwd:$c, source:"adapt"}')"
}

pre_tool_use() {
  local name out p
  name="$(printf '%s' "$input" | jq -r '.tool_name // empty')"
  case "$name" in
    Bash)
      emit_decision "$(run_hook guard.sh "$(printf '%s' "$input" | jq --arg c "$cwd" '{command: (.tool_input.command // ""), cwd:$c, source:"adapt"}')")" ;;
    Read)
      emit_decision "$(file_check "$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty')" Read)" ;;
    Edit|Write|MultiEdit|NotebookEdit)
      emit_decision "$(file_check "$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // .tool_input.path // empty')" Write)" ;;
    apply_patch)
      # Codex: tool_input.command is the patch text; check every file it touches.
      while IFS= read -r p; do
        [ -z "$p" ] && continue
        out="$(file_check "$p" Write)"
        [ "$(printf '%s' "$out" | jq -r .permission)" = "allow" ] || emit_decision "$out"
      done < <(printf '%s' "$input" | jq -r '.tool_input.command // .tool_input.patch // .tool_input.input // ""' \
        | sed -nE 's/^\*\*\* (Add|Update|Delete) File: (.*)$/\2/p; s/^\*\*\* Move to: (.*)$/\1/p')
      exit 0 ;;
    WebFetch|WebSearch|mcp__*)
      emit_decision "$(run_hook mcp-guard.sh "$(printf '%s' "$input" | jq --arg c "$cwd" '{tool_name:.tool_name, tool_input:.tool_input, cwd:$c, source:"adapt"}')")" ;;
    *) exit 0 ;;
  esac
}

case "$EVENT" in
  PreToolUse) pre_tool_use ;;
  PostToolUse)
    [ "$(printf '%s' "$input" | jq -r '.tool_name // empty')" = "Bash" ] || exit 0
    printf '%s' "$input" | jq --arg c "$cwd" --arg s "$TOOL" \
      '{command: .tool_input.command, exit_code: (.tool_response.exit_code // .tool_response.exitCode // null), cwd:$c, source:$s}' \
      | "$HOOKS/audit.sh" >/dev/null 2>&1
    exit 0 ;;
  SessionStart)
    ctx="$(printf '%s' "$input" | jq --arg c "$cwd" '{cwd:$c}' | "$HOOKS/session-start.sh" 2>/dev/null | jq -r '.additional_context // empty' 2>/dev/null)"
    jq -n --arg m "$ctx" '{hookSpecificOutput:{hookEventName:"SessionStart", additionalContext:$m}}'
    exit 0 ;;
  Stop)
    # No loop_count in these tools: count consecutive follow-ups in state.
    root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$cwd")"
    counter="$root/.agentic/state/stop-followups-$TOOL"
    n=0
    if [ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" = "true" ]; then
      n="$(cat "$counter" 2>/dev/null || echo 0)"
    fi
    out="$(jq -n --arg c "$cwd" --argjson n "$n" '{status:"completed", loop_count:$n, cwd:$c}' | "$HOOKS/stop.sh" 2>/dev/null)"
    msg="$(printf '%s' "$out" | jq -r '.followup_message // empty' 2>/dev/null)"
    if [ -n "$msg" ]; then
      mkdir -p "$(dirname "$counter")" 2>/dev/null && echo $((n + 1)) > "$counter"
      jq -n --arg m "$msg" '{decision:"block", reason:$m}'
    else
      echo '{}'
    fi
    exit 0 ;;
  *) exit 0 ;;
esac
