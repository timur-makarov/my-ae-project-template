---
name: agentic-handoff
description: "Use when a session is ending or context is running out while a ticket is mid-flight, so the next session can resume without re-deriving state."
---

# Agentic Handoff: Mid-Ticket Resumption Brief

The mechanical state survives on its own: the branch, the ticket front matter, `.agentic/state/`,
and `scripts/gate.sh next NN` recompute it. A handoff carries what doesn't survive, which is
what you were thinking.

## Write

Fill `.agentic/templates/handoff.md` → `.agentic/journal/NN-handoff.md`:

1. Branch, worktree path, and the `NEXT` line from `scripts/gate.sh next NN`.
2. **In flight:** what's half-done and in which files (`git status` pasted, not summarized).
3. **Verified vs. decayed:** claims that hold, with evidence pointers, vs. mutable facts to re-check
   (running processes, remote state).
4. **The open question:** one sentence naming exactly what the next action must answer. If you
   can't write it, say "state: confused about X". A named confusion is solvable; a disguised one compounds.
5. **Traps:** what a resuming agent could plausibly do that damages the work.

Leave the ticket's status alone.

## Resume

Run `scripts/gate.sh next NN` first, then read the handoff and re-verify every decayed item.
If `NEXT` disagrees with the handoff, trust `NEXT`. Delete the handoff once resumed; a stale
handoff is worse than none.
