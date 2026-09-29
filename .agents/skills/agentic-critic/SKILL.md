---
name: agentic-critic
description: "Use when a MEDIUM or HIGH ticket's diff needs an adversarial pass before it ships. The fast lane skips this hop."
---

# Agentic Critic

Scripts already run the ticket's `Check:` commands and refuse a diff that leaves scope. Do not repeat those two facts. The job is to take each claim in the ticket and try to break it on the code that actually changed.

The fast lane (LOW and `risk.low_fast_lane`) skips this hop. When the hop runs, the same agent writes the report. Do not spawn a subagent for this report. `models.critic` is a label until a separate process is started; this hop does not start one.

**Seat:** `same-agent` on MEDIUM. That is the whole derivation: each claim has a command in the action journal. A sentence that says the claim held, with no command, is not a verdict.

## Scope

The ticket's claims and the diff. For each Done Contract claim, name one input that should break it, run that input, and put the command in the Claims table. A claim that says "all" or "never" gets a second row. `type: diagnosis`, and any number, still need the rival or the words `not measured`. Sibling callers of a modified function are one sentence under `Not in this contract`, or one claim row.

A finding is a line in the diff that does not do what the claim says, or a command that failed against that code. Cite the changed `file:line`, or the command and the fact that it failed. There is no cap on real misses.

The read-only payload from `scripts/gate.sh critic` is for the HIGH security persona. This report's evidence is the Claims table plus the action journal.

## Out of scope

- Files that are not in the diff and not in the fixtures the check already uses.
- A demand that the author prove no future file can break the claim.
- A second shape after a real miss has already been named.

One sentence under `Not in this contract` is allowed. It does not set `CHANGES_REQUESTED` and it does not start another pass.

## One report

Write `.agentic/journal/<NN>-critic.md` from `.agentic/templates/critic_report.md`. One verdict line, one enum value. Run `scripts/gate.sh critic <NN>` once to assemble the payload; it refuses a second payload if that report already exists. `scripts/gate.sh critic <NN> --again` asks.

`scripts/artifact-lint.sh` rejects a verdict menu, an `APPROVED` report with no claim command, a missing `Seat:` line, and a finding that cites neither a changed `file:line` nor a command that was run and failed. `scripts/evidence-check.sh --hostile` requires each Claims-table command to appear in `actions-*.jsonl`. Zero commands cannot be `APPROVED`.

## Verdict

`APPROVED` when every claim row's command is in the journal and held. `CHANGES_REQUESTED` when a cited line or a failed command breaks a claim. `REOPEN_REQUIRED` when the claim's approach is wrong, not a line. Two patches defending one conclusion is the epicycle: reopen, don't patch again.

## Rationalizations

| Excuse | Rebuttal |
|---|---|
| The checks passed, so the claim holds | The scripts already ran the checks. Read the changed branches. |
| I'll name a file that might exist later | A finding cites a changed line or a command that failed. |
| One more shape, then I'm done | A real miss is already a finding. A second imagined shape is not another pass. |
| I set models.critic to another family | Nothing in this hop starts that model. The journal is the check. |
