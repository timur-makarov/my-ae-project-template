# ADR 0002: The human reads the PR

> **Status:** `accepted`
> **Date:** 2026-10-05

## 1. Context

A human has to see what shipped without a second board. The files disagree about
where that lives. `.agentic/map.md` is Destination, Standing Notes, and Out of Scope.
Grill tells the agent to write §2 and to move tickets from §4 to §3. Ticket-lite
says to list an EXPANDING blast under §4. Those headings are not in the file.
`ticket-lint.sh` still accepts a Check of `` `true` `` and tells the agent to use it.
A digest flag, a Resolution sentence on `next --all`, seam lint, `verify.e2e`
wiring, and a caller-entry test rule were all proposed.

## 2. Decision

Accepted 2026-10-05:

1. The human reads the PR. `.agentic/templates/pr.md` Summary stays "1–3 bullets: what
   changed and why." No digest flag. `scripts/gate.sh next --all` does not grow a
   Resolution sentence.
2. Ticket `## Resolution` stays for `Ruling:` lines and postmortem. It is not a
   second human digest.
3. `.agentic/map.md` is orientation. It is not a ticket board and not a decision
   log. Do not add §2–§4. Decisions that cross modules are ADRs. Ticket state stays
   on the ticket. Grill no longer says to write `map.md` §2, and ticket-lite no
   longer says "list under map.md §4". `scripts/selftest.sh` fails if a skill or
   template names a `map.md` section the file lacks.
4. No seam lint in this pass. No `verify.e2e` wiring. No critic sentence about
   caller-level tests.
5. The caller-entry / e2e-versus-unit rule is deferred. It does not go in
   `.agentic/references/judgment.md` until that rule is chosen.
6. The same pass makes `scripts/ticket-lint.sh` reject a Check whose command is
   exactly `true` or `:` (including backtick-wrapped). The hint to use shell
   `` `true` `` is removed. A larger command that merely contains those words
   stays legal.

## 3. Consequences

- This pass touches the grill skill, the ticket-lite template, `scripts/selftest.sh`,
  and `scripts/ticket-lint.sh`. `scripts/**` floors MEDIUM. `.agentic/config.yml`
  is not in scope.
- A Check of `` `true` `` can no longer ship.
- Agents that named phantom map sections fail `scripts/selftest.sh` until the
  wording is gone.
