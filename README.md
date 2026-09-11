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

A script or hook can **deny**, **ask**, or **exit non-zero**. Skills and the constitution do not. Hooks fire in Cursor agent turns; a host-terminal `git` bypasses them. CI is the wall on PRs to `dev`/`main`/`master`.

### Shell — `guard.sh` (failClosed)

| Move | Stop |
|---|---|
| `curl\|sh`, `wget\|bash`, `bash <(curl)`, `eval "$(curl …)"`, `curl -o install.sh`, `./install.sh` outside `scripts/`, `base64\|sh` | deny |
| Cloud metadata (`169.254.169.254`, GCP, `fd00:ec2::254`) | deny |
| curl/wget/nc/ssh **and** interpreter HTTP (`python`/`node` urllib\|fetch) | ticket/config `network:` (default ask; localhost allow) |
| Package install not listed in ticket `new_deps:` | ask / deny (`guard.new_deps`) |
| `--privileged`, `--network=host`, `chmod 777`, mkfs, `dd of=/dev/` | deny |
| sudo/su, crontab/launchctl, redirect into `.env`/keys, `~/.ssh` | ask |
| Force-push or `git commit` on `main`/`master`/`dev`/`base_branch` | deny |
| HIGH merge into `base_branch` | deny (`risk.high_requires_human_merge`) |
| `git commit -m` without ticket `NN` | deny; no inspectable `-m` (HEREDOC/`-F`) → ask |
| Mutate `tickets/closed/` without `gate.sh archive` token; rewrite journal | deny |
| Redirect onto `scope-*.txt`, or outside frozen `scope_paths` | deny |
| rebase, `--amend`, `reset --hard`, `rm -rf` (non-scratch), `git clean -f` | ask |
| Shell write to `config.yml` / `CONTEXT.md` / `lessons.md` / `.cursor/` | ask |
| `kill` / `pkill` | ask |

### File tools + fetch — `protect.sh`, `mcp-guard.sh` (failClosed)

| Move | Stop |
|---|---|
| Write outside the worktree (TMPDIR allowed) | deny |
| **Read** or write `.env` / `*.pem` / keys (`.env.example` allowed) | deny unless HIGH **and** in frozen scope |
| `.cursor/**`, `scripts/**`, templates, `config.yml`, `enforcement.sha256`, workflows | deny unless HIGH **and** in scope |
| File-tool rewrite of `scope-*.txt` | deny (`gate.sh implement` owns it) |
| `tickets/closed/`, journal JSONL | deny |
| Writes outside frozen `scope_paths` (active ticket) | deny |
| No ticket and `scope.strict: true` | deny all file-tool edits (template ships **false**; `/agentic-init` flips it) |
| WebFetch / WebSearch / MCP | same `network:` budget as curl |

`audit.sh` appends every shell command to `actions-*.jsonl` (fails open if jq is missing). EditNotebook is on the write matcher.

### Stages — `gate.sh` + linters

| Move | Stop |
|---|---|
| Ticket YAML, blast NARROWING/EXPANDING, EXPANDING ⇒ grill, nonempty `scope_paths` | `ticket-lint.sh` |
| `Check:` must be a runnable command (`true`/`pass`/`ok` as English fail; `` `true` `` is the shell) | `ticket-lint.sh` |
| Lone `*` / `**` glob unless `type: wide-refactor` **and** HIGH | `ticket-lint.sh` |
| Irreversible without `rollback:`; title containing ` and `; too many globs without Capability Map; `blocked_by` cycles | `ticket-lint.sh` |
| Unknown `models.*` slug | `model-check.sh` (hard fail; no silent inherit) |
| `DATABASE_URL` / `REDIS_URL` / `AMQP_URL` (or URL-shaped `*_API_KEY`) not localhost | `gate.sh implement` |
| Claim lock (another session holds `in-progress`) | `gate.sh implement` |
| No baseline verify stamp; later critic/pr without a fresh green stamp for this HEAD | `stamp-check.sh` |
| Optional: implement from a linked worktree | `limits.require_worktree` (shipped false) |
| MEDIUM/HIGH critic: ledger, evidence-only payload, last verdict `APPROVED` | `gate.sh critic` / `pr` + `artifact-lint.sh` |
| MEDIUM/HIGH `directive`/`diagnosis`: nonempty `actions-*.jsonl`; each hostile **Command run** must appear in it | `evidence-check.sh` (`limits.tdd_required`) |
| Quoted `scripts/`/`pytest`/… in reports must appear in the journal; RED before GREEN (skipped while `verify.test` is `selftest.sh`) | `evidence-check.sh` |
| HIGH diff hitting a HIGH `risk_paths` glob | `NN-critic-security.md` APPROVED (`critic.fanout`) |
| Diff floor above ticket tier; test-count drop without a Ruling; leftover ASSUMED rows | `gate.sh pr` |
| Destructive DDL without a down-file / `expand-contract`; migrations require HIGH | `gate.sh pr` |
| Lockfile changed: `new_deps:` nonempty **and** lists every added package name | `gate.sh pr` |
| Resolution: weakest premise, flip, no unhedged should/probably/likely; PR body surfaces `Ruling:` lines | `artifact-lint.sh` |
| Ledger piece-complete needs commit range + brief + report + review package; fix-round cap; `Rulings: none` or listed | `artifact-lint.sh` |
| `@ts-ignore` / eslint-disable / noqa, empty `catch`, `.skip`/`xit`, deleted assertions, lowered config numbers | `floor-guard.sh` |
| `PONYTAIL(id):` must resolve to a ticket or ADR | `debt-lint.sh` |
| Hook/script hash drift; `failClosed: false`; CONTEXT.md over cap; stale memory cites/needles/TTL; CI `--protected-diff` without HIGH | `env-lint.sh` |
| MEDIUM/HIGH missing `## Definition of Done`; archive without lessons line or `Lessons: none` | `gate.sh archive` |
| Diff insertions over `limits.diff_fail_lines` (shipped 0 = off; warn at 300) | `gate.sh pr` |

### Observe-only (not a deny)

| Condition | What happens |
|---|---|
| Active ticket, no fresh green stamp | `stop` hook warns (`loop_limit: 0`, no follow-up loop) |
| `scope.strict: false` and `verify.test` still `selftest.sh` | sessionStart: run `/agentic-init` |
| `models.critic == models.implementer` and `models_allowed` lists another family | `model-check.sh` WARNING (`inherit` never fails) |

### CI

On PRs to `dev`/`main`/`master`: env-lint `--protected-diff`, ticket-lint, floor-guard, verify, debt-lint, model-check. `gate.sh pr NN` **only** if the branch is `ticket/NN-slug`. Other branches skip the ticket gate.

Residual escapes stay possible: command indirection, kind misclassification, non-Cursor git. CI + HIGH human merge are load-bearing.

## Bring-up

1. Copy this tree. `chmod +x scripts/*.sh .cursor/hooks/*.sh`
2. `/agentic-init` — real `verify:` commands, `scope.strict: true`, Destination in `map.md`
3. `scripts/env-lint.sh --write-manifest` after any enforcement-file change
4. Work only through the spine above

Tunables: `.agentic/config.yml`. Do not fork skills to change numbers. Loosening a number is a floor-guard failure unless a HIGH ticket + `Ruling:` says so.
