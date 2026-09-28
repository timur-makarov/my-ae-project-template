---
name: agentic-critic
description: "Use when a MEDIUM or HIGH ticket's diff needs an adversarial pass before it ships. The fast lane skips this hop."
---

# Agentic Critic

Scripts already run the ticket's `Check:` commands and refuse a diff that leaves scope. Do not repeat those two facts. The job is to take each claim in the ticket and try to break it on the code that actually changed.

The fast lane (LOW and `risk.low_fast_lane`) skips this hop. When the hop runs, the same agent writes the report. Do not spawn a subagent or another critic.

## Scope

The ticket's claims and the diff. For each claim, look at the branches, conditions, and error paths in the changed lines and try to name an input that claim fails on. Run it when the changed code can accept it.

A finding is a line in the diff that does not do what the claim says, or a command that failed against that code. Cite the changed `file:line`, or the command and the fact that it failed. There is no cap on real misses.

## Out of scope

- Files that are not in the diff and not in the fixtures the check already uses.
- A demand that the author prove no future file can break the claim.
- A second shape after a real miss has already been named.

One sentence under `Not in this contract` is allowed. It does not set `CHANGES_REQUESTED` and it does not start another pass.

## One report

Write `.agentic/journal/<NN>-critic.md` from `.agentic/templates/critic_report.md`. Run `scripts/gate.sh critic <NN>` once to assemble the payload; it refuses a second payload if that report already exists. `scripts/gate.sh critic <NN> --again` asks.

`scripts/artifact-lint.sh` rejects a finding that cites neither a changed `file:line` nor a command that was run and failed. `scripts/evidence-check.sh` still checks that the ticket's `Check:` commands appear in the action journal.

## Verdict

`APPROVED` when every claim you could try on the changed lines held. `CHANGES_REQUESTED` when a cited line or a failed command breaks a claim. `REOPEN_REQUIRED` when the claim's approach is wrong, not a line. Two patches defending one conclusion is the epicycle: reopen, don't patch again.

## Rationalizations

| Excuse | Rebuttal |
|---|---|
| The checks passed, so the claim holds | The scripts already ran the checks. Read the changed branches. |
| I'll name a file that might exist later | A finding cites a changed line or a command that failed. |
| One more shape, then I'm done | A real miss is already a finding. A second imagined shape is not another pass. |
