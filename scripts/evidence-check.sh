#!/usr/bin/env bash
# evidence-check.sh — cross-check ticket claims against the audit journal.
#
# Usage: scripts/evidence-check.sh NN [--tdd COMMAND] [--require-journal] [--hostile FILE]
#   - Every fenced command in piece reports / critic report that looks like
#     evidence must appear in actions-*.jsonl (when the journal has entries).
#   - --tdd COMMAND: the command appears with exit != 0 before exit 0.
#   - --require-journal: fail if actions-*.jsonl is missing or empty.
#   - --hostile FILE: each critic hostile-row Command run must appear in the journal.
#   - Verify stamp timestamp must postdate the last commit on the branch.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

if [ $# -lt 1 ]; then
  echo "usage: scripts/evidence-check.sh NN [--tdd COMMAND] [--require-journal] [--hostile FILE]" >&2
  exit 2
fi
NN="$(nn_pad "$1")"; shift
TDD_CMD=""
REQUIRE_JOURNAL=0
HOSTILE_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tdd) TDD_CMD="${2:-}"; shift 2 ;;
    --require-journal) REQUIRE_JOURNAL=1; shift ;;
    --hostile) HOSTILE_FILE="${2:-}"; shift 2 ;;
    *) echo "usage: scripts/evidence-check.sh NN [--tdd COMMAND] [--require-journal] [--hostile FILE]" >&2; exit 2 ;;
  esac
done

fail=0
err() { echo "evidence-check: $1" >&2; fail=1; }

journal_files() {
  ls -1 "$JOURNAL"/actions-*.jsonl 2>/dev/null || true
}

journal_nonempty() {
  local f
  for f in $(journal_files); do
    [ -f "$f" ] || continue
    [ -s "$f" ] && return 0
  done
  return 1
}

journal_has_command() {
  local needle="$1" want_exit="${2:-}"
  local f
  for f in $(journal_files); do
    [ -f "$f" ] || continue
    if [ -n "$want_exit" ]; then
      if command -v jq >/dev/null 2>&1; then
        jq -e --arg c "$needle" --argjson e "$want_exit" \
          'select((.command // "") | contains($c)) | select(.exit_code == $e)' "$f" >/dev/null 2>&1 && return 0
      else
        grep -q "$needle" "$f" && return 0
      fi
    else
      grep -Fq "$needle" "$f" && return 0
    fi
  done
  return 1
}

if [ "$REQUIRE_JOURNAL" -eq 1 ]; then
  if ! journal_nonempty; then
    err "audit journal missing or empty ($JOURNAL/actions-*.jsonl) — critic/pr cannot treat evidence as executed"
  fi
fi

if [ -n "$HOSTILE_FILE" ]; then
  [ -f "$HOSTILE_FILE" ] || err "hostile critic file not found: $HOSTILE_FILE"
  if [ -f "$HOSTILE_FILE" ]; then
    if ! journal_nonempty; then
      err "hostile rows require a non-empty audit journal"
    else
      while IFS= read -r hcmd; do
        [ -z "$hcmd" ] && continue
        case "$hcmd" in *'<'*|*'['*|PASS|FAIL) continue ;; esac
        if ! journal_has_command "$hcmd"; then
          err "hostile Command run not in audit journal: $hcmd"
        fi
      done < <(awk '
        BEGIN { FS="|" }
        /Hostile input/ {
          in_table=1
          has_id = ($0 ~ /[[:space:]]ID[[:space:]]/)
          next
        }
        in_table && /^[|][-: ]+[|]/ { next }
        in_table && /^\|/ {
          if (has_id) { cmd=$4 } else { cmd=$3 }
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", cmd)
          if (cmd != "" && cmd != "Command run") print cmd
        }
        in_table && (/^$/ || /^##/ || /^\*\*Findings/) { in_table=0 }
      ' "$HOSTILE_FILE")
    fi
  fi
fi

# TDD: RED before GREEN for a command substring.
if [ -n "$TDD_CMD" ]; then
  found_red=0
  found_green_after=0
  for f in $(journal_files); do
    [ -f "$f" ] || continue
    if command -v jq >/dev/null 2>&1; then
      while IFS=$'\t' read -r ts code; do
        if [ "$found_red" -eq 0 ] && [ "$code" != "0" ] && [ "$code" != "null" ]; then
          found_red=1
          continue
        fi
        if [ "$found_red" -eq 1 ] && [ "$code" = "0" ]; then
          found_green_after=1
        fi
      done < <(jq -r --arg c "$TDD_CMD" 'select((.command // "") | contains($c)) | [.ts, (.exit_code|tostring)] | @tsv' "$f")
    fi
  done
  if [ "$found_red" -eq 0 ]; then
    err "TDD sequence: no failing run of '$TDD_CMD' in the audit journal (RED never happened)"
  elif [ "$found_green_after" -eq 0 ]; then
    err "TDD sequence: '$TDD_CMD' failed but never later succeeded"
  fi
fi

# Quoted evidence commands from reports (lines starting with $ or inside ``` that look like scripts/).
for report in "$JOURNAL/$NN"-piece-*-report.md "$JOURNAL/$NN"-critic.md; do
  [ -f "$report" ] || continue
  while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue
    # skip placeholders
    case "$cmd" in *'<'*|*'['*) continue ;; esac
    if [ -z "$(journal_files)" ]; then
      echo "evidence-check: no audit journal yet; skipping command presence for $cmd" >&2
      continue
    fi
    if ! journal_has_command "$cmd"; then
      err "$(basename "$report"): quoted command not in audit journal: $cmd"
    fi
  done < <(awk '
    /^```/ { fence = !fence; next }
    fence && $0 ~ /scripts\/|pytest|cargo test|go test|npm test/ { print }
  ' "$report")
done

# Stamp must postdate last commit.
stamp="$(last_stamp || true)"
if [ -n "$stamp" ] && has_git; then
  stamp_ts="$(json_get "$stamp" ts)"
  commit_ts="$(git -C "$ROOT" log -1 --format=%cI 2>/dev/null || true)"
  if [ -n "$stamp_ts" ] && [ -n "$commit_ts" ]; then
    # normalize commit_ts to UTC-ish comparable strings
    stamp_epoch="$(date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$stamp_ts" +%s 2>/dev/null || date -u -d "$stamp_ts" +%s 2>/dev/null || echo 0)"
    commit_epoch="$(date -u -j -f '%Y-%m-%dT%H:%M:%S%z' "$(echo "$commit_ts" | sed 's/T/ /;s/+0000/Z/;s/Z//')" +%s 2>/dev/null \
      || date -u -d "$commit_ts" +%s 2>/dev/null || echo 0)"
    if [ "$stamp_epoch" -gt 0 ] && [ "$commit_epoch" -gt 0 ] && [ "$stamp_epoch" -lt "$commit_epoch" ]; then
      err "verify stamp ($stamp_ts) predates last commit ($commit_ts) — re-run verify.sh"
    fi
  fi
fi

if [ "$fail" -eq 0 ]; then
  echo "evidence-check: OK ($NN)"
  protocol EVIDENCE_CHECK OK
fi
exit "$fail"
