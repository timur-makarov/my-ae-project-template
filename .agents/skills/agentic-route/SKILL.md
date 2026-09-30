---
name: agentic-route
description: "Use when starting a session or deciding which skill applies. Maps a spark onto this repo's railroad. Domain skills load only when craft_skills is true in config.yml."
---

# Agentic Route: Which skill runs

For ticket work, the answer is always `scripts/gate.sh next [NN]`: it names the one legal move.
This tree covers what comes before a ticket exists and what `NEXT` hands to a skill.

```
spark
 ├── kind unclear (question vs directive vs diagnosis)     → AGENTS.md § How to work, then this tree
 ├── vibe / "what if we…" / no Done Contract possible      → /agentic-idea, then /agentic-task
 ├── underspecified want (can't write Check: commands)     → /agentic-interview, then /agentic-task
 ├── blast expands, two costly readings, architecture      → /agentic-grill
 ├── independently testable modules bundled                → Capability Map, then N tickets
 ├── new work that should be tracked                       → /agentic-task
 ├── a ticket exists                                       → scripts/gate.sh advance NN (/agentic-implement)
 │     ├── API / public types / OpenAPI                    → /agentic-api
 │     ├── auth / payment / untrusted input                → /agentic-security
 │     ├── tests failing / build red                       → /agentic-debug (stop the line)
 │     └── schema change / API removal                     → /agentic-migrate
 ├── NEXT: spawn the reviewer                              → /agentic-critic (the brief says how)
 ├── NEXT: write lessons                                   → /agentic-archive
 ├── NEXT: /agentic-pr                                     → /agentic-pr
 ├── session dying mid-ticket                              → /agentic-handoff
 ├── shipped work regressed                                → /agentic-postmortem
 └── explicit whole-codebase audit                         → /agentic-audit
```

If `craft_skills: false`, skip `/agentic-{api,security,migrate,debug}`.

## Rationalizations

| Excuse | Rebuttal |
|---|---|
| This is too small for a ticket | Then write a LOW ticket. It's claim → edit → ship. |
| I'll spec after the prototype | A prototype is a ticket with its residue named. |
| I'll load every domain skill | Context pollution. Load the one that matches. |
| I know the next step, no need to ask the gate | `next` is cheaper than being wrong about state. |

## Verification

You routed correctly if the next command is one named skill or `scripts/gate.sh`.
