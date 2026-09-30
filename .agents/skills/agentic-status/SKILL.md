---
name: agentic-status
description: "Use when someone asks where the project stands — open tickets, blockers, frontier, recent decisions — or at the start of a session to orient."
---

# Agentic Status

Read-only; changes nothing.

## 1. Read

- `scripts/gate.sh next --all`: in flight (claimed branches), open (with blockers), recently closed.
- `scripts/gate.sh next NN` for each in-flight ticket: its one next move.
- `scripts/ticket-lint.sh`, `scripts/env-lint.sh`, `scripts/debt-lint.sh` (PONYTAIL list): health.
- `.agentic/state/metrics.jsonl`: the last few gate steps and their exits (local to this worktree).
- `.agentic/map.md` destination; `.agentic/journal/NN-handoff.md` if any.
- Tracker `github-issues`: `gh issue list`, and flag drift from local tickets (local wins).

## 2. Render

```markdown
# Status — <destination>

## In flight
| ID | Branch | NEXT |

## Ready (open, unblocked)
| ID | Title | Tier |

## Blocked
| ID | Title | On (alignment / ticket NN) |

## Recently closed
- NN — title

## Health
- ticket-lint / env-lint / debt: <OK | details>
```
