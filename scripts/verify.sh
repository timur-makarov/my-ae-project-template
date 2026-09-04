#!/usr/bin/env bash
# verify.sh — run the project's verification gate from .agentic/config.yml.
#
# Usage: scripts/verify.sh [--e2e]
#   Runs verify.test, verify.lint, verify.typecheck in order (skipping empty ones).
#   With --e2e, also runs verify.e2e last.
#   Fails on the first non-zero exit and prints exactly which step died.
#   Every run appends a stamp to .agentic/journal/verify-stamps.jsonl.
#
# Protocol lines: VERIFY, HEAD, DIRTY, EXIT, STAMP
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

if [ ! -f "$CONFIG" ]; then
  echo "verify: config not found at $CONFIG" >&2
  exit 2
fi

verify_cmd() { config_get "verify.$1"; }

E2E=false
STEPS="test lint typecheck"
if [ "${1:-}" = "--e2e" ]; then
  STEPS="$STEPS e2e"
  E2E=true
fi

HEAD_SHA="$(current_head)"
DIRTY="$(is_dirty)"
ran=0
EXIT_CODE=0
TEST_COUNT="null"
declare -a STEP_CODES=()
declare -a STEP_CMDS=()
TEST_OUTPUT=""

write_stamp() {
  mkdir -p "$JOURNAL"
  local ts steps_json cmd_json
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  steps_json="{"
  cmd_json="{"
  local i=0
  local first=1
  for step in $STEPS; do
    local code="${STEP_CODES[$i]:-skip}"
    local cmd="${STEP_CMDS[$i]:-}"
    if [ "$first" -eq 1 ]; then first=0; else steps_json="$steps_json,"; cmd_json="$cmd_json,"; fi
    steps_json="$steps_json\"$step\":$code"
    cmd_json="$cmd_json\"$step\":\"$(printf '%s' "$cmd" | sed 's/["\\]/\\&/g')\""
    i=$((i + 1))
  done
  steps_json="$steps_json}"
  cmd_json="$cmd_json}"
  printf '{"ts":"%s","head":"%s","dirty":%s,"steps":%s,"commands":%s,"e2e":%s,"exit":%s,"test_count":%s}\n' \
    "$ts" "$HEAD_SHA" "$DIRTY" "$steps_json" "$cmd_json" "$E2E" "$EXIT_CODE" "$TEST_COUNT" \
    >> "$JOURNAL/verify-stamps.jsonl"
  protocol STAMP "$JOURNAL/verify-stamps.jsonl"
  protocol HEAD "$HEAD_SHA"
  protocol DIRTY "$DIRTY"
  protocol EXIT "$EXIT_CODE"
}

i=0
for step in $STEPS; do
  cmd="$(verify_cmd "$step")"
  STEP_CMDS[$i]="$cmd"
  if [ -z "$cmd" ]; then
    echo "verify: [$step] skipped (not configured)"
    STEP_CODES[$i]="\"skip\""
    i=$((i + 1))
    continue
  fi
  echo "verify: [$step] $cmd"
  out=""
  set +e
  out="$(bash -c "$cmd" 2>&1)"
  code=$?
  set -e
  printf '%s\n' "$out"
  STEP_CODES[$i]="$code"
  if [ "$step" = "test" ]; then
    TEST_OUTPUT="$out"
    extracted="$(extract_test_count "$out")"
    [ -n "$extracted" ] && TEST_COUNT="$extracted"
  fi
  if [ "$code" -ne 0 ]; then
    echo "verify: FAIL at [$step] (exit $code): $cmd" >&2
    EXIT_CODE="$code"
    write_stamp
    protocol VERIFY FAIL
    exit "$code"
  fi
  ran=$((ran + 1))
  i=$((i + 1))
done

if [ "$ran" -eq 0 ]; then
  echo "verify: WARNING — no verification commands configured in $CONFIG (verify: block is empty)." >&2
  echo "verify: this gate proved nothing. Fill verify.test at minimum." >&2
  EXIT_CODE=3
  write_stamp
  protocol VERIFY EMPTY
  exit 3
fi

echo "verify: OK ($ran step(s) passed)"
EXIT_CODE=0
write_stamp
protocol VERIFY OK
exit 0
