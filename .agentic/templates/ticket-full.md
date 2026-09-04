---
status: open
type: directive
risk_tier: MEDIUM
template: full
blocked_by: none
branch: —
claimed_by: ""
network: ask          # none | ask | allow  (shell egress; curl|sh is always deny)
reversibility: reversible   # reversible | expand-contract | irreversible
rollback: n/a
new_deps: []
scope_paths:
  - <glob, e.g. src/foo/**>
---

# Ticket NN — <Title>

## Restate Contract

- **Outcome:**
- **User:**
- **Why now:**
- **Success:**
- **Constraint:**
- **Out of scope:**

## Request

- **Verbatim:** "<the user's exact words>"
- **Restatement:** <outcome wanted, for whom, urgency, quality bar — beyond the literal words>
- **Cause:** <what event produced this request right now>
- **Problem vs. proposed mechanism:** <if the request names a mechanism, does it actually solve the underlying problem? Name any mismatch in one sentence>

## Done Contract

1. <testable assertion> — Check: `<runnable command>`
2. <testable assertion> — Check: `<runnable command>`

## Definition of Done

Standing bar (see `.agentic/references/dod.md`). Unchecked boxes fail `gate.sh archive`.

- [ ] Correctness: acceptance checks ran; tests failed without the change and pass with it
- [ ] Quality: scoped, no unrelated refactors, lint/types clean
- [ ] Integration: migrations / flags / compat accounted for (or N/A)
- [ ] Rollback: `rollback:` above is a real command, expand-contract plan, or n/a with reason

## Constraints & Residue

- [ ] **C1:** <constraint, verbatim where possible>
- [ ] **C2:** <implied constraint>

**Residue (deliberately not covered):**
- <named uncovered area — a decision, not an accident>

## Blast Radius

**NARROWING | EXPANDING** — <rationale. EXPANDING → status blocked-on-alignment + /agentic-grill>
<!-- reversibility: irreversible without a compensating rollback: also EXPANDING. -->

## Risk

- **Pricing:** P=<low|med|high> × C=<low|med|high> × detection-lag=<immediate|delayed> → tier confirmed above
- **Loss asymmetry:** cheap-wrong = <direction>; expensive-wrong = <direction>. Verification budget goes to expensive-wrong.
- **Pre-mortem:** "It's next week and this failed because <most likely disaster>." That risk gets checked first.
- **Session traps:** <live credentials, prod tunnels, wrong-target commands present in this environment — or "none">

## Load-Bearing Assumptions

<!-- Only claims the outcome depends on. Verify ASSUMED entries before writing code.
     Upgrade every ASSUMED row before gate.sh pr. -->

| # | Claim | Status (VERIFIED / INFERRED / ASSUMED) | Evidence pointer | Flip condition & check cost |
|---|---|---|---|---|
| A1 | | | | |

## Execution Pieces

<!-- Each piece = an independently checkable claim with a binary verdict.
     Vertical slices (one user-visible path), not horizontal layers.
     S ≤2 files, M ≤5; split anything larger or with "and" in the title.
     Last piece is always goal-backward verification. -->

### Piece 0 — <shared assumption, if any>
- **Claim:** <verdict-bearing assertion> — **Check:** `<command>` — **Status:** [ ]

### Piece 1 — <kill-shot / cheapest disambiguator>
- **Claim:** — **Check:** `<command>` — **Status:** [ ]

### Piece N — Goal-backward verification
- **Claim:** the originally requested scenario works end-to-end; constraints C1..CN hold against the final artifact
- **Check:** `<end-to-end reproduction command>` — **Status:** [ ]

## Capability Map

<!-- Required when scope_paths has more than limits.max_scope_globs entries,
     or when the work is independently testable modules. Else write "n/a". -->

n/a

## Resolution

<!-- Sentence 1 answering the request. Proof sketch with pointers.
     Must include weakest-premise label, named flip condition, and
     `Rulings: none` or the list of ledger Ruling: lines. No unhedged
     should/probably/likely. -->

### Risk & Flip Conditions
- **Weakest premise:** <claim + label>
- **Untested paths:** <named>
- **Flip condition:** <the observation that would reverse this>
- **Rulings:** none

### Critic Sign-off
- [ ] Isolated critic ran on evidence only (diff + test output + Done Contract, zero narrative) — report: `.agentic/journal/NN-critic.md`
- [ ] Verdict `APPROVED` with epicycle count ≤ 1
- [ ] HIGH + auth/payment/migrations/`.cursor`: security fan-out report `.agentic/journal/NN-critic-security.md`
