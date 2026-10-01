# Domain Context

> Distilled long-term memory. Updated before ship (`/agentic-archive`), read by every planning
> and implementation pass. Hard cap: `limits.context_md_max_lines` in `config.yml`.
> Load-bearing rows need `cite:path needle:"token"` (glossary Cite column). ADR
> index markdown links are cites; needle optional there.

## Ubiquitous Language & Glossary

| Term | Meaning in this project | Cite |
|---|---|---|
| Railroad | `gate.sh next` names the one legal move; `advance` runs every script step | `scripts/gate.sh` needle:"compute_next()" |
| Claim | A `ticket/NN-slug` branch with the ticket in-progress and a frozen scope | `scripts/gate.sh` needle:"step_implement()" |
| Stamp | JSONL row from `verify.sh` (HEAD, dirty, exit). Gates read this, not the model. | `scripts/verify.sh` needle:"VERIFY" |
| Product file | Anything outside `.agentic/tickets/` and `.agentic/journal/`; only these make evidence stale | `scripts/lib.sh` needle:"NON_PRODUCT=" |
| Floor | Diff-scoped cheap-green detector (`scripts/floor-guard.sh`) | `scripts/floor-guard.sh` needle:"cheap-green" |
| On-the-loop | Human at blast expansion and HIGH merge, not between every step | `AGENTS.md` needle:"HIGH tickets are merged by a human" |
| Craft | Optional domain skills gated by `craft_skills` | `.agentic/config.yml` needle:"craft_skills" |

## System Architecture & Invariants

- Prose never moves a ticket; `scripts/gate.sh` does. cite:scripts/gate.sh needle:"step_ship()"
- Pipe-to-interpreter is deny, not ask. cite:scripts/hooks/guard.sh needle:"curl|sh"
- File tools cannot write outside the repo, to secrets, or to `.agentic/state/`. cite:scripts/hooks/protect.sh needle:"outside this repo"
- Claude Code and Codex run the same hooks through one adapter. cite:scripts/hooks/adapt.sh needle:"Translates"
- `config.yml` is the only number store. Markdown twins will drift. cite:scripts/env-lint.sh needle:"context_md_max_lines"

## Risk Boundaries

- Enforcement layer: hooks, tool configs, CI, `config.yml` are HIGH; `scripts/` is MEDIUM. cite:.agentic/config.yml needle:"scripts/hooks/**"
- Host auth, payments, migrations (see `risk_paths`). cite:.agentic/config.yml needle:"risk_paths"
- An unanswered ticket stays `blocked-on-answers` until Open questions is `none` and a human sets `status: open`. Product writes are denied until then. cite:scripts/gate.sh needle:"blocked-on-answers"
- Remote fetch is `guard.network` in config. New dependencies stay on the ticket (`new_deps`). cite:.agentic/config.yml needle:"new_deps"

## ADR Index

- [0001 — Enforcement vs convention](adr/0001-enforcement-vs-convention.md) — scripts own state; hooks guard the irreversible few; judgment stays prose.
