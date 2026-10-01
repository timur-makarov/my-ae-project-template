---
name: agentic-critic
description: "Use when a MEDIUM or HIGH ticket's diff needs an adversarial review before it ships, or when you are the reviewer handed a brief. The LOW fast lane skips this."
---

# Agentic Critic: The Reviewer

The author doesn't review its own work. `scripts/gate.sh advance NN` builds a payload in
`.agentic/state/payload-NN/` and names a brief. A separate agent seat reads it and writes the report.

Security is a later seat. Do not start it in the same turn as the critic. It runs only after the
author has judged the critic's findings.

## Spawning (the author)

`critic.command` is one project setting, chosen once. A ticket does not switch it.

- **Empty command** (Mode A): start a seat that did not write this change. Give it the brief path,
  `.agentic/state/payload-NN/BRIEF.md`, and tell it to review per that brief. One seat. The security
  brief does not exist yet.
- **Command set** (Mode B): `advance` runs `critic.command` for the critic report, then stops if
  there are findings to judge. Security uses the same command later, on its own brief.

The report is a findings list. You judge it. A finding is fixed when an ordinary caller of the
template, or of a project built with it, hits the changed logic. Otherwise decline it. Unsure
means fix. Write one line per in-bound finding in `.agentic/journal/NN-critic-response.md`:

```
F1: fixed
F2: declined
```

Do not edit the reviewer's report. A finding that does not cite a changed line is already
ignored; leave it out of the response. Then `advance`. Security starts only after this file
covers every in-bound critic finding.

## Reviewing (the evaluator)

The brief names the evidence (`contract.md`, `diff.md`, `checks.json`, `verify-stamp.json`) and
the report path. Edit nothing but the report.

Review the changed lines and the logic those lines implement. Reading the containing block is
allowed. Anything else is forbidden:

- unchanged files and unchanged lines
- imagined inputs, encodings, and cousin cases
- a verdict
- claim commands

A finding cites one changed line as `` `path:line` `` and names the ordinary caller who hits it.
If the changed lines hold, the findings list is the single word `none`.

Write the report from `.agentic/templates/critic_report.md`, with the `**Head:**` line exactly as
the brief gives it.

## Rationalizations

| Excuse | Rebuttal |
|---|---|
| The checks passed, so there is nothing to say | Read the changed lines. A miss there is a finding. |
| One more imagined shape, then I'm done | Imagined shapes are forbidden. |
| I'll write a verdict so the gate stops them | You return a list. The author judges it. |
