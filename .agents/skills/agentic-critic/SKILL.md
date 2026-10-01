---
name: agentic-critic
description: "Use when a MEDIUM or HIGH ticket's diff needs an adversarial review before it ships, or when you are the reviewer handed a brief. The LOW fast lane skips this."
---

# Agentic Critic: The Reviewer

The author doesn't review its own work. `scripts/gate.sh advance NN` builds a payload in
`.agentic/state/payload-NN/` and names a brief. A separate agent seat reads it and writes the report.

## Spawning (the author)

`critic.command` is one project setting, chosen once. A ticket does not switch it.

- **Empty command** (Mode A): start a seat that did not write this change. Give it the brief path,
  `.agentic/state/payload-NN/BRIEF.md`, and tell it to review per that brief. If `BRIEF-security.md`
  exists, start a second seat on that brief in the same turn.
- **Command set** (Mode B): `advance` runs `critic.command`. Nothing to spawn. The command reads
  `AGENTIC_BRIEF` and prints the report.

Then `advance`: it re-runs every command in the report's Claims table. A report changed after a
Mode B reviewer wrote it is refused.

## Reviewing (the evaluator)

The brief names the evidence (`contract.md`, `diff.md`, `checks.json`, `verify-stamp.json`) and
the report path. You may read any file and run read-only commands; edit nothing but the report.
The gate has already run the Done Contract checks and scope rules, so don't restate them.

1. **Each claim, attacked.** For each Done Contract assertion, pick the input most likely to break
   it, run it, and record the command in the Claims table. A claim that says "all" or "never" gets
   a second row. `type: diagnosis` and any number need the rival, or the words `not measured`.
2. **The tests.** Would they fail without this change? Read them against the diff. A test that
   passes on the old code proves nothing; say so as a finding.
3. **The diff.** A finding is a changed line that doesn't do what the claim says, or a command
   that failed. Cite `file:line` or the command. There's no cap on real misses; imagined future
   files are not findings. Sibling callers of a changed function get one sentence or one claim row.
   If the change moves untrusted input into a sink, apply the finding bar in
   `.agents/skills/agentic-security/SKILL.md` in this same report. One reviewer. A second seat
   still runs only when `BRIEF-security.md` is in the brief set.
4. **Standing bar:** `.agentic/references/dod.md` for the ticket's tier.

Write the report from `.agentic/templates/critic_report.md`, with the `**Head:**` line exactly as
the brief gives it and one `**Verdict:**`:

- `APPROVED`: every claim row held and the tests prove the change.
- `CHANGES_REQUESTED`: a cited line or a failed command breaks a claim, or the tests don't prove it.
- `REOPEN_REQUIRED`: the approach is wrong, not a line.

## Rationalizations

| Excuse | Rebuttal |
|---|---|
| The checks passed, so the claim holds | The gate ran them. Your job is the input they didn't try. |
| The tests exist, so it's tested | Would they fail on the old code? |
| One more imagined shape, then I'm done | A real miss is already a finding. |
| I'll approve and note concerns | A concern that breaks a claim is CHANGES_REQUESTED. |
