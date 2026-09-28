# Domain Context

> Distilled long-term memory. Updated by `/agentic-archive`, read by every planning
> and implementation pass. Hard cap: `limits.context_md_max_lines` in `config.yml`.
> Load-bearing rows need `cite:path needle:"token"` (glossary Cite column). ADR
> index markdown links are cites; needle optional there.

## Ubiquitous Language & Glossary

| Term | Meaning in this project | Cite |
|---|---|---|
| Spine | `/agentic-task` → implement → critic → pr → archive | `.agents/skills/agentic-route/SKILL.md` needle:"/agentic-archive" |
| Stamp | JSONL row from `verify.sh` (HEAD, dirty, exit). Gates read this, not the model. | `scripts/verify.sh` needle:"VERIFY" |
| Floor | Diff-scoped cheap-green detector (`scripts/floor-guard.sh`) | `scripts/floor-guard.sh` needle:"cheap-green" |
| On-the-loop | Human at blast expansion and HIGH merge, not between every piece | `.agents/skills/agentic-route/SKILL.md` needle:"on-the-loop" |
| Craft | Optional domain skills gated by `craft_skills` | `.agentic/config.yml` needle:"craft_skills" |

## System Architecture & Invariants

- Prose never authorizes a stage transition; `scripts/gate.sh` does. cite:scripts/gate.sh needle:"stage_"
- Pipe-to-interpreter and vendor `install.sh` are deny, not ask. cite:.cursor/hooks/guard.sh needle:"install.sh"
- File tools cannot write outside the worktree or to secret/key paths without HIGH+scope. cite:.cursor/hooks/protect.sh needle:"outside the worktree"
- `config.yml` is the only number store. Markdown twins will drift. cite:scripts/env-lint.sh needle:"context_md_max_lines"

## Risk Boundaries

- Enforcement layer: `.cursor/`, `scripts/`, templates, `config.yml`, GitHub workflow. cite:scripts/env-lint.sh needle:"enforcement"
- Host auth, payments, migrations (see `risk_paths`). cite:.agentic/config.yml needle:"risk_paths"
- Remote fetch is `guard.network` in config. New dependencies stay on the ticket (`new_deps`). cite:.agentic/config.yml needle:"new_deps"

## ADR Index

- [0001 — Enforcement vs convention](adr/0001-enforcement-vs-convention.md) — scripts authorize; skills on trigger; human on-the-loop. cite:.agentic/map.md needle:"Enforcement vs convention"
