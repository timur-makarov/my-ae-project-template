#!/usr/bin/env bash
# task-guard.sh — spawning a subagent asks. The fast lane does not dispatch one.
set -u
input=$(cat)
msg="Spawn a subagent?"
if command -v jq >/dev/null 2>&1; then
  jq -n --arg m "$msg" '{permission:"ask", user_message:$m, agent_message:$m}'
else
  printf '{"permission":"ask","user_message":"%s","agent_message":"%s"}\n' "$msg" "$msg"
fi
exit 0
