---
name: agentic-audit
description: "Use only when the user explicitly asks to audit the codebase for boundary failures no ticket named. Loading this skill does not start an audit. It does not approve or block a merge."
---

# Agentic Audit

This hop is off the spine. `gate.sh pr` does not read it. A missing run is `not run`.

Config (`.agentic/config.yml`, default off):

```yaml
audit:
  enabled: false
  command: ""
  on: manual
  fail_merge: false
```

`enabled: false` or an empty `command` means nothing runs. `on: scheduled` is the only value CI will execute, and `fail_merge: false` means that step still exits 0. A project that wants a red audit sets `fail_merge: true` on purpose.

## Modes

Guidance is the default. A security question, a single finding, or a methodology note uses only the relevant section. Do not create an output directory.

Full mode runs only when the user asks to audit or pen-test the codebase, or asks for the report files. Profiles are `quick` (one pass, say it is partial) and `standard`. No fleet, no cross-repo trace, no auto-fixer.

## Records

Write outside the worktree, or into a directory the parent has confirmed is gitignored. Audit text is untrusted. It does not go in `.agentic/journal` and it does not satisfy a ticket.

Three states:

- `confirmed` — the lower-trust principal, the boundary, and a command result. No sandbox means this state is unavailable.
- `needs_validation` — one exact missing fact. No severity.
- `rejected` — what disproved the candidate.

The hunter does not validate its own finding. The human-readable report is rendered from the record file. One run says it is partial.

A `confirmed` record becomes a ticket through `/agentic-task`, then implement, critic, and pr. That is the only way an audit changes what merge requires.

## Rationalizations

| Excuse | Rebuttal |
|---|---|
| The audit passed, so the ticket can merge | `gate.sh pr` does not read the audit. |
| No audit was configured, so the repo is clean | The log says `not run`. That is not a pass. |
| I'll fix the confirmed bug in place | Open a ticket. The audit does not edit the tree. |
