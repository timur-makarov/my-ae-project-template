#!/usr/bin/env bash
# stamp-check.sh — is the last verify stamp still evidence for this tree?
#
# Usage: scripts/stamp-check.sh
#
# Fresh = the last stamp exited 0, was recorded on a clean product tree, the
# product tree is clean now, and no product file changed between the stamp's
# HEAD and this HEAD. Tickets and journal files are not product files, so
# committing a critic report or a ticket edit keeps the stamp fresh.
#
# Exit 0 = fresh green stamp. Exit 1 = missing/stale/red.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

[ $# -eq 0 ] || { echo "usage: scripts/stamp-check.sh" >&2; exit 2; }

stamp="$(last_stamp)" || {
  echo "stamp-check: no verify stamp yet" >&2
  echo "FIX: scripts/verify.sh" >&2
  protocol STAMP_CHECK MISSING
  exit 1
}

exit_code="$(json_get "$stamp" exit)"
head="$(json_get "$stamp" head)"
dirty="$(json_get "$stamp" dirty)"

protocol STAMP_HEAD "$head"
protocol STAMP_EXIT "$exit_code"

if [ "$exit_code" != "0" ]; then
  echo "stamp-check: last verify run failed (exit=$exit_code)" >&2
  echo "FIX: fix the failing step, then scripts/verify.sh" >&2
  protocol STAMP_CHECK RED
  exit 1
fi
if [ "$dirty" != "false" ]; then
  echo "stamp-check: last verify ran with uncommitted product changes" >&2
  echo "FIX: commit, then scripts/verify.sh" >&2
  protocol STAMP_CHECK DIRTY
  exit 1
fi
if [ "$(is_dirty)" != "false" ]; then
  echo "stamp-check: product files changed since verify (uncommitted)" >&2
  echo "FIX: commit, then scripts/verify.sh" >&2
  protocol STAMP_CHECK TREE_DIRTY
  exit 1
fi
if ! product_same "$head"; then
  echo "stamp-check: product files changed since verify ran at $head" >&2
  echo "FIX: scripts/verify.sh" >&2
  protocol STAMP_CHECK STALE
  exit 1
fi

protocol STAMP_CHECK OK
exit 0
