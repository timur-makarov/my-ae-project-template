---
name: agentic-archive
description: "Use when gate.sh next asks for lessons before a MEDIUM/HIGH ship, or when a ticket's work should be distilled into long-term memory."
---

# Agentic Archive: Distill Memory Before Ship

Closing is mechanical: `scripts/gate.sh ship NN` (via `advance`) moves the ticket to
`tickets/closed/` on its branch and commits `NN: close`. This skill is the part a script can't do:
deciding what the project learned. It runs before ship, so the memory lands in the same PR.

## 1. Lessons: `.agentic/journal/lessons/NN.md`

Start from `.agentic/templates/lessons.md`. One line per real defect the reviewer, CI, or you
found along the way:

```
- [NN] YYYY-MM-DD <defect> — <check that catches it> — cite:path needle:"token"
```

Prefer an enforcing cite (`scripts/`, a `*test*` file, or a `verify.*` command). Lessons older than
`limits.lesson_ttl_days` without one fail `scripts/memory-lint.sh`: promote them to a check or retire
them with `- DROPPED YYYY-MM-DD <defect>`. Nothing learned → `Lessons: none` (the file must exist).
A green LOW ship writes no lesson.

A lesson's check lands in one place. A command that should always hold goes into `verify` or a
guard. A path this app keeps treating as ordinary, and that was a real boundary, goes into this
project's `risk_paths` via its own ticket. Promotion only adds a floor or a check. Loosening the
map is a HIGH ticket. A shape true in every copy is a ticket on the template repo, not an edit
from a product diff.

## 2. Context: `.agentic/context/CONTEXT.md`

New terms go in the glossary; new invariants or risk boundaries go in their sections. Each
load-bearing row needs `cite:path needle:"token"`. Over `limits.context_md_max_lines`, **compact**
(merge, drop stale) rather than append.

## 3. Decisions

A decision that affects multiple modules or external systems gets an ADR in `.agentic/context/adr/`
(from `.agentic/templates/adr.md`), indexed in CONTEXT.md.

## 4. Then

`scripts/gate.sh advance NN`. `memory-lint` runs inside ship.
Tracker `github-issues`: after merge, `gh issue close <issue> --comment "Closed: <gist>. PR: <url>"`.
