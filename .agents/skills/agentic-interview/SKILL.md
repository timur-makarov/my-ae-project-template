---
name: agentic-interview
description: "Use when the ask is underspecified and you cannot yet write a Done Contract with Check: commands. One question at a time, with a falsifiable guess."
---

# Agentic Interview

Extract what the user actually wants. Not a confidence-score ritual.

## When

- `/agentic-task` cannot write 1–3 testable assertions.
- Buzzwords ("scalable", "clean architecture") are doing the talking.
- Two audiences or two success metrics are still live.

## Process

1. One-sentence hypothesis. If you cannot write a Done Contract, say what is missing.
2. **One question per turn**, followed by `GUESS: <what you think they'll say and why>`. Questions that are already independent of each other may share one round. A question the previous answer would dissolve waits.
3. Stop when you can predict the next three answers — then emit the Restate Contract and wait for an explicit yes.
4. Hand off to `/agentic-task` with that contract copied verbatim. Anything still unanswered goes under `## Open questions`, and the ticket stays `blocked-on-answers` until the user sets `status: open`.

### Restate Contract (six lines)

- Outcome
- User
- Why now
- Success
- Constraint
- **Out of scope** (mandatory)

## Rationalizations

| Excuse | Rebuttal |
|---|---|
| I'll batch five questions | They'll answer the easy one and skip the load-bearing one. |
| They said "whatever you think" | That is not a yes to the Restate Contract. Ask once more. |

## Verification

A ticket exists whose Restate Contract the user accepted, with Out of scope filled.