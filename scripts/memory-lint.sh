#!/usr/bin/env bash
# memory-lint.sh — citations, needles, forbidden recomputable cites, lesson TTL.
#
# Usage:
#   scripts/memory-lint.sh
#   scripts/memory-lint.sh --root DIR [--context FILE] [--lessons FILE]
#
# Lessons live one file per ticket in .agentic/journal/lessons/NN.md (so
# parallel tickets never conflict). A "- DROPPED" line in any file retires the
# matching lesson in every file.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

MEM_ROOT="$ROOT"
CONTEXT_FILE=""
LESSONS_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --root) MEM_ROOT="$2"; shift 2 ;;
    --context) CONTEXT_FILE="$2"; shift 2 ;;
    --lessons) LESSONS_FILE="$2"; shift 2 ;;
    *) echo "usage: scripts/memory-lint.sh [--root DIR] [--context FILE] [--lessons FILE]" >&2; exit 2 ;;
  esac
done

if [ -f "$MEM_ROOT/.agentic/config.yml" ]; then
  CONFIG="$MEM_ROOT/.agentic/config.yml"
fi

[ -n "$CONTEXT_FILE" ] || CONTEXT_FILE="$MEM_ROOT/.agentic/context/CONTEXT.md"
LESSON_FILES=()
if [ -n "$LESSONS_FILE" ]; then
  LESSON_FILES=("$LESSONS_FILE")
else
  for f in "$MEM_ROOT"/.agentic/journal/lessons/*.md "$MEM_ROOT/.agentic/journal/lessons.md"; do
    [ -f "$f" ] && LESSON_FILES+=("$f")
  done
fi

TTL="$(config_get "limits.lesson_ttl_days")"
[ -n "$TTL" ] || TTL=90

fail=0
err() { echo "memory-lint: $1" >&2; fail=1; }

epoch_ymd() {
  local d="$1" e
  e="$(date -j -f "%Y-%m-%d" "$d" "+%s" 2>/dev/null)" && { printf '%s\n' "$e"; return 0; }
  e="$(date -d "$d" "+%s" 2>/dev/null)" && { printf '%s\n' "$e"; return 0; }
  return 1
}

days_old() {
  local d="$1" then now
  then="$(epoch_ymd "$d")" || return 1
  now="$(epoch_ymd "$(date -u +%Y-%m-%d)")" || now="$(date -u +%s)"
  printf '%s\n' $(( (now - then) / 86400 ))
}

strip_ticks() {
  printf '%s' "$1" | tr -d '`'
}

is_forbidden() {
  local base
  base="$(basename "$1")"
  case "$base" in
    README.md|package.json|package-lock.json|yarn.lock|pnpm-lock.yaml|Cargo.lock|go.sum) return 0 ;;
  esac
  return 1
}

verify_script_path() {
  local cmd="$1" word
  word="$(printf '%s' "$cmd" | awk '{print $1}')"
  case "$word" in
    ''|true|:) return 1 ;;
  esac
  printf '%s\n' "$word"
}

is_enforcing() {
  local path="$1" base cmd sp
  case "$path" in
    scripts/*) return 0 ;;
  esac
  base="$(basename "$path")"
  case "$base" in
    *test*|*Test*) return 0 ;;
  esac
  for key in test lint typecheck e2e; do
    cmd="$(config_get "verify.$key")"
    sp="$(verify_script_path "$cmd")" || continue
    [ "$path" = "$sp" ] && return 0
  done
  return 1
}

# Sets PATH_OUT NEEDLE_OUT. Cite spec: [cite:]path [needle:"token"]
parse_cite_spec() {
  local spec needle path
  spec="$(printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  spec="$(strip_ticks "$spec")"
  NEEDLE_OUT=""
  PATH_OUT=""
  if printf '%s' "$spec" | grep -q 'needle:"'; then
    needle="$(printf '%s' "$spec" | sed -n 's/.*needle:"\([^"]*\)".*/\1/p')"
    spec="$(printf '%s' "$spec" | sed 's/needle:"[^"]*"//')"
    NEEDLE_OUT="$needle"
  fi
  spec="$(printf '%s' "$spec" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  spec="$(printf '%s' "$spec" | sed 's/^cite://')"
  spec="$(strip_ticks "$spec")"
  spec="$(printf '%s' "$spec" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  path="$(printf '%s' "$spec" | awk '{print $1}')"
  PATH_OUT="$path"
}

md_link_path() {
  printf '%s' "$1" | sed -n 's/.*](\([^)]*\)).*/\1/p' | head -n 1
}

resolve_cite() {
  local path="$1" from="$2" dir
  case "$path" in
    ""|/*|*..*) return 1 ;;
  esac
  if [ -f "$MEM_ROOT/$path" ]; then
    printf '%s\n' "$path"
    return 0
  fi
  if [ -n "$from" ]; then
    dir="$(dirname "$from")"
    if [ -f "$MEM_ROOT/$dir/$path" ]; then
      printf '%s\n' "$dir/$path"
      return 0
    fi
  fi
  return 1
}

check_cite() {
  local where="$1" path="$2" needle="$3" require_needle="$4" from="$5"
  local resolved full
  if [ -z "$path" ]; then
    err "$where: missing cite"
    return 1
  fi
  if is_forbidden "$path"; then
    err "$where: cite '$path' is recomputable — recompute, don't remember"
    return 1
  fi
  resolved="$(resolve_cite "$path" "$from")" || {
    err "$where: cite '$path' does not exist"
    return 1
  }
  if [ "$require_needle" = "1" ] && [ -z "$needle" ]; then
    err "$where: missing needle:\"token\" for cite '$resolved'"
    return 1
  fi
  if [ -n "$needle" ]; then
    full="$MEM_ROOT/$resolved"
    if ! grep -Fq -- "$needle" "$full"; then
      err "$where: stale — needle \"$needle\" missed in $resolved — compact or drop"
      return 1
    fi
  fi
  return 0
}

lint_context() {
  local f="$1"
  [ -f "$f" ] || return 0
  local rel lineno line last_col spec path needle require
  rel="${f#$MEM_ROOT/}"
  [ "$rel" = "$f" ] && rel="$f"
  lineno=0
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))
    case "$line" in
      ''|\#*|'>'*|'<!--'*) continue ;;
    esac
    if printf '%s' "$line" | grep -qE '^[[:space:]]*\|[[:space:]]*-{2,}'; then
      continue
    fi
    if printf '%s' "$line" | grep -q '^[[:space:]]*|'; then
      last_col="$(printf '%s' "$line" | awk -F'|' '{
        n=NF
        for (i=n; i>=1; i--) {
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
          if ($i != "") { print $i; exit }
        }
      }')"
      first_col="$(printf '%s' "$line" | awk -F'|' '{
        for (i=1; i<=NF; i++) {
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
          if ($i != "") { print $i; exit }
        }
      }')"
      case "$last_col" in
        Cite|cite) continue ;;
      esac
      case "$first_col" in
        Term|term) continue ;;
      esac
      parse_cite_spec "$last_col"
      check_cite "$rel:$lineno" "$PATH_OUT" "$NEEDLE_OUT" 1 "$rel"
      continue
    fi
    if printf '%s' "$line" | grep -qE '^[[:space:]]*-[[:space:]]'; then
      require=1
      path=""
      needle=""
      if printf '%s' "$line" | grep -q 'cite:'; then
        spec="$(printf '%s' "$line" | sed 's/.*cite:/cite:/')"
        parse_cite_spec "$spec"
        path="$PATH_OUT"
        needle="$NEEDLE_OUT"
      elif printf '%s' "$line" | grep -q ']('; then
        path="$(md_link_path "$line")"
        parse_cite_spec "$line"
        needle="$NEEDLE_OUT"
        require=0
      else
        err "$rel:$lineno: missing cite"
        continue
      fi
      check_cite "$rel:$lineno" "$path" "$needle" "$require" "$rel"
    fi
  done < "$f"
}

extract_lesson_defect() {
  # After "YYYY-MM-DD ": text until " — "
  printf '%s' "$1" | sed 's/ — .*//'
}

DROPPED=""
collect_dropped() {
  local f="$1" rel lineno line rest defect
  [ -f "$f" ] || return 0
  rel="${f#$MEM_ROOT/}"
  lineno=0
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))
    case "$line" in
      '- DROPPED '*)
        rest="${line#- DROPPED }"
        if ! printf '%s' "$rest" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2} '; then
          err "$rel:$lineno: DROPPED line missing YYYY-MM-DD"
          continue
        fi
        defect="${rest#????-??-?? }"
        # date is first token; strip it portably
        defect="$(printf '%s' "$rest" | sed 's/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][[:space:]]*//')"
        DROPPED="$DROPPED$defect"$'\n'
        ;;
    esac
  done < "$f"
}

lint_lessons() {
  local f="$1"
  [ -f "$f" ] || return 0
  local rel lineno line rest date defect cite_spec age
  rel="${f#$MEM_ROOT/}"
  [ "$rel" = "$f" ] && rel="$f"

  lineno=0
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))
    case "$line" in
      ''|'#'*|'>'*|'Lessons: none'|'<!--'*|'- DROPPED '*) continue ;;
    esac
    if ! printf '%s' "$line" | grep -qE '^- \[[0-9]+\] '; then
      continue
    fi
    rest="${line#*\] }"
    if ! printf '%s' "$rest" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2} '; then
      err "$rel:$lineno: lesson missing YYYY-MM-DD"
      continue
    fi
    date="$(printf '%s' "$rest" | awk '{print $1}')"
    rest="$(printf '%s' "$rest" | sed 's/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][[:space:]]*//')"
    defect="$(extract_lesson_defect "$rest")"
    if printf '%s' "$DROPPED" | grep -Fqx -- "$defect"; then
      continue
    fi
    if ! printf '%s' "$line" | grep -q 'cite:'; then
      err "$rel:$lineno: missing cite"
      continue
    fi
    cite_spec="$(printf '%s' "$line" | sed 's/.*cite:/cite:/')"
    parse_cite_spec "$cite_spec"
    check_cite "$rel:$lineno" "$PATH_OUT" "$NEEDLE_OUT" 1 "$rel" || continue
    if is_enforcing "$PATH_OUT"; then
      continue
    fi
    age="$(days_old "$date")" || { err "$rel:$lineno: unreadable date '$date'"; continue; }
    if [ "$age" -gt "$TTL" ]; then
      err "$rel:$lineno: lesson older than $TTL days with no enforcing cite — promote to a check or append DROPPED"
    fi
  done < "$f"
}

lint_context "$CONTEXT_FILE"
for f in ${LESSON_FILES[@]+"${LESSON_FILES[@]}"}; do collect_dropped "$f"; done
for f in ${LESSON_FILES[@]+"${LESSON_FILES[@]}"}; do lint_lessons "$f"; done

if [ "$fail" -eq 0 ]; then
  echo "memory-lint: OK"
  protocol MEMORY_LINT OK
fi
exit "$fail"
