#!/usr/bin/env bash
# stamp-check.sh — accept or reject a verify stamp against the current tree.
#
# Usage:
#   scripts/stamp-check.sh              # last stamp: exit 0, HEAD match, dirty=false
#   scripts/stamp-check.sh --baseline   # last stamp exists (baseline may be dirty)
#   scripts/stamp-check.sh --head SHA   # stamp head must equal SHA
#
# Exit 0 = fresh green stamp. Exit 1 = missing/stale/red.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

MODE="fresh"
WANT_HEAD=""
while [ $# -gt 0 ]; do
  case "$1" in
    --baseline) MODE="baseline"; shift ;;
    --head) WANT_HEAD="$2"; shift 2 ;;
    *) echo "usage: scripts/stamp-check.sh [--baseline] [--head SHA]" >&2; exit 2 ;;
  esac
done

stamp="$(last_stamp)" || { echo "stamp-check: no stamps in $JOURNAL/verify-stamps.jsonl" >&2; protocol STAMP_CHECK MISSING; exit 1; }

exit_code="$(json_get "$stamp" exit)"
head="$(json_get "$stamp" head)"
dirty="$(json_get "$stamp" dirty)"
ts="$(json_get "$stamp" ts)"

protocol STAMP_TS "$ts"
protocol STAMP_HEAD "$head"
protocol STAMP_DIRTY "$dirty"
protocol STAMP_EXIT "$exit_code"

if [ "$exit_code" != "0" ]; then
  echo "stamp-check: last stamp is not green (exit=$exit_code)" >&2
  protocol STAMP_CHECK RED
  exit 1
fi

if [ "$MODE" = "baseline" ]; then
  protocol STAMP_CHECK BASELINE_OK
  exit 0
fi

current="$(current_head)"
if [ -n "$WANT_HEAD" ]; then
  current="$WANT_HEAD"
fi
if [ "$head" != "$current" ]; then
  echo "stamp-check: stamp head $head != current $current" >&2
  protocol STAMP_CHECK HEAD_MISMATCH
  exit 1
fi
if [ "$dirty" != "false" ]; then
  echo "stamp-check: stamp recorded dirty=true; tree must be clean for a fresh stamp" >&2
  protocol STAMP_CHECK DIRTY
  exit 1
fi
if [ "$(is_dirty)" != "false" ]; then
  echo "stamp-check: working tree is dirty; re-run verify.sh on a clean tree" >&2
  protocol STAMP_CHECK TREE_DIRTY
  exit 1
fi

protocol STAMP_CHECK OK
exit 0
