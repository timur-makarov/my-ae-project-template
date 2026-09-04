#!/usr/bin/env bash
# artifact-lint.sh — greppable contracts for critic reports, ledgers, resolutions, PR bodies.
#
# Usage:
#   scripts/artifact-lint.sh critic <file>
#   scripts/artifact-lint.sh ledger <file> <NN>
#   scripts/artifact-lint.sh resolution <ticket-file>
#   scripts/artifact-lint.sh pr-body <pr-body-file> <ledger-file>
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

fail=0
err() { echo "artifact-lint: $1" >&2; fail=1; }

lint_critic() {
  local f="$1"
  [ -f "$f" ] || { err "critic report not found: $f"; return; }
  local verdict
  verdict="$(grep -E '^\*\*Verdict:\*\*|^- \*\*Verdict:\*\*' "$f" | tail -1 | grep -oE 'APPROVED|CHANGES_REQUESTED|REOPEN_REQUIRED' | head -1)"
  if [ -z "$verdict" ]; then
    verdict="$(grep -oE 'APPROVED|CHANGES_REQUESTED|REOPEN_REQUIRED' "$f" | head -1)"
  fi
  case "$verdict" in
    APPROVED|CHANGES_REQUESTED|REOPEN_REQUIRED) ;;
    *) err "$f: verdict line missing or not in enum" ;;
  esac
  if ! grep -q 'Epicycle count' "$f"; then
    err "$f: missing epicycle count"
  fi
  if ! grep -q 'Watchlist' "$f"; then
    err "$f: missing watchlist"
  fi

  if grep -Eqi '[0-9]+[[:space:]]*(ms|ms\b|%|qps|rps)|\b(LCP|INP|CLS|TTFB)\b' "$f"; then
    if ! grep -Eqi 'measured|EXPLAIN ANALYZE|lighthouse|not measured' "$f"; then
      err "$f: numeric performance claim without measured/not measured (metric-honesty)"
    fi
  fi
  # Hostile-input table: skip header/separator; require non-empty command + output cells.
  # Rows look like: | ... | command | output | PASS/FAIL |
  local depth="standard"
  grep -q '`full`' "$f" && depth="full"
  awk -v depth="$depth" -v file="$f" '
    BEGIN { FS="|" }
    /Hostile input/ {
      in_table=1
      has_id = ($0 ~ /[[:space:]]ID[[:space:]]/)
      next
    }
    in_table && /^[|][-: ]+[|]/ { next }
    in_table && /^\|/ {
      if (has_id) { cmd=$4; out=$5 } else { cmd=$3; out=$4 }
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", cmd)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", out)
      rows++
      if (cmd == "" || out == "") {
        printf "artifact-lint: %s: hostile-input row %d has empty Command run or Pasted output\n", file, rows > "/dev/stderr"
        bad=1
      }
    }
    in_table && (/^$/ || /^\#\#/ || /^\*\*Findings/) { in_table=0 }
    END {
      need = (depth=="full") ? 4 : 2
      if (rows < need) {
        printf "artifact-lint: %s: hostile-input table has %d rows, %s depth requires >=%d\n", file, rows+0, depth, need > "/dev/stderr"
        bad=1
      }
      exit bad+0
    }
  ' "$f" || fail=1
}

lint_ledger() {
  local f="$1" nn="$2"
  [ -f "$f" ] || { err "ledger not found: $f"; return; }
  grep -q "^# Ledger — ticket $nn" "$f" || err "$f: first line must be '# Ledger — ticket $nn'"
  local cap
  cap="$(config_get "limits.fix_rounds_per_piece")"
  [ -z "$cap" ] && cap=5
  local k
  for k in $(grep -oE 'Piece [0-9]+: complete' "$f" | grep -oE '[0-9]+'); do
    grep -Eq "Piece $k: complete \(commits " "$f" || err "$f: Piece $k complete missing commit range"
    [ -f "$JOURNAL/$nn-piece-$k-brief.md" ] || err "$f: Piece $k complete but brief missing"
    [ -f "$JOURNAL/$nn-piece-$k-report.md" ] || err "$f: Piece $k complete but report missing"
    if ! ls "$JOURNAL/reviews/$nn-piece-$k"* >/dev/null 2>&1; then
      err "$f: Piece $k complete but review package journal/reviews/$nn-piece-$k* missing"
    fi
    local rounds
    rounds="$(grep -c "Piece $k: fix round" "$f" || true)"
    if [ "$rounds" -gt "$cap" ]; then
      err "$f: Piece $k has $rounds fix rounds (cap $cap)"
    fi
    if [ "$rounds" -ge "$cap" ]; then
      grep -q "Ruling:.*[Pp]iece $k" "$f" || err "$f: Piece $k at fix-round cap needs a Ruling:"
    fi
  done
  # Convergence: same finding ID on two consecutive rounds → need ADJUDICATE or CONVERGED.
  awk '
    /Finding F[0-9.]+/ {
      if (match($0, /Finding F[0-9.]+/)) {
        id = substr($0, RSTART, RLENGTH)
        seen[id]++
        if (seen[id] >= 2 && !adjudicated[id]) pending[id]=1
      }
    }
    /ADJUDICATE F[0-9.]+|CONVERGED F[0-9.]+/ {
      if (match($0, /F[0-9.]+/)) { id="Finding " substr($0, RSTART, RLENGTH); delete pending[id]; adjudicated[id]=1 }
    }
    END {
      for (id in pending) {
        printf "artifact-lint: repeated %s across rounds without ADJUDICATE/CONVERGED\n", id > "/dev/stderr"
        bad=1
      }
      exit bad+0
    }
  ' "$f" || fail=1
  if ! grep -qE '^Ruling:|^Rulings: none' "$f"; then
    err "$f: missing 'Ruling:' or explicit 'Rulings: none'"
  fi
}

lint_resolution() {
  local f="$1"
  [ -f "$f" ] || { err "ticket not found: $f"; return; }
  awk '/^## Resolution/{inb=1;next} inb && /^## /{inb=0} inb{print}' "$f" > /tmp/agentic-res-$$
  local res="/tmp/agentic-res-$$"
  if [ ! -s "$res" ]; then
    err "$f: empty Resolution"
    rm -f "$res"
    return
  fi
  grep -q 'Weakest premise' "$res" || err "$f: Resolution missing weakest-premise label"
  grep -q 'Flip condition' "$res" || err "$f: Resolution missing named flip condition"
  if grep -Eqi '\b(should|probably|likely|presumably|I believe|it seems)\b' "$res"; then
    err "$f: Resolution contains unhedged should/probably/likely (constitution sweep)"
  fi
  grep -qE 'Rulings: none|Ruling:' "$res" || err "$f: Resolution missing 'Rulings: none' or listed rulings"
  rm -f "$res"
}

lint_pr_body() {
  local body="$1" ledger="$2"
  [ -f "$body" ] || { err "PR body not found: $body"; return; }
  if [ ! -f "$ledger" ]; then
    grep -q 'Rulings: none' "$body" || err "$body: no ledger; PR body must say Rulings: none"
    return
  fi
  if grep -q '^Rulings: none' "$ledger" && ! grep -q '^Ruling:' "$ledger"; then
    return 0
  fi
  while IFS= read -r line; do
    local snippet
    snippet="$(printf '%s' "$line" | sed 's/^Ruling:[[:space:]]*//' | cut -c1-40)"
    [ -z "$snippet" ] && continue
    grep -Fq "$snippet" "$body" || err "$body: ledger ruling not surfaced: $snippet"
  done < <(grep '^Ruling:' "$ledger" || true)
}

KIND="${1:-}"
case "$KIND" in
  critic) lint_critic "${2:-}" ;;
  ledger) lint_ledger "${2:-}" "${3:-}" ;;
  resolution) lint_resolution "${2:-}" ;;
  pr-body) lint_pr_body "${2:-}" "${3:-}" ;;
  *) echo "usage: scripts/artifact-lint.sh critic|ledger|resolution|pr-body ..." >&2; exit 2 ;;
esac

if [ "$fail" -eq 0 ]; then
  echo "artifact-lint: OK ($KIND)"
fi
exit "$fail"
