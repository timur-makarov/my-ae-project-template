# Handoff — Ticket NN

> Written by `/agentic-handoff` when a session ends mid-ticket.
> The next session (or agent) resumes from this file + the ledger, not from memory.

- **Ticket:** `.agentic/tickets/open/NN-slug.md` — status: `<status>`
- **Branch / worktree:** `<branch>` at `<path>` (or "not yet created")
- **Ledger:** `.agentic/journal/NN-ledger.md` — trust it and `git log` over any recollection

## State of the work

- **Last completed piece:** <piece + commit range, from the ledger>
- **In flight:** <what is half-done right now, in which files>
- **Verified so far:** <claims with evidence pointers that need no re-checking>
- **Decayed / re-verify on resume:** <mutable-state facts that were true then and may not be now>

## The open question

<One sentence: the exact question the next action must answer. If you cannot write
this sentence, the state is "confused" — say so explicitly rather than faking a step.>

## Next command

```
<the literal next command or dispatch to run>
```

## Traps

- <anything the resuming agent could plausibly do that would damage the work — wrong branch, stale build dir, half-applied migration>
