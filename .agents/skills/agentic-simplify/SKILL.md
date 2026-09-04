---
name: agentic-simplify
description: "Use when code works but is harder than it should be, or the critic flagged complexity. Preserve behavior. Chesterton's fence. No drive-by refactors."
---

# Agentic Simplify

- Understand why the code exists (`git log -L`, blame, ADRs) before deleting it.
- Same outputs, error types, side effects.
- Scope = recently changed code. Adjacent mess goes on the noticed-not-touching list.
- If the refactor exceeds ~500 lines, prefer a codemod over hand editing.

## Verification

Tests that characterized behavior still pass unchanged. Diff is deletions-heavy.