---
name: agentic-implement
description: "Use when an open, unblocked ticket exists and it's time to execute it — implementation, fixes, or diagnosis work."
---

# Agentic Implement: Ride the Railroad

```
scripts/gate.sh advance NN
```

`advance` runs every step a script can run and stops with `NEXT` when it needs you. Do what
`NEXT` says, then run `advance` again. Repeat until it prints a rest or human row. Don't edit
ticket status, move ticket files, or write `.agentic/state/`.

## What `NEXT` will ask of you

- **implement: edit files inside scope_paths.** Write the change. TDD loop: failing reproducer →
  see it fail for the right reason → minimal code → see it pass. Full-template tickets: check
  every ASSUMED row before writing code; the gate refuses ASSUMED rows at ship. Domain skills
  load when `craft_skills: true` and the work matches (`/agentic-route`).
- **commit your changes** (MEDIUM/HIGH): `git commit -m "NN: <summary>"`. LOW doesn't need this;
  ship commits in-scope changes itself.
- **spawn the reviewer** (MEDIUM/HIGH): see `/agentic-critic`. Don't review your own diff.
- **fix the findings / fix: <step failed>:** the failing command's output was printed above,
  and the full log is in `.agentic/state/logs/`. Fix the code or the ticket, then `advance`.
  Findings on a report stay open until a new commit gets a fresh review.
- **write lessons** (MEDIUM/HIGH): `/agentic-archive`.
- **/agentic-pr:** the ticket is shipped on its branch; integrate it.

## Rules the gate enforces

- One claim is one `ticket/NN-slug` branch, with the scope frozen at claim time. Widening means
  editing `scope_paths` and running `scripts/gate.sh implement NN --widen`.
- `limits.max_active_tickets` in-progress tickets across local branches. Overlapping scopes and
  `blocked_by` links refuse a second claim.
- Parallel work: `scripts/gate.sh implement NN --worktree` creates `.worktrees/NN-slug` on the
  ticket branch. Open it as the workspace and run `advance` there.
- Ship refuses: files outside `scope_paths`, a risk floor above the tier, destructive migrations
  without a down path, lockfile packages missing from `new_deps`, a test-count drop without a
  `Ruling:` line in the ticket.

Two patches defending one conclusion means the conclusion is wrong: set the approach aside, reread
the ticket, and if the Done Contract itself is wrong, fix the ticket (or `/agentic-grill` if that
expands the blast radius). Three failed fixes on one bug means the diagnosis is wrong
(`/agentic-debug`).

## Report

Sentence 1: what shipped, in the ticket's terms. Then the evidence (the commands the gate ran, with
exit codes) and the risk: weakest premise, untested paths, flip condition.
