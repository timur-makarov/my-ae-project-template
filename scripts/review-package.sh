#!/usr/bin/env bash
# review-package.sh — bundle a git range into one file a reviewer/critic reads
# in a single pass, so the diff never enters the controller's context.
#
# Usage: scripts/review-package.sh BASE HEAD [LABEL]
#   BASE/HEAD: any git revisions. Record BASE before dispatching an implementer;
#   never use HEAD~1 for multi-commit work (it silently drops earlier commits).
#   LABEL: optional filename stem (default: <base7>-<head7>).
#
# Prints the path of the package it wrote. Package goes to .agentic/journal/reviews/.
set -eu

if [ $# -lt 2 ]; then
  echo "usage: scripts/review-package.sh BASE HEAD [LABEL]" >&2
  exit 2
fi

BASE="$1"; HEAD="$2"
git rev-parse --verify --quiet "$BASE^{commit}" >/dev/null || { echo "review-package: bad BASE '$BASE'" >&2; exit 2; }
git rev-parse --verify --quiet "$HEAD^{commit}" >/dev/null || { echo "review-package: bad HEAD '$HEAD'" >&2; exit 2; }

B7=$(git rev-parse --short=7 "$BASE")
H7=$(git rev-parse --short=7 "$HEAD")
LABEL="${3:-$B7-$H7}"

OUT_DIR=".agentic/journal/reviews"
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/$LABEL.md"

{
  echo "# Review package: $B7..$H7"
  echo
  echo "> READ-ONLY. Evaluate this package. Do not mutate the tree. Do not trust generator narrative."
  echo
  echo "## Commits"
  echo '```'
  git log --oneline "$BASE..$HEAD"
  echo '```'
  echo
  echo "## Stat"
  echo '```'
  git diff --stat "$BASE..$HEAD"
  echo '```'
  echo
  echo "## Full diff (-U10)"
  echo '```diff'
  git diff -U10 "$BASE..$HEAD"
  echo '```'
} > "$OUT"

echo "$OUT"
