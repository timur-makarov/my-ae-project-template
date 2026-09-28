#!/usr/bin/env bash
# trek-log.sh — run the ticket's Check: commands, then floor-guard.
# The only command allowed to append .agentic/journal/trek.jsonl.
# Usage: scripts/trek-log.sh NN
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

if [ $# -lt 1 ]; then
  echo "usage: scripts/trek-log.sh NN" >&2
  exit 2
fi
NN="$(nn_pad "$1")"
TICKET="$(ticket_file "$NN" || true)"
[ -n "$TICKET" ] || { echo "trek-log: ticket $NN not found" >&2; exit 1; }

worst=0
ran=0
while IFS= read -r dcline; do
  payload="${dcline#*Check:}"
  payload="$(printf '%s' "$payload" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  cmd="$(printf '%s' "$payload" | tr -d '`')"
  [ -z "$cmd" ] && continue
  ran=1
  echo "trek-log: $cmd"
  bash -c "$cmd"
  code=$?
  if [ "$code" -ne 0 ]; then
    worst=1
    echo "trek-log: check exited $code" >&2
  fi
done < <(awk '/^## Done Contract/{inb=1;next} /^## /{inb=0} inb && /Check:/ {print}' "$TICKET")

if [ "$ran" -eq 0 ]; then
  echo "trek-log: no Check: command in $TICKET" >&2
  worst=1
fi

"$SCRIPT_DIR/floor-guard.sh" || worst=1

mkdir -p "$JOURNAL"
head="$(current_head)"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '{"nn":"%s","head":"%s","exit":%s,"ts":"%s"}\n' "$NN" "$head" "$worst" "$ts" >> "$JOURNAL/trek.jsonl"
echo "trek-log: exit $worst head $head"
exit "$worst"
