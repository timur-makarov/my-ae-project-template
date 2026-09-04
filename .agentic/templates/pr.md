<!-- PR description template. /agentic-pr fills this from the ticket. -->

## Summary

<1–3 bullets: what changed and why, locked to the ticket's restatement>

**Ticket:** `.agentic/tickets/open/NN-slug.md` (moves to `closed/` on archive)

## Done Contract

- [ ] <assertion 1 — checked with evidence below>

## Changes / didn't touch / concerns

- **Changed:**
- **Didn't touch (intentionally):**
- **Concerns:**

## Verification

```
<command> → <exit code / summary line>
```

## Rollback

`<command or expand-contract step or n/a + why>`

## Risk

- **Weakest premise:** <claim + VERIFIED/INFERRED/ASSUMED label>
- **Untested paths:** <named, or "none">
- **Flip condition:** <the observation that would reverse this change>

## Rulings made autonomously

<!-- Every decision taken without a human, from the ticket ledger.
     `gate.sh pr` greps the ledger for `Ruling:` lines and requires each
     to appear here. If the ledger says `Rulings: none`, write that. -->

Rulings: none

## Critic

**Verdict:** <APPROVED — report: `.agentic/journal/NN-critic.md`> <!-- or "N/A (LOW risk fast lane)" -->
**Security fan-out:** <path or N/A>
