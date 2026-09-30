# Review — Ticket NN

**Head:** <commit sha from the brief>
**Reviewer:** <agentic-evaluator | security-auditor | command>

## Claims

One row per Done Contract assertion, at least. Each command must be runnable from the repo root;
the gate re-runs every one and a failure blocks ship. Write a pipe inside a command as `\|`. A claim that says "all" or "never" gets a
second row with an input chosen to break it.

| Claim | Command | Result |
|---|---|---|
| <assertion, in your words> | `<command>` | held |

## Tests

Would the tests fail without this change? Name the test and the line that proves it, or say they
wouldn't and why that matters.

## Findings

A finding cites a changed `file:line`, or a command you ran and the fact that it failed. No cap.
Security reports also name a class: `injection`, `authz`, `secret`, `supply-chain`, `prompt-injection`.

- F1: <file:line or `command` failed — what the claim said and what the code did>

## Not in this contract

<one sentence, or none. This does not set CHANGES_REQUESTED.>

## Verdict

**Verdict:** APPROVED
**Watchlist:** 1) <what to watch after merge> 2) <the signal that would mean it failed>
