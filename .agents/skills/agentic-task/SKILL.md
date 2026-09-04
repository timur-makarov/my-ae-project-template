---
name: agentic-task
description: "Use when the user asks for new work — a feature, a bug report, a question, or an idea — that should become a tracked ticket."
---

# Agentic Task: Intent → Ticket

Convert a raw ask into a ticket sized to its risk. The judgment rules (intent reading, blast radius, done contracts) live in the constitution rule and apply here in full; this skill adds the procedure and the artifact.

## Process

### 1. Orient

- Read `.agentic/map.md` (destination, frontier) and `.agentic/context/CONTEXT.md` (glossary, invariants, risk boundaries).
- Grep `.agentic/journal/lessons.md` for entries touching this area.
- Next ticket number = max across `tickets/open/` and `tickets/closed/` + 1, zero-padded (`01`, `02`, ...).
- Read `.agents/skills/agentic-route/SKILL.md`. Vague concept → `/agentic-idea` first. No writable Done Contract → `/agentic-interview` first.

### 2. Deconstruct the request

Apply the constitution's intent rules and record the results, not the ceremony:
- Restatement (outcome, for whom, quality bar), kind classification, cause, small-words findings, problem-vs-mechanism check.
- **Done Contract:** 1–3 testable assertions. If you can't write them, you don't understand the ask — `/agentic-interview`, don't invent checks.
- Full tickets: fill the six-line Restate Contract (Out of scope required). Lite: one-line Out of scope.
- Front matter: `reversibility`, `rollback`, `network`, `new_deps`. `irreversible` without a compensating rollback is EXPANDING.

### 3. Price the risk → pick the template

- **Tier:** probability × cost × detection lag. Data/money boundaries, public APIs, auth, irreversible operations, or anything in CONTEXT.md's Risk Boundaries → MEDIUM at minimum; irreversible/public/expensive-wrong → HIGH.
- **LOW** → `.agentic/templates/ticket-lite.md` (~15 lines; no claims table, no DAG).
- **MEDIUM / HIGH** → `.agentic/templates/ticket-full.md` (pre-mortem, loss asymmetry, load-bearing claims, pieces ordered by information yield).
- Never fill full-template sections with boilerplate: a field you'd fill with a platitude is a field this ticket doesn't need — that's what the lite template is for.

### 4. Blast-radius gate

- NARROWING → proceed; state the reading taken in the ticket.
- EXPANDING → Status `blocked-on-alignment`, list under map.md §4 Fog of War, and either ask the single decisive question or point to `/agentic-grill`. Never place on the Active Frontier.

### 5. Write & validate

- Write `tickets/open/<NN>-<slug>.md` from the YAML-front-matter template. Required fields: status, type, risk_tier, template, blocked_by, scope_paths, reversibility, rollback, Done Contract assertions each with a `Check:` command token. Title must not contain ` and ` unless `type: wide-refactor`. More than `limits.max_scope_globs` paths requires `## Capability Map`. MEDIUM/HIGH: `## Definition of Done` from `.agentic/references/dod.md`.
- Run `scripts/ticket-lint.sh .agentic/tickets/open/<NN>-<slug>.md` — fix violations before reporting. The lint passing is the definition of "ticket created". Path-floor warnings (stated scope intersecting a higher `risk_paths` floor) are warnings at creation; `gate.sh pr` fails them against the real diff.
- Update map.md: §3 Active Frontier (unblocked) or §4 Fog of War (blocked), with `Blocked by:` dependencies if another ticket must land first.

### 6. Tracker sync (only if `tracker: github-issues` in config.yml)

`gh issue create --title "NN — <title>" --body-file <ticket path>` and record the issue URL in the ticket header. Local markdown stays the source of truth; the issue is a mirror.

### 7. Report

1. Sentence 1: the ticket created, locked to the user's request terms.
2. Proof sketch: restatement, Done Contract, risk tier, blast-radius classification, lint result.
3. Next action: `/agentic-implement <NN>` (unblocked) or `/agentic-grill` (blocked).
