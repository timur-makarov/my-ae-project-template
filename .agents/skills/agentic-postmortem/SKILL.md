---
name: agentic-postmortem
description: "Use when shipped work regresses, a closed ticket's fix turns out wrong, or a defect escaped the critic and reached users."
---

# Agentic Postmortem: When Shipped Work Breaks

A regression on a closed ticket is two failures: the defect, and the process hole that let it through. Fix both, and make the second one pay for itself.

## 1. Contain and reproduce

- Reproduce the symptom first — a failing test or exact command with pasted output. No reproduction → gather evidence, don't guess.
- If damage is ongoing (data corruption, money, public breakage): smallest reversible containment first (revert the merge is usually it), diagnosis second.

## 2. Diagnose against the original conclusion

The closed ticket claimed a conclusion that reality just disputed. Do not patch the symptom:

- Re-read the closed ticket's Resolution and its critic report (`journal/<NN>-critic.md`). The "fixed" label is now evidence *against* the original diagnosis — the bar is higher this time.
- Run the rival-cause hunt: what else produces exactly this symptom? The original hypothesis is one candidate among several, and it just lost credibility. Find the discriminating observation before choosing.
- Check the critic report's deploy watchlist — did it name the thing that broke? (That's process signal either way.)

## 3. Fix through the pipeline, not around it

Open a new ticket via `/agentic-task` (type `diagnosis`, risk tier at least the original's, linked to the closed ticket: `Regression of NN`). The fix flows through implement → critic → pr like any work — regressions are where skipping process is most tempting and most expensive.

## 4. Close the process hole

This is the step that makes the environment improve itself:

- **Lessons** — in the fixing ticket's `.agentic/journal/lessons/NN.md`: `- [NN] YYYY-MM-DD <defect that escaped> — <the check that would have caught it> — cite:path needle:"token"`.
- **metrics.jsonl** — read recent `gate` / `critic` events: a critic that returns no findings on every MEDIUM ticket is a broken critic.
- **Check or guard** — if a command or a `guard.sh` pattern would have caught the escaping defect, add that `Check:` or that pattern.
- **CONTEXT.md** — if the regression revealed an invariant or risk boundary nobody had written down, write it down now (`cite:path needle:"token"` on the row).
- **Verify gate** — if a deterministic check could have caught it, add it to the project's verify commands (config `verify:` block) or test suite, so prose never has to remember it again.
- **Floor** — a path this app keeps treating as ordinary, and that was a real boundary, goes into this project's `risk_paths` via its own ticket. Promotion only adds a floor or a check. Loosening the map is a HIGH ticket. A shape true in every copy is a ticket on the template repo, not an edit from this product diff.

## 5. Report

Sentence 1: what regressed and the root cause (or the discriminating test still needed). Then: original conclusion vs. what was actually true, the new ticket, and — explicitly — which process hole was closed and how.
