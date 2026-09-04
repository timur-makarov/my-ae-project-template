---
name: agentic-spec
description: "Use for a new host-product capability (not a one-file fix). Living spec before code: objective, commands, structure, test strategy, Always/Ask/Never."
---

# Agentic Spec

If the ask bundles independently testable capabilities, stop and write a Capability Map (`Module ID`, `Responsibility`, `Depends on`, no cycles). Each module is its own ticket.

Otherwise one spec in the ticket (full template already is a mini-spec):

- Objective and stories
- Exact verify commands (or point at `config.yml verify:`)
- Always / Ask first / Never
- Success criteria as testable numbers, not "fast"

Then `/agentic-task`. Do not implement from the spec hop.

## Verification

Capability map acyclic, or a single full ticket with Out of scope.