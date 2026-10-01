# ADR 0001: Enforcement vs convention

> **Status:** `accepted`
> **Date:** 2026-09-30

## 1. Context

Agents skip prose steps under pressure, and a skill the agent can rationalize around is a
suggestion. Enforcing everything mechanically is also wrong: it makes the harness slower than
the work, pushes agents toward workarounds, and can't judge quality anyway.

## 2. Decision

Split every rule into one of three layers:

1. **Scripts own state.** Only `scripts/gate.sh` moves a ticket: new, claim, check, review,
   ship. `gate.sh next` is one table that names the single legal next move. Evidence (verify
   stamps and check results) lives in `.agentic/state/`, is written only by scripts, and
   stays valid while no product file changes.
2. **Hooks guard the few irreversible or evidence-forging actions** (see `AGENTS.md`), in every
   tool: Cursor natively, and Claude Code and Codex through `scripts/hooks/adapt.sh`. Everything
   else is allowed. Tool-native sandboxes and prompts handle the "ask" class where they exist.
3. **Judgment stays prose.** Test quality, approach, and whether a change holds belong to
   the reviewer (a separate agent seat on MEDIUM/HIGH). The reviewer returns findings on the
   changed lines. The author fixes a finding an ordinary caller hits and declines the rest.

CI re-derives the script layer from the pushed branch (`gate.sh pr NN --require-shipped`).

## 3. Consequences

- The LOW fast lane is claim → edit → ship, with no reviewer and no stamp.
- A human is on the loop, not in it: unanswered tickets (`blocked-on-answers`), blast-radius expansion (`blocked-on-alignment`), and HIGH merges.
- Hook pattern-matching is a speed bump, not a sandbox: a determined agent can write state
  through an interpreter. CI re-runs the ship checks.
- Mechanical test-first proof is deliberately absent; the reviewer judges whether tests would fail
  without the change.
