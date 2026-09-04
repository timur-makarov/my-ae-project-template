# Domain Context

> Distilled long-term memory. Updated by `/agentic-archive`, read by every planning
> and implementation pass. Hard cap: `limits.context_md_max_lines` in `config.yml`.

## Ubiquitous Language & Glossary

| Term | Meaning in this project |
|---|---|
| Spine | `/agentic-task` → implement → critic → pr → archive |
| Stamp | JSONL row from `verify.sh` (HEAD, dirty, exit). Gates read this, not the model. |
| Floor | Diff-scoped cheap-green detector (`scripts/floor-guard.sh`) |
| On-the-loop | Human at blast expansion and HIGH merge, not between every piece |
| Craft | Optional domain skills gated by `craft_skills` |

## System Architecture & Invariants

- Prose never authorizes a stage transition; `scripts/gate.sh` does.
- Pipe-to-interpreter and vendor `install.sh` are deny, not ask.
- File tools cannot write outside the worktree or to secret/key paths without HIGH+scope.
- `config.yml` is the only number store. Markdown twins will drift.

## Risk Boundaries

- Enforcement layer: `.cursor/`, `scripts/`, templates, `config.yml`, GitHub workflow.
- Host auth, payments, migrations (see `risk_paths`).
- Remote fetch and new dependencies (ticket `network` / `new_deps`).

## ADR Index

- [0001 — Enforcement vs convention](adr/0001-enforcement-vs-convention.md) — scripts authorize; skills on trigger; human on-the-loop.
