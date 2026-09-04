---
name: agentic-handoff
description: "Use when a session is ending or context is running out while a ticket is mid-flight, so the next session can resume without re-deriving state."
---

# Agentic Handoff: Mid-Ticket Resumption Brief

Write the state down so the next session (you, another agent, another human) resumes instead of restarts. Memory does not survive session boundaries; files do.

## Write the brief

Fill `.agentic/templates/handoff.md` → `.agentic/journal/<NN>-handoff.md`:

1. **Ticket, branch, worktree path, ledger path** — the pointers, exact.
2. **State:** last completed piece with its commit range (from the ledger — verify against `git log`, don't trust recollection); what is half-done and in which files (`git status` pasted, not summarized).
3. **Verified vs. decayed:** claims that hold with evidence pointers, vs. mutable-state facts that must be re-checked on resume (running processes, remote state, anything time-sensitive).
4. **The open question** — one sentence naming exactly what the next action must answer. If you can't write that sentence, the honest entry is "state: confused about X" — a named confusion is solvable; a disguised one compounds.
5. **Next command** — the literal command or dispatch to run first.
6. **Traps** — what a resuming agent could plausibly do that damages the work (wrong branch, stale build, half-applied migration).

## Update the pointers

- Append to the ledger: `HANDOFF: see journal/<NN>-handoff.md`.
- Leave ticket Status as-is (it reflects work state, not session state).

## On resume (the other half of this skill)

Read the handoff + ledger **before** touching anything. Re-verify every "decayed" item. If the handoff mtime is older than the ledger mtime, ignore the handoff (`gate.sh implement` will flag it). Delete the handoff file once resumed (`git rm` if committed) — a stale handoff is worse than none; the ledger keeps the permanent record.
