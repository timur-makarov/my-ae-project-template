---
name: agentic-status
description: "Use when someone asks where the project stands — open tickets, blockers, frontier, recent decisions — or at the start of a session to orient."
---

# Agentic Status: Map & Frontier Overview

Snapshot the project state. Read-only; changes nothing.

## 1. Read

- `.agentic/map.md`; all of `tickets/open/`; the 3 most recent files in `tickets/closed/`.
- `scripts/ticket-lint.sh` — surface violations as a health warning.
- `scripts/env-lint.sh` — enforcement drift is a health warning.
- `scripts/floor-guard.sh` — cheap-green moves on the current diff.
- `.agentic/journal/metrics.jsonl` — last-N stage events (fix-round / verdict / gate-failure patterns).
- `scripts/debt-lint.sh` — harvested `PONYTAIL(id):` list; render under Health.
- If a `journal/<NN>-handoff.md` exists and is older than the ledger, flag it stale.
- If `tracker: github-issues` in config: `gh issue list` and flag drift between issues and local tickets (local markdown is the source of truth).

## 2. Categorize open tickets

- **Active Frontier** — status `open`, no unresolved blockers → ready for `/agentic-implement`.
- **Blocked on alignment** — `blocked-on-alignment` → needs `/agentic-grill`.
- **Blocked on dependencies** — `Blocked by:` names an unfinished ticket.
- **In progress** — `in-progress`; check `journal/<NN>-ledger.md` for the last completed piece, and mention `journal/<NN>-handoff.md` if one exists.
- **Ready for critic / review** — awaiting `/agentic-pr` or `/agentic-archive`.

## 3. Render

```markdown
# Status — <Destination from map.md>

## Ready to implement
| ID | Title | Type | Risk | Action |
|---|---|---|---|---|

## Blocked (alignment / dependencies)
| ID | Title | Blocked by | Action |
|---|---|---|---|

## In flight
| ID | Title | Status | Last ledger entry |
|---|---|---|---|

## Recent decisions (last 3 closed)
- [NN — title](path) — gist

## Health
- ticket-lint: <OK | violations>
- env-lint: <OK | drift>
- debt (PONYTAIL): <none | list>
- metrics (last 5): <stage/nn/exit>
- tracker drift: <none | details>          (github-issues only)
```
