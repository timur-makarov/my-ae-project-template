---
name: agentic-task
description: "Use when the user asks for new work — a feature, a bug report, a question, or an idea — that should become a tracked ticket."
---

# Agentic Task: Intent → Ticket

Convert a raw ask into a ticket sized to its risk. The judgment rules (intent, blast radius, done
contracts) are in `AGENTS.md` § How to work and `.agentic/references/judgment.md`; this skill adds
the procedure and the artifact.

## 1. Orient

- Read `.agentic/context/CONTEXT.md` (glossary, invariants, risk boundaries).
- Grep `.agentic/journal/lessons/` for lessons touching this area.
- Vague concept → `/agentic-idea` first. No writable Done Contract → `/agentic-interview` first.

## 2. Price the risk

Probability × cost × detection lag. Data/money boundaries, public APIs, auth, irreversible
operations, anything in CONTEXT.md's Risk Boundaries → MEDIUM at least; irreversible, public or
expensive-wrong → HIGH. The tier must cover every `risk_paths` floor the diff will touch; the
hooks and the gate refuse writes above it.

## 3. Create

```
scripts/gate.sh new <slug> --tier LOW|MEDIUM|HIGH [--title "..."]
```

This reserves the next ticket number atomically (safe with parallel agents) and copies the lite
(LOW) or full (MEDIUM/HIGH) template into `.agentic/tickets/open/NN-<slug>.md`.

## 4. Fill

- **Request:** Verbatim, Restatement, Cause, Out of scope (required). Full template: the six-line
  Restate Contract and problem-vs-mechanism check.
- **Done Contract:** 1–3 testable assertions, each with `Check: \`<command>\``: a focused
  runnable command, not the blanket suite. The gate runs these; they define done.
- **Front matter:** `scope_paths` (the globs you will edit; frozen at claim), `reversibility`,
  `rollback`, `new_deps`, `blocked_by`. `irreversible` without a compensating rollback is EXPANDING.
- **Open questions:** `none`, or real questions. A question means `status: blocked-on-answers`.
  One question per turn. List together only questions that are already independent of each other.
  Template leftovers (a single `<placeholder>`, or `TBD`) fail lint.
- New tickets start at `status: blocked-on-answers`. Do not set `status: open`. The human does
  that after accepting the Restate Contract (lite: the Restatement). Until then `gate.sh next`
  stays on a human row, and product writes are denied.
- Never fill full-template sections with platitudes; a field you'd fill that way is one the ticket
  doesn't need.

## 5. Blast-radius gate

- NARROWING → proceed; state the reading taken. The ticket still waits at `blocked-on-answers` until the human accepts it.
- EXPANDING → `status: blocked-on-alignment` and `/agentic-grill`. `gate.sh next` routes it to a human. That status replaces `blocked-on-answers` until the grill settles.

## 6. Validate

`scripts/ticket-lint.sh .agentic/tickets/open/NN-<slug>.md` passing is the definition of "ticket
created". Tracker `github-issues`: `gh issue create --title "NN — <title>" --body-file <ticket>`;
local markdown stays the source of truth.

## 7. Report

Sentence 1: the ticket created, in the user's terms. Then Done Contract, tier, blast radius, lint
result. Next: `scripts/gate.sh advance NN` (or `/agentic-grill`).
