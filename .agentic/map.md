# Project Map & Decision Index

> **Destination:** A copy-pasteable project environment where agentic engineering is gated by scripts, not prose.
> **Tracker:** see `.agentic/config.yml`

---

## 1. Standing Notes & Context

- **Spine:** `/agentic-route`, `/agentic-init`, `/agentic-task`, `/agentic-grill`, `/agentic-implement`, `/agentic-critic`, `/agentic-pr`, `/agentic-archive`, `/agentic-status`, `/agentic-handoff`, `/agentic-postmortem`. `/agentic-audit` is off the spine (explicit request only).
- **Intake:** `/agentic-idea`, `/agentic-interview`.
- **Craft (when `craft_skills: true`):** `/agentic-debug`, `/agentic-api`, `/agentic-security`, `/agentic-migrate`.
- **Domain context:** `.agentic/context/CONTEXT.md`.
- **Core invariant:** every ticket satisfies its Done Contract and the standing DoD, passes `scripts/verify.sh` with a fresh stamp, floor-guard, and — for MEDIUM/HIGH — a same-agent critic whose claim commands are in the action journal (plus a security report on HIGH `risk_paths`) before closing. A system audit is not a merge check. Stage transitions go through `scripts/gate.sh`.

---

## 2. Decisions So Far

- **ADR 0001 — Enforcement vs convention:** scripts authorize; skills advise; LOW fast lane is sacred; human on-the-loop = blast expansion + HIGH merge. See `.agentic/context/adr/0001-enforcement-vs-convention.md`.

---

## 3. Active Frontier (Unblocked Tickets)

<!-- Host projects fill this. The template ships empty. -->

---

## 4. Fog of War / Blocked on Alignment

<!-- Tickets whose blast radius expands scope, awaiting /agentic-grill resolution. -->

---

## 5. Out of Scope

- Live forge branch-protection settings (workflow ships; humans click the GitHub UI).
- PID registry for long-running dev servers (kill/pkill is ask-gated only).
- Harness-owned OS sandbox / cloud IAM (document in CONTEXT; cannot enforce from bash).
