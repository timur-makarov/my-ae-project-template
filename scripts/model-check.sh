#!/usr/bin/env bash
# model-check.sh — unknown model slugs are a hard error, never a silent fallback.
#
# Usage: scripts/model-check.sh [role]
#   With no args, checks every models.* value in config.yml.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

allowed="$(awk '
  /^models_allowed:/ { inb=1; next }
  inb && /^[^[:space:]#]/ { inb=0 }
  inb && /^[[:space:]]*-[[:space:]]*/ {
    line=$0
    sub(/^[[:space:]]*-[[:space:]]*/, "", line)
    gsub(/["'\'' ]/, "", line)
    print line
  }
' "$CONFIG")"

# Empty list ⇒ inherit only.
if [ -z "$allowed" ]; then
  allowed="inherit"
fi

ok_slug() {
  local s="$1" a
  while IFS= read -r a; do
    [ "$s" = "$a" ] && return 0
  done <<< "$allowed"
  return 1
}

fail=0
check_role() {
  local role="$1" val
  val="$(config_get "models.$role")"
  [ -z "$val" ] && { echo "model-check: unknown role '$role'" >&2; fail=1; return; }
  if ! ok_slug "$val"; then
    echo "model-check: models.$role='$val' is not inherit and not in models_allowed — hard error, no fallback" >&2
    fail=1
    return
  fi
  echo "model-check: $role=$val"
}

if [ $# -eq 1 ]; then
  check_role "$1"
else
  for role in planner implementer implementer_mechanical reviewer critic escalation; do
    check_role "$role"
  done
fi

critic="$(config_get models.critic)"
impl="$(config_get models.implementer)"
if [ -n "$critic" ] && [ "$critic" = "$impl" ] && [ "$critic" != "inherit" ]; then
  extra=0
  while IFS= read -r a; do
    [ -z "$a" ] && continue
    [ "$a" = "inherit" ] && continue
    [ "$a" = "$critic" ] && continue
    extra=1
  done <<< "$allowed"
  if [ "$extra" -eq 1 ]; then
    echo "model-check: WARNING: models.critic equals models.implementer ($critic) while models_allowed lists another family — same-model critic shares failure modes" >&2
  fi
fi

if [ "$fail" -eq 0 ]; then
  protocol MODEL_CHECK OK
fi
exit "$fail"
