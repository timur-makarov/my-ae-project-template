#!/usr/bin/env bash
# env-lint.sh — enforcement-layer integrity + CONTEXT.md cap + memory-lint + optional protected-path diff.
#
# Usage:
#   scripts/env-lint.sh                 # compare hashes to .agentic/state/enforcement.sha256
#   scripts/env-lint.sh --write-manifest # regenerate the manifest (HIGH-ticket work)
#   scripts/env-lint.sh --protected-diff # fail if CI diff touches protected paths without HIGH
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

MANIFEST="$STATE/enforcement.sha256"

enforcement_list() {
  {
    echo ".cursor/hooks.json"
    echo ".cursor/hooks/guard.sh"
    echo ".cursor/hooks/audit.sh"
    echo ".cursor/hooks/protect.sh"
    echo ".cursor/hooks/session-start.sh"
    echo ".cursor/hooks/stop.sh"
    echo ".cursor/hooks/mcp-guard.sh"
    echo ".cursor/hooks/task-guard.sh"
    echo ".cursor/rules/constitution.mdc"
    echo ".cursor/rules/default_swe.mdc"
    echo ".github/workflows/agentic-gates.yml"
    echo ".agentic/references/dod.md"
    find "$ROOT/scripts" -name '*.sh' -not -name 'selftest.sh' | sed "s|^$ROOT/||" | sort
    find "$ROOT/.agentic/templates" -type f | sed "s|^$ROOT/||" | sort
  } | sort -u
}

file_hash() {
  local f="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | awk '{print $1}'
  else
    shasum -a 256 "$f" | awk '{print $1}'
  fi
}

write_manifest() {
  mkdir -p "$STATE"
  : > "$MANIFEST"
  local rel
  while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    if [ ! -f "$ROOT/$rel" ]; then
      echo "env-lint: missing enforcement file $rel" >&2
      continue
    fi
    printf '%s  %s\n' "$(file_hash "$ROOT/$rel")" "$rel" >> "$MANIFEST"
  done < <(enforcement_list)
  echo "env-lint: wrote $MANIFEST"
}

compare_manifest() {
  if [ ! -f "$MANIFEST" ]; then
    echo "env-lint: missing $MANIFEST — run scripts/env-lint.sh --write-manifest" >&2
    protocol ENV_LINT MISSING_MANIFEST
    return 1
  fi
  local fail=0 rel expected actual
  while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    if ! grep -q "  $rel\$" "$MANIFEST"; then
      echo "env-lint: $rel is in the enforcement set but not in the manifest" >&2
      fail=1
      continue
    fi
  done < <(enforcement_list)

  while IFS= read -r line; do
    expected="${line%%  *}"
    rel="${line#*  }"
    if [ ! -f "$ROOT/$rel" ]; then
      echo "env-lint: manifest lists missing file $rel" >&2
      fail=1
      continue
    fi
    actual="$(file_hash "$ROOT/$rel")"
    if [ "$actual" != "$expected" ]; then
      echo "env-lint: DRIFT $rel" >&2
      fail=1
    fi
  done < "$MANIFEST"

  return "$fail"
}

context_cap() {
  local cap file lines
  cap="$(config_get "limits.context_md_max_lines")"
  [ -z "$cap" ] && cap=120
  file="$ROOT/.agentic/context/CONTEXT.md"
  [ -f "$file" ] || return 0
  lines="$(wc -l < "$file" | tr -d ' ')"
  if [ "$lines" -gt "$cap" ]; then
    echo "env-lint: CONTEXT.md is $lines lines (cap $cap) — compact it" >&2
    return 1
  fi
  return 0
}

memory_lint() {
  "$SCRIPT_DIR/memory-lint.sh"
}

protected_diff() {
  has_git || { echo "env-lint: --protected-diff requires git" >&2; return 1; }
  local base
  base="$(base_branch)"
  [ -z "$base" ] && base="dev"
  if ! git -C "$ROOT" rev-parse --verify "$base" >/dev/null 2>&1; then
    echo "env-lint: base branch '$base' not found; skipping protected-diff" >&2
    return 0
  fi
  local nn="" ticket="" tier=""
  nn="$(git -C "$ROOT" branch --show-current | sed -n 's/^ticket\/0*\([0-9][0-9]*\).*/\1/p')"
  if [ -n "$nn" ]; then
    ticket="$(ticket_file "$(nn_pad "$nn")" 2>/dev/null || true)"
    [ -n "$ticket" ] && tier="$(ticket_yaml "$ticket" risk_tier)"
  fi
  local fail=0 f floor
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    floor="$(path_risk_floor "$f")"
    case "$f" in
      .cursor/hooks/*|scripts/*|.agentic/templates/*|.cursor/hooks.json|.cursor/rules/*)
        if [ "$tier" != "HIGH" ]; then
          echo "env-lint: protected path '$f' in diff requires HIGH ticket (found '${tier:-none}')" >&2
          fail=1
        fi
        ;;
    esac
    if [ "$(tier_rank "$floor")" -gt "$(tier_rank "${tier:-LOW}")" ]; then
      echo "env-lint: '$f' floor $floor exceeds ticket tier ${tier:-unset}" >&2
      fail=1
    fi
  done < <(git -C "$ROOT" diff --name-only "$base"...HEAD)
  return "$fail"
}


failclosed_intact() {
  local hf="$ROOT/.cursor/hooks.json"
  [ -f "$hf" ] || return 0
  if grep -q '"failClosed"[[:space:]]*:[[:space:]]*false' "$hf"; then
    echo "env-lint: failClosed was set to false in hooks.json — HIGH-only and a floor violation" >&2
    return 1
  fi
  if ! grep -q '"failClosed"[[:space:]]*:[[:space:]]*true' "$hf"; then
    echo "env-lint: hooks.json missing failClosed true" >&2
    return 1
  fi
  return 0
}

MODE="${1:-}"
fail=0
case "$MODE" in
  --write-manifest) write_manifest; exit 0 ;;
  --protected-diff)
    compare_manifest || fail=1
    context_cap || fail=1
    memory_lint || fail=1
    failclosed_intact || fail=1
    protected_diff || fail=1
    ;;
  "")
    compare_manifest || fail=1
    context_cap || fail=1
    memory_lint || fail=1
    failclosed_intact || fail=1
    ;;
  *) echo "usage: scripts/env-lint.sh [--write-manifest|--protected-diff]" >&2; exit 2 ;;
esac

if [ "$fail" -eq 0 ]; then
  echo "env-lint: OK"
  protocol ENV_LINT OK
fi
exit "$fail"
