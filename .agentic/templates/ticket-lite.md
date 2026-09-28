---
status: open
type: directive
risk_tier: LOW
template: lite
blocked_by: none
branch: —
claimed_by: ""
reversibility: reversible
rollback: n/a
new_deps: []
scope_paths:
  - <glob>
---

# Ticket NN — <Title>

## Request

- **Verbatim:** "<the user's exact words>"
- **Restatement:** <2–3 sentences: the actual outcome wanted, for whom, at what quality bar — must contain things the original didn't say but clearly meant>
- **Cause:** <what event plausibly produced this request right now — one line>
- **Out of scope:** <one line; required>

## Done Contract

1. <testable assertion that defines done> — Check: `<runnable command>`

## Constraints

- <verbatim or implied constraint — backward compatibility, no restart, style, etc.>

## Blast Radius

**NARROWING** — <one-line rationale>
<!-- EXPANDING (touches more systems, deletes data, breaks public API, spends money,
     publishes anything) → set Status to blocked-on-alignment, list under map.md §4,
     and run /agentic-grill before any implementation.
     irreversibility without rollback is EXPANDING. -->

## Resolution

<!-- Filled at completion:
     Sentence 1 answering the request in its own terms.
     Proof sketch: file:line pointers, test command + output, exit codes.
     Risk: weakest premise + label, untested paths by name, flip condition.
     Rulings: none -->
