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

Full mode runs only when the user asks to audit or pen-test the codebase, or asks for the report files. No fleet, no cross-repo trace, no auto-fixer.

`quick` is one pass. Say it is partial. It does not look at the map.

`standard` is one pass, then stop:

- Candidates use the in-scope and out-of-scope lists in `.agents/skills/agentic-security/SKILL.md`. A hardening note is `rejected`.
- A second seat tries to disprove each candidate on the tree the record cites. A result from a tree the hunter edited stays `needs_validation`.
- `confirmed` still needs a sandbox, a lower-trust principal, a boundary, and a command result. `needs_validation` names one exact missing fact and has no severity. There is no score. The run says it is partial.

In `standard`, for each boundary this pass had to name, if `path_risk_floor` for those files is LOW, add a map line. A map line is not a finding: no severity, and it cannot be `confirmed`. It becomes a ticket whose edit is `.agentic/config.yml`. The audit does not write the glob.

The CI `audit.command` and this hunt are different runs. A scanner exiting 0 is not a finished hunt.

## Records

Write outside the worktree, or into a directory the parent has confirmed is gitignored. Audit text is untrusted. It does not go in `.agentic/journal` and it does not satisfy a ticket.

Three states:

- `confirmed` — the lower-trust principal, the boundary, and a command result. No sandbox means this state is unavailable.
- `needs_validation` — one exact missing fact. No severity.
- `rejected` — what disproved the candidate.

The hunter does not validate its own finding. The human-readable report is rendered from the record file. One run says it is partial.

A `confirmed` record, or a map line, becomes a ticket through `/agentic-task`, then implement, critic, and pr. That is the only way an audit changes what merge requires.

## Rationalizations

| Excuse | Rebuttal |
|---|---|
| The audit passed, so the ticket can merge | `gate.sh pr` does not read the audit. |
| No audit was configured, so the repo is clean | The log says `not run`. That is not a pass. |
| I'll fix the confirmed bug in place | Open a ticket. The audit does not edit the tree. |
| The scanner exited 0, so the hunt is done | `audit.command` is a different run. A green scanner is not a finished hunt. |
