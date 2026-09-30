#!/usr/bin/env bash
# env-lint.sh — the enforcement wiring is intact and the tools agree.
#
# Usage:
#   scripts/env-lint.sh                  # wiring + CONTEXT.md cap + memory-lint
#   scripts/env-lint.sh --protected-diff # also: every changed file's risk floor
#                                        # is covered by the branch's ticket tier (CI)
#
# Wiring: tool configs parse; every hook command names a script that exists;
# Cursor's shell/file hooks stay failClosed; Codex's sandbox network matches
# guard.network; .claude/skills/* resolve to .agents/skills/*.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

fail=0
err() { echo "env-lint: $1" >&2; fail=1; }

CURSOR_HOOKS="$ROOT/.cursor/hooks.json"
CLAUDE_SETTINGS="$ROOT/.claude/settings.json"
CODEX_HOOKS="$ROOT/.codex/hooks.json"
CODEX_CONFIG="$ROOT/.codex/config.toml"

parse_configs() {
  local f
  for f in "$CURSOR_HOOKS" "$CLAUDE_SETTINGS" "$CODEX_HOOKS"; do
    [ -f "$f" ] || continue
    python3 - "$f" <<'PY' || err "$(relpath_from "$f") is not valid JSON"
import json, re, sys
text = open(sys.argv[1]).read()
text = "\n".join(l for l in text.splitlines() if not l.lstrip().startswith("//"))
try:
    json.loads(text)
except ValueError as e:
    sys.exit(str(e))
PY
  done
  if [ -f "$CODEX_CONFIG" ]; then
    python3 - "$CODEX_CONFIG" <<'PY' || err ".codex/config.toml is not valid TOML"
import sys
try:
    import tomllib
except ImportError:
    sys.exit(0)
tomllib.load(open(sys.argv[1], "rb"))
PY
  fi
}

hook_scripts_exist() {
  local f s
  for f in "$CURSOR_HOOKS" "$CLAUDE_SETTINGS" "$CODEX_HOOKS"; do
    [ -f "$f" ] || continue
    while IFS= read -r s; do
      [ -z "$s" ] && continue
      [ -x "$ROOT/$s" ] || err "$(relpath_from "$f") runs $s, which is missing or not executable"
    done < <(grep -v '^[[:space:]]*//' "$f" | grep -oE 'scripts/hooks/[A-Za-z0-9_.-]+\.sh' | sort -u)
  done
}

failclosed_intact() {
  [ -f "$CURSOR_HOOKS" ] || return 0
  python3 - "$CURSOR_HOOKS" <<'PY' || err ".cursor/hooks.json: guard.sh and protect.sh must be wired, each with \"failClosed\": true"
import json, sys
text = "\n".join(l for l in open(sys.argv[1]).read().splitlines() if not l.lstrip().startswith("//"))
try:
    hooks = json.loads(text).get("hooks", {})
except ValueError:
    sys.exit(0)  # parse_configs reports it
entries = [e for es in hooks.values() for e in es]
cmds = [e.get("command", "") for e in entries]
bad = [
    e for e in entries
    if any(k in e.get("command", "") for k in ("guard.sh", "protect.sh")) and e.get("failClosed") is not True
]
missing = not any("/guard.sh" in c and "mcp-guard" not in c for c in cmds) or not any("protect.sh" in c for c in cmds)
sys.exit(1 if bad or missing else 0)
PY
}

network_agrees() {
  [ -f "$CODEX_CONFIG" ] || return 0
  local net want have
  net="$(config_get guard.network)"
  case "$net" in allow) want=true ;; *) want=false ;; esac
  have="$(awk '/^\[sandbox_workspace_write\]/{inb=1; next} /^\[/{inb=0} inb && /^network_access/{sub(/.*=[[:space:]]*/, ""); sub(/[[:space:]]*#.*$/, ""); print; exit}' "$CODEX_CONFIG")"
  [ -z "$have" ] && have=false
  [ "$have" = "$want" ] || err ".codex/config.toml network_access = $have, but guard.network is '$net' (want $want)"
}

skill_links() {
  local d name
  [ -d "$ROOT/.claude/skills" ] || return 0
  for d in "$ROOT"/.agents/skills/*/; do
    name="$(basename "$d")"
    [ -f "$ROOT/.claude/skills/$name/SKILL.md" ] || err ".claude/skills/$name does not resolve to .agents/skills/$name (ln -s ../../.agents/skills/$name .claude/skills/$name)"
  done
  for d in "$ROOT"/.claude/skills/*; do
    [ -e "$d" ] || [ -L "$d" ] || continue
    [ -f "$d/SKILL.md" ] || err ".claude/skills/$(basename "$d") is a broken link"
  done
}

context_cap() {
  local cap file lines
  cap="$(config_get "limits.context_md_max_lines")"
  [ -z "$cap" ] && cap=120
  file="$ROOT/.agentic/context/CONTEXT.md"
  [ -f "$file" ] || return 0
  lines="$(wc -l < "$file" | tr -d ' ')"
  [ "$lines" -le "$cap" ] || err "CONTEXT.md is $lines lines (cap $cap) — compact it"
}

protected_diff() {
  has_git || { err "--protected-diff requires git"; return; }
  local ref mb nn ticket tier f floor
  if ! ref="$(base_ref)"; then
    [ -n "${CI:-}" ] && { err "base '$(base_branch)' not found — fetch it"; return; }
    echo "env-lint: WARNING: base '$(base_branch)' not found; skipping protected-diff" >&2
    return
  fi
  mb="$(git -C "$ROOT" merge-base "$ref" HEAD 2>/dev/null)" || { err "no merge-base with $ref"; return; }
  nn="$(branch_nn)"
  tier=""
  if [ -n "$nn" ]; then
    ticket="$(ticket_file "$nn" 2>/dev/null || true)"
    [ -n "$ticket" ] && tier="$(ticket_yaml "$ticket" risk_tier)"
  fi
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    floor="$(path_risk_floor "$f")"
    [ "$floor" = "LOW" ] && continue
    if [ "$(tier_rank "$floor")" -gt "$(tier_rank "${tier:-NONE}")" ]; then
      err "'$f' (floor $floor) changed on $(current_branch) with ticket tier '${tier:-none}'"
    fi
  done < <(git -C "$ROOT" diff --name-only "$mb" HEAD -- . "${NON_PRODUCT[@]}")
}

MODE="${1:-}"
case "$MODE" in
  ""|--protected-diff) ;;
  *) echo "usage: scripts/env-lint.sh [--protected-diff]" >&2; exit 2 ;;
esac

parse_configs
hook_scripts_exist
failclosed_intact
network_agrees
skill_links
context_cap
"$SCRIPT_DIR/memory-lint.sh" >/dev/null || err "memory-lint failed: scripts/memory-lint.sh"
[ "$MODE" = "--protected-diff" ] && protected_diff

if [ "$fail" -eq 0 ]; then
  echo "env-lint: OK"
  protocol ENV_LINT OK
fi
exit "$fail"
