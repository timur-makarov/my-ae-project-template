# Project Environment Template for Agentic Engineering

A copy-pasteable project scaffold that treats **language-model labor as untrusted until a script says otherwise**.

Prose (constitution, skills, tickets) tells the agent what good work looks like. Code (hooks, `scripts/gate.sh`, floor-guard, CI) is the only thing that can stop a stage transition.

## Workflow

One spine. Domain skills load on trigger (`craft_skills` in `.agentic/config.yml`), not all at once.

```
spark
  → /agentic-idea          if it's a vibe (Not Doing list)
  → /agentic-interview     if you cannot write Check: commands yet
  → /agentic-grill         if blast radius expands or two costly readings survive
  → /agentic-task          atomic ticket: Done Contract, out of scope, reversibility, scope freeze
  → /agentic-implement     TDD pieces, commits named NN, verify stamp
  → /agentic-critic        evidence-only; HIGH risk_paths also spawn a security persona
  → /agentic-pr            human merge for HIGH
  → /agentic-archive       close token, lessons, CONTEXT
```

`/agentic-route` is the map. `/agentic-status` anytime. `/agentic-handoff` mid-ticket. `/agentic-postmortem` when shipped work breaks.

LOW tickets skip the critic. Humans sit **on** the loop (expansion, HIGH merge, irreversible work), not between every slice. Every autonomous stretch still ends on a verify **stamp**.

If a change is not reversible, the ticket says `reversibility: irreversible` with a compensating `rollback:` — and that is EXPANDING, so it grills first.

## Guardrails (enforced)

| Move | What stops it |
|---|---|
| `curl \| sh`, `bash <(curl)`, `eval "$(curl …)"`, `./install.sh` | `guard.sh` deny |
| Remote fetch | `network: ask\|none` on the ticket / config |
| New packages | `new_deps:` list or ask |
| Write outside the repo, `.env`, keys | `protect.sh` deny |
| `@ts-ignore`, `.skip`, deleted assertions, empty `catch`, lowered config numbers | `scripts/floor-guard.sh` |
| File-tool edits outside frozen `scope_paths` | `protect.sh` |
| Stage skip (implement / critic / pr / archive) | `scripts/gate.sh` + stamp |
| `failClosed: false` | `env-lint.sh` |

Residual escapes (command indirection, kind misclassification) stay possible. CI + HIGH human review are load-bearing.

## Bring-up

1. Copy this tree. `chmod +x scripts/*.sh .cursor/hooks/*.sh`
2. `/agentic-init` — real `verify:` commands, `scope.strict: true`, Destination in `map.md`
3. `scripts/env-lint.sh --write-manifest` after any enforcement-file change
4. Work only through the spine above

Tunables: `.agentic/config.yml`. Do not fork skills to change numbers. Loosening a number is a floor-guard failure unless a HIGH ticket + `Ruling:` says so.
