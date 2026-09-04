---
name: agentic-grill
description: "Use when a ticket is blocked-on-alignment, a blast radius expands scope, or an architectural decision has divergent paths a human must settle."
---

# Agentic Grill: Decision-Tree Interview

Resolve architectural fog and blast-radius expansions through structured rounds of questions, before any code is committed.

## Core rules

1. **Map the design tree.** High-level decisions branch into secondary ones; resolve parents first. The frontier of each round = questions whose prerequisites are settled.
2. **Sort unknowns strictly.** *Unknown to you* (answer lives in code, config, logs, git history, docs) → inspect it yourself or dispatch a research subagent; never spend the human's attention on lookups. *Unknowable from here* (intent, risk tolerance, domain preference) → ask.
3. **One decisive question over a menu of clarifiers.** If two interpretations survive, ask the one that splits them.
4. **Every question carries a recommendation.** Options A/B/C, your recommended choice grounded in codebase evidence, and the flip condition that would reverse it. A remote party should be able to answer every round with "go with your recommendations."
5. **No sycophancy.** The human's initial guess is one hypothesis; probe rival causes and downstream consequences before endorsing it.
6. **Mode commitment.** A mode the human chose (ask vs agent, merge vs PR vs keep, grill vs implement) binds the rest of the session — do not silently drift to a more convenient mode.

## Question format

```markdown
### Round N — <topic>

**Q1 — <decision>:** <question with tradeoffs and blast radius>
- **A:** <option>  **B:** <option>
→ **Recommended:** A — <one-line rationale>. Flips if <condition>.
```

## Resolution

When the human answers:
1. Recompute the frontier; present Round N+1 if new questions unlocked.
2. When all branches settle:
   - Record decisions in `.agentic/map.md` §2 Decisions So Far.
   - If an architectural seam was established, write an ADR to `.agentic/context/adr/` from `.agentic/templates/adr.md` and index it in `CONTEXT.md`.
   - Update the blocked ticket: blast radius re-classified, Status back to `open`, move from map §4 to §3.
3. Report: decisions made, ADRs written, tickets unblocked, next action (`/agentic-implement <NN>`).
