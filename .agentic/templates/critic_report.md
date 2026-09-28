# Critic Report — Ticket NN

> **Verdict:** `APPROVED` | `CHANGES_REQUESTED` | `REOPEN_REQUIRED`

## Claims

For each Done Contract claim: the branch, condition, or error path in the diff, and the input you tried.

| Claim | Changed line or failed command | Result |
|---|---|---|
| | `path:line` or `` `command` `` failed | held / miss |

## Findings

A miss cites a changed `file:line` or a command that was run and failed. No cap.

- Finding F1: <file:line or `command` failed — what the claim said and what the code did>

## Not in this contract

<one sentence, or none. This does not set CHANGES_REQUESTED and does not start another pass.>

## Epicycles

- **Epicycle count:** <0 | 1 | 2+> — 2+ patches defending one conclusion = REOPEN_REQUIRED

## Verdict & Deploy Watchlist

- **Verdict:** <APPROVED | CHANGES_REQUESTED | REOPEN_REQUIRED> — <one sentence>
- **Watchlist:** 1) <what to watch after merge> 2) <the line that would signal failure>
