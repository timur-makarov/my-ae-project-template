#!/usr/bin/env bash
# answers-check.sh — focused proof that an unanswered ticket cannot start work.
#
# Usage: scripts/answers-check.sh lint|gate|protect
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-}"
case "$MODE" in
  lint|gate|protect) ;;
  *) echo "usage: scripts/answers-check.sh lint|gate|protect" >&2; exit 2 ;;
esac

die() { echo "answers-check: $*" >&2; exit 1; }

write_lite() { # FILE STATUS VERBATIM QUESTION
  cat > "$1" <<EOF
---
status: $2
type: directive
risk_tier: LOW
template: lite
blocked_by: none
reversibility: reversible
rollback: n/a
new_deps: []
scope_paths:
  - README.md
---
# Ticket 01 — ask

## Request

- **Verbatim:** $3
- **Restatement:** the outcome for the caller
- **Cause:** the request arrived
- **Out of scope:** everything else

## Done Contract

1. it holds — Check: \`test -f README.md\`

## Constraints

- stay inside scope

## Open questions

$4

## Blast Radius

**NARROWING** — fixture
EOF
}

lint_mode() {
  local f out
  f="$(mktemp)"
  write_lite "$f" open '"x"' "- Should archived rows be included?"
  out="$("$ROOT/scripts/ticket-lint.sh" "$f" 2>&1 || true)"
  printf '%s' "$out" | grep -q "blocked-on-answers" || die "open question was accepted: $out"
  write_lite "$f" open '"<needs a real quote>"' "none"
  out="$("$ROOT/scripts/ticket-lint.sh" "$f" 2>&1 || true)"
  printf '%s' "$out" | grep -q "template leftover" || die "placeholder Verbatim was accepted: $out"
  write_lite "$f" blocked-on-answers '"x"' "none"
  out="$("$ROOT/scripts/ticket-lint.sh" "$f" 2>&1 || true)"
  printf '%s' "$out" | grep -q "ticket-lint: OK" || die "acceptance wait failed lint: $out"
  rm -f "$f"
}

copy_repo() {
  local dest="$1" f
  mkdir -p "$dest"
  (cd "$ROOT" && git ls-files -co --exclude-standard) | while IFS= read -r f; do
    if [ -e "$ROOT/$f" ] || [ -L "$ROOT/$f" ]; then printf '%s\n' "$f"; fi
  done > "$dest/files"
  (cd "$ROOT" && tar -cf - -T "$dest/files") | (cd "$dest" && tar -xf -)
  rm -f "$dest/files"
  find "$dest/.agentic/tickets" -name '*.md' -delete
  (
    cd "$dest" && git init -q -b main && git config user.email t@t && git config user.name t \
      && git add -A && git commit -qm init
  )
}

gate_mode() {
  local dest out
  dest="$(mktemp -d)"
  copy_repo "$dest"
  write_lite "$dest/.agentic/tickets/open/01-ask.md" blocked-on-answers '"x"' "none"
  out="$(cd "$dest" && ./scripts/gate.sh next 01 2>&1)" || die "next failed: $out"
  printf '%s' "$out" | grep -q "NEXT: human:" || die "next did not stop for a human: $out"
  printf '%s' "$out" | grep -q "blocked-on-answers" || die "next did not name blocked-on-answers: $out"
  out="$(cd "$dest" && ./scripts/gate.sh advance 01 2>&1)" || die "advance failed: $out"
  printf '%s' "$out" | grep -q "blocked-on-answers" || die "advance claimed or hid the wait: $out"
  [ "$(git -C "$dest" branch --show-current)" = "main" ] || die "acceptance wait left $(git -C "$dest" branch --show-current)"
  if git -C "$dest" rev-parse --verify --quiet refs/heads/ticket/01-ask >/dev/null; then
    die "acceptance wait created a ticket branch"
  fi
  rm -rf "$dest"
}

protect_mode() {
  local dest perm
  command -v jq >/dev/null 2>&1 || die "jq is required"
  dest="$(mktemp -d)"
  copy_repo "$dest"
  write_lite "$dest/.agentic/tickets/open/01-ask.md" blocked-on-answers '"x"' "none"
  perm="$(jq -n --arg p "$dest/src/x.txt" --arg d "$dest" '{tool_name:"Write", tool_input:{path:$p}, cwd:$d}' \
    | "$dest/scripts/hooks/protect.sh" | jq -r '.permission // "none"')"
  [ "$perm" = "deny" ] || die "product write was $perm, want deny"
  perm="$(jq -n --arg p "$dest/.agentic/tickets/open/01-ask.md" --arg d "$dest" '{tool_name:"Write", tool_input:{path:$p}, cwd:$d}' \
    | "$dest/scripts/hooks/protect.sh" | jq -r '.permission // "none"')"
  [ "$perm" = "allow" ] || die "ticket edit was $perm, want allow"
  rm -rf "$dest"
}

case "$MODE" in
  lint) lint_mode ;;
  gate) gate_mode ;;
  protect) protect_mode ;;
esac
echo "answers-check: OK ($MODE)"
