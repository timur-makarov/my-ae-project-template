---
name: agentic-pr
description: "Use when a ticket's implementation is complete and verified, and the branch needs to be integrated — merged, pushed as a PR, or kept for later."
---

# Agentic PR: Finish the Branch

Integrate a shipped ticket branch (`scripts/gate.sh next NN` says `/agentic-pr`). Reads
`base_branch` from `.agentic/config.yml`.

## 1. Gate

`scripts/gate.sh pr NN --require-shipped` re-runs everything CI will run, read-only. Red → report
the failure with output and stop. HIGH tickets (`risk.high_requires_human_merge`): push and open
the PR, but a human merges; the guard denies an agent merge into base.

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

- **Merge locally:** from the main checkout — `git checkout <base_branch> && git pull && git merge --no-ff <branch>` (the guard allows it only for a shipped, non-HIGH ticket branch), then `scripts/verify.sh` **on the merged result**. Red → stop, leave branch and worktree in place (nothing pushed; recoverable). Green → clean up worktree (step 5), `git branch -d <branch>`.
- **PR:** `git push -u origin <branch>`, then `gh pr create --base <base_branch>` (or the forge's equivalent) with the body from `.agentic/templates/pr.md`, filled from the ticket and the review report. CI runs `gate.sh pr NN --require-shipped` on the pushed branch. Keep the worktree — feedback lands there.
- **Keep:** report branch and worktree path; done.

## 5. Worktree cleanup (merge path only)

Only remove worktrees under the config's `worktree_dir` — anything else is host-managed. `git worktree remove "$WORKTREE_PATH" && git worktree prune`. If removal is refused (modified/untracked files), those files exist nowhere else: **never `--force`** — show `git -C "$WORKTREE_PATH" status --porcelain -uall` and ask: commit them, move them out, or delete (unrecoverable).

## 6. Handling PR feedback

Edit on the ticket branch and run `scripts/gate.sh advance NN`: product changes after ship reopen the ticket, re-run the checks (and the review, for MEDIUM/HIGH), and ship again. Then push. Reply to inline review threads in-thread, not as top-level comments. Before implementing any reviewer suggestion, verify it against this codebase (does it break something, is there a reason for the current shape, is the "missing feature" even used — YAGNI check). Push back with technical reasoning when it's wrong; never performative agreement. Fix one item at a time, test each; unclear items get clarified before *any* are implemented — items may be related.

## 7. Report

Sentence 1: what was integrated and where (PR URL or merge result). Then: the gate evidence, anything deliberately deferred, and who merges (human for HIGH).
