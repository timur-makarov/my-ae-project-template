---
name: agentic-init
description: "Use when bootstrapping the agentic environment in a new project, after copying the template in, or when the .agentic structure looks broken or incomplete."
disable-model-invocation: true
---

# Agentic Init: Bootstrap the Environment in a Project

Turn the copied template into a working environment for *this* project. Idempotent: safe to re-run; never overwrites existing tickets, decisions, or journal history.

## Procedure

### 1. Verify structure

Ensure this hierarchy exists (create missing pieces from `.agentic/templates/`, report — don't overwrite — existing ones):

```
.agentic/
├── config.yml
├── map.md
├── context/CONTEXT.md
├── context/adr/
├── tickets/open/  tickets/closed/
├── journal/  journal/reviews/  journal/lessons.md
├── state/enforcement.sha256
├── references/dod.md
└── templates/  (ticket-lite, ticket-full, critic_report, adr, pr, handoff)
scripts/verify.sh  scripts/ticket-lint.sh  scripts/review-package.sh
scripts/gate.sh  scripts/stamp-check.sh  scripts/env-lint.sh
scripts/evidence-check.sh  scripts/artifact-lint.sh  scripts/debt-lint.sh
scripts/model-check.sh  scripts/selftest.sh  scripts/lib.sh  scripts/floor-guard.sh
.cursor/rules/constitution.mdc  .cursor/rules/default_swe.mdc
.cursor/hooks.json  .cursor/hooks/guard.sh  .cursor/hooks/audit.sh
.cursor/hooks/protect.sh  .cursor/hooks/session-start.sh
.github/workflows/agentic-gates.yml
```

### 2. Git

- If not a git repo: `git init`, initial commit, create the base branch named in `config.yml` (`base_branch`).
- Ensure `.gitignore` contains the `worktree_dir` from config (default `.worktrees/`) plus `.agentic/state/active-ticket`, `close-authorized-*`, `critic-payload-*`, and `scope-*.txt`. The `.agentic/` tree itself is **committed** — it's the project's memory. `enforcement.sha256` is committed; ephemeral state files are not.

### 3. Fill project specifics (ask the human for what you can't detect)

- `config.yml` → `verify:` block: detect the stack (package.json / Cargo.toml / pyproject.toml / go.mod / Makefile...) and propose real commands for `test`, `lint`, `typecheck`, `e2e`. Confirm before writing. The template ships `scripts/selftest.sh` as `verify.test` to prove the environment; replace it with the host project's suite once that exists.
- `config.yml` → `risk_paths`: keep the defaults; add project-specific floors (`migrations/**`, `**/auth/**`, payment paths).
- `config.yml` → `models:`: leave `inherit` unless the human names slugs that also appear in `models_allowed`.
- `config.yml` → `scope.strict: true` after the human confirms the copy is the real project (the template ships false so first edits aren't bricked).
- `config.yml` → `craft_skills`: keep true unless the host wants the spine only.
- `map.md` → **Destination**: one sentence, from the human. Don't invent it.
- `context/CONTEXT.md`: seed glossary/invariants if the project already has code worth reading.

### 4. Prove the gate works

Run `scripts/verify.sh` then `scripts/env-lint.sh --write-manifest` after any enforcement-file change. A warning about an empty verify block means step 3 is unfinished — the environment is not initialized until the gate proves something.

### 5. Report

- Structure status, git status, verify output (pasted).
- The workflow: `/agentic-route` if unsure → `/agentic-task` → (`/agentic-grill` if blocked) → `/agentic-implement` → `/agentic-pr` → `/agentic-archive`; `/agentic-status` anytime; `/agentic-handoff` when stopping mid-ticket; `/agentic-postmortem` when shipped work regresses.
