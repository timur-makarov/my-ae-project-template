---
name: agentic-init
description: "Use when bootstrapping the agentic environment in a new project, after copying the template in, or when the .agentic structure looks broken or incomplete."
disable-model-invocation: true
---

# Agentic Init: Bootstrap the Environment in a Project

Turn the copied template into a working environment for *this* project. Idempotent: never
overwrites existing tickets, decisions, or journal history.

## 1. Verify structure

```
AGENTS.md
.agentic/  config.yml  map.md  context/{CONTEXT.md,adr/}  tickets/{open,closed}/
           journal/lessons/  references/{dod,judgment}.md  templates/
scripts/   gate.sh verify.sh stamp-check.sh lib.sh ticket-lint.sh env-lint.sh memory-lint.sh
           debt-lint.sh floor-guard.sh model-check.sh review-package.sh selftest.sh
scripts/hooks/  guard.sh protect.sh mcp-guard.sh session-start.sh stop.sh audit.sh adapt.sh
.cursor/   hooks.json  agents/agentic-evaluator.md
.claude/   settings.json  agents/agentic-evaluator.md  skills/* -> ../../.agents/skills/*
.codex/    config.toml  hooks.json  rules/agentic.rules
.github/workflows/agentic-gates.yml
```

Requires `git`, `jq` and `python3`. The hooks deny everything without jq (fail closed).

## 2. Git

- Not a repo: `git init`, initial commit, create `base_branch` from config.
- `.gitignore` has `.worktrees/` and `.agentic/state/`. Everything else under `.agentic/` is committed.
- Codex: trust the project, then review the hooks in `/hooks` (Codex re-asks after every hook change).

## 3. Fill project specifics (ask the human for what you can't detect)

- `verify:` detect the stack (package.json / Cargo.toml / pyproject.toml / go.mod / Makefile) and
  propose real `test`, `lint`, `typecheck`, `e2e` commands. Confirm before writing. The template's
  `scripts/selftest.sh` proves the environment itself; replace it with the host suite.
- `scope.strict: true` once the host suite is wired, so product edits need a claimed ticket.
  `ticketless_paths` lists globs that stay editable without one (docs, say).
- `risk_paths`: keep the defaults; add project floors (auth, payments, migrations paths).
- `guard:`: defaults give the agent broad freedom (network and installs allowed; secrets denied).
  Tighten only on the human's word. `guard.network` must match `.codex/config.toml`
  `network_access` (env-lint checks).
- `models:` stay `inherit` unless the human names slugs listed in `models_allowed`.
- `map.md` Destination: one sentence, from the human. Don't invent it.
- `CONTEXT.md`: seed the glossary and invariants if the project has code worth reading; every
  load-bearing row needs `cite:path needle:"token"`.

## 4. Prove it works

`scripts/verify.sh` and `scripts/env-lint.sh` both exit 0, and `scripts/gate.sh next` prints a rest row.

## 5. Report

Structure status, verify output (pasted), and the workflow: `/agentic-task` →
`scripts/gate.sh advance NN` until it ships → `/agentic-pr`.
