#!/usr/bin/env bash
# debt-lint.sh — every PONYTAIL: marker must name a ticket or ADR.
#
# Usage: scripts/debt-lint.sh [path ...]
#   Default: scan the repo (excluding .git, .worktrees, gstack).
#   Valid: PONYTAIL(01): ...   PONYTAIL(adr-0003): ...
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

PATHS=("$@")
if [ ${#PATHS[@]} -eq 0 ]; then
  PATHS=("$ROOT")
fi

fail=0
hits="$(grep -RIn --exclude-dir=.git --exclude-dir=.worktrees --exclude-dir=gstack \
  --exclude='*.jsonl' --exclude='analysis.md' --exclude='README.md' \
  --exclude='selftest.sh' --exclude='debt-lint.sh' --exclude='*.md' \
  -E 'PONYTAIL(\(|:)' "${PATHS[@]}" 2>/dev/null || true)"

if [ -z "$hits" ]; then
  echo "debt-lint: OK (no markers)"
  exit 0
fi

while IFS= read -r line; do
  [ -z "$line" ] && continue
  file="${line%%:*}"
  rest="${line#*:}"
  rest="${rest#*:}"
  if printf '%s' "$rest" | grep -Eq 'PONYTAIL\((adr-[0-9]+|[0-9]+)\)'; then
    id="$(printf '%s' "$rest" | grep -oE 'PONYTAIL\((adr-[0-9]+|[0-9]+)\)' | head -1 | sed 's/PONYTAIL(//;s/)//')"
    case "$id" in
      adr-*)
        found="$(find "$ROOT/.agentic/context/adr" -name "${id}-*.md" -o -name "${id}.md" 2>/dev/null | head -1)"
        if [ -z "$found" ]; then
          echo "debt-lint: $file: orphan PONYTAIL($id) — no matching ADR" >&2
          fail=1
        fi
        ;;
      *)
        if ! ticket_file "$(nn_pad "$id")" >/dev/null 2>&1; then
          echo "debt-lint: $file: orphan PONYTAIL($id) — no matching ticket" >&2
          fail=1
        fi
        ;;
    esac
  elif printf '%s' "$rest" | grep -q 'PONYTAIL:'; then
    echo "debt-lint: $file: PONYTAIL: marker missing ticket/ADR id — use PONYTAIL(NN): or PONYTAIL(adr-NNNN):" >&2
    fail=1
  fi
done <<< "$hits"

if [ "$fail" -eq 0 ]; then
  echo "debt-lint: OK"
fi
exit "$fail"
