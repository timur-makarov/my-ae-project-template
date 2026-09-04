# Critic Report — Ticket NN

> **Evaluator:** isolated critic subagent (evidence only: diff, raw test output, Done Contract — zero generator narrative)
> **Verdict:** `APPROVED` | `CHANGES_REQUESTED` | `REOPEN_REQUIRED`
> **Attack depth:** `standard` (MEDIUM) | `full` (HIGH — every hostile input executed live)

## Attack 1 — Counterexample Hunt

Universal quantifiers targeted ("all/never/always" claims in ticket or diff): <list or none>

| ID | Hostile input | Command run | Pasted output (exact) | Verdict |
|---|---|---|---|---|
| F1 | empty / zero / null | | | PASS/FAIL |
| F2 | boundary / max / duplicates | | | PASS/FAIL |
| F3 | concurrency / timing / partial failure | | | PASS/FAIL |
| F4 | unicode / malformed / metacharacters | | | PASS/FAIL |

**Findings:** <did anything break? explain. Each finding keeps its stable ID (F1…). A repeated ID across two fix rounds short-circuits to adjudication.>

## Attack 2 — Rival-Cause Hunt

*(For diagnoses and performance claims; mark N/A for pure feature work.)*

- **Primary hypothesis:** <what the diff claims fixed/caused>
- **Rivals:** 1) <alternative cause fitting the same symptoms> 2) <second alternative>
- **Discriminating test:** `<command>` → `<pasted output>` → **verdict:** PRIMARY_CONFIRMED | RIVAL_CONFIRMED | INCONCLUSIVE

## Attack 3 — Consequence Walk

- **Upstream preconditions checked:** <what had to be true before — result>
- **Downstream postconditions checked:** <what must hold now — result>
- **Sibling callers of modified functions:** <grepped list — affected? result>

## Cold-Read Audit

- [ ] Every changed line traces to the Done Contract (no silent scope expansion)
- [ ] Quoted tool output actually says what is claimed, read cold (no laundering)
- [ ] Original user goal exercised end-to-end, not just internal steps
- [ ] No unasked abstraction, config, or speculative generality in the diff
- [ ] Tests assert real behavior, not mock behavior; suite output pristine
- [ ] No unhedged unsourced claims; guesses labeled at point of use
- [ ] Numeric performance claims are measured (command + output) or marked `not measured`

## Epicycles & Kill Condition

- **Precommitted kill condition:** <the observable result that forces abandoning this approach>
- **Epicycle count:** <0 | 1 | 2+> — *2+ patches defending one conclusion = REOPEN_REQUIRED*

## Verdict & Deploy Watchlist

- **Verdict:** <APPROVED | CHANGES_REQUESTED | REOPEN_REQUIRED> — <one-sentence reason>
- **Watchlist:** 1) <top decaying fact / dynamic risk to watch after merge> 2) <metric or log line that signals failure>
