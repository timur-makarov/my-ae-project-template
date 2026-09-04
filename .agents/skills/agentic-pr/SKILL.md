---
name: agentic-pr
description: "Use when a ticket's implementation is complete and verified, and the branch needs to be integrated — merged, pushed as a PR, or kept for later."
---

# Agentic PR: Finish the Branch

Take a `ready-for-review` ticket branch to integration. Reads `base_branch` from `.agentic/config.yml`.

## 1. Gate

Run `scripts/gate.sh pr <NN> [pr-body-file]` **on the tree being integrated, now**. The gate checks the verify *stamp* (HEAD match, dirty=false, exit 0), critic APPROVED for MEDIUM/HIGH, diff-time risk floors, merge-base vs `base_branch`, no remaining ASSUMED rows, resolution lint, and debt-lint. Red gate → report failures with output and stop; the menu comes after green. For HIGH-risk tickets, `risk.high_requires_human_merge` means options that merge without a human are off the table (local guard asks; CI is the wall).

## 2. Detect environment

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" && pwd -P)
WORKTREE_PATH=$(git rev-parse --show-toplevel)   # capture before any cd
```

`GIT_DIR != GIT_COMMON` → linked worktree (cleanup rules below apply). Confirm the base branch (config `base_branch`) is really what this branch forked from — merging into the wrong base is expensive to undo.

## 3. Present the menu and wait

```
Implementation complete. Options:
1. Merge into <base_branch> locally
2. Push and create a Pull Request → <base_branch>   (default for remote-driven work)
3. Keep the branch as-is
```

Integration is the human's decision; if they pre-authorized ("open a PR when done"), that authorization is the answer — proceed without re-asking. **Discarding work is never offered**; it happens only when explicitly requested, confirmed by the typed word `discard`, and executed with `git branch -D` only after showing exactly which commits and files die.

## 4. Execute

- **Merge locally:** from the main checkout — `git checkout <base_branch> && git pull && git merge <branch>`, then `scripts/verify.sh` **on the merged result**. Red → stop, leave branch and worktree in place (nothing pushed; recoverable). Green → clean up worktree (step 5), `git branch -d <branch>`.
- **PR:** `git push -u origin <branch>`, create the PR against `base_branch` with the forge CLI (`gh pr create` or equivalent), body from `.agentic/templates/pr.md` filled from the ticket: Done Contract as checkboxes, verify stamp protocol lines, risk section, **every `Ruling:` line from the ledger** (or `Rulings: none`), critic verdict + report path. Re-run `scripts/gate.sh pr <NN> <bodyfile>` on the filled body. Record the PR URL in the ticket. Keep the worktree — feedback lands there.
- **Keep:** report branch and worktree path; done.

## 5. Worktree cleanup (merge path only)

Only remove worktrees under the config's `worktree_dir` — anything else is host-managed. `git worktree remove "$WORKTREE_PATH" && git worktree prune`. If removal is refused (modified/untracked files), those files exist nowhere else: **never `--force`** — show `git -C "$WORKTREE_PATH" status --porcelain -uall` and ask: commit them, move them out, or delete (unrecoverable).

## 6. Handling PR feedback

Reply to inline review threads in-thread, not as top-level comments. Before implementing any reviewer suggestion, verify it against this codebase (does it break something, is there a reason for the current shape, is the "missing feature" even used — YAGNI check). Push back with technical reasoning when it's wrong; never performative agreement. Fix one item at a time, test each; unclear items get clarified before *any* are implemented — items may be related.

## 7. Report

Sentence 1: what was integrated and where (PR URL or merge result). Then: verify evidence, anything parked/deferred from the ledger, next action (`/agentic-archive <NN>` once accepted/merged).
