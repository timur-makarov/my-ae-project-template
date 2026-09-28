---
name: agentic-route
description: "Use when starting a session or deciding which skill applies. Maps a spark onto this repo's spine. Domain skills load only when craft_skills is true in config.yml."
---

# Agentic Route: Which skill runs

This is the discovery tree. It does not replace `/agentic-task`. It tells you which hop comes first.

Prose here is vocabulary. `scripts/gate.sh` still authorizes every stage transition.

```
spark
 ├── kind unclear (question vs directive vs diagnosis)     → constitution, then this tree
 ├── vibe / "what if we…" / no Done Contract possible      → /agentic-idea  then /agentic-task
 ├── underspecified want (can't write Check: commands)     → /agentic-interview then /agentic-task
 ├── blast expands, two costly readings, architecture      → /agentic-grill
 ├── independently testable modules bundled                → Capability Map in the ticket, then N tickets
 ├── new work that should be tracked                       → /agentic-task
 ├── ticket open and unblocked                             → /agentic-implement
 │     ├── UI / css / tsx / vue                            → /agentic-ui + /agentic-browser
 │     ├── API / public types / OpenAPI                    → /agentic-api
 │     ├── auth / payment / untrusted input                → /agentic-security
 │     ├── new dependency or framework API                 → /agentic-source
 │     ├── tests failing / build red                       → /agentic-debug (stop the line)
 │     ├── HIGH non-trivial piece (cross-service, migrate) → in-flight doubt (critic hop), then continue
 │     └── performance ticket                              → /agentic-perf (measure; keep-or-revert)
 ├── ready-for-review                                      → /agentic-critic  (+ security fan-out on HIGH risk_paths)
 ├── critic APPROVED                                       → /agentic-pr
 ├── merged / accepted                                     → /agentic-archive
 ├── session dying mid-ticket                              → /agentic-handoff
 └── shipped work regressed                                → /agentic-postmortem
```

LOW fast lane: skip critic and domain packs unless a glob above matches. That lane is `scripts/gate.sh implement NN --trek`. The same agent writes the code.

If `craft_skills: false`, skip `/agentic-{ui,api,browser,security,perf,observe,migrate,spec,source,debug,simplify}` and keep the spine only.

## Rationalizations

| Excuse | Rebuttal |
|---|---|
| This is too small for a ticket | Then write a lite ticket. Untracked edits are how scope dies. |
| I'll spec after the prototype | Prototype is a ticket with residue named. Spec-after is a second ticket. |
| I'll load every domain skill | Context pollution. Load the one glob that matches. |
| Human must click between pieces | Human is on-the-loop: blast expansion + HIGH merge. Stamps gate the rest. |

## Verification

You routed correctly if the next command is one named skill or `scripts/gate.sh` stage, not a free-form implementation.