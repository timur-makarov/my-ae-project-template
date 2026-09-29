# Critic Report — Ticket NN

**Seat:** same-agent

## Claims

One row per Done Contract claim. The command is what the action journal must contain. A claim that says "all" or "never" gets a second row.

| Claim | Command | Result |
|---|---|---|
| | `command` | held |

## Findings

A miss cites a changed `file:line` or a command that was run and failed. No cap. Security reports also name a class id: `injection`, `authz`, `secret`, `supply-chain`, or `prompt-injection`.

- Finding F1: <file:line or `command` failed — what the claim said and what the code did>

## Not in this contract

<one sentence, or none. This does not set CHANGES_REQUESTED and it does not start another pass.>

## Epicycles

- **Epicycle count:** 0

## Verdict

- **Verdict:** APPROVED
- **Watchlist:** 1) <what to watch after merge> 2) <the line that would signal failure>
