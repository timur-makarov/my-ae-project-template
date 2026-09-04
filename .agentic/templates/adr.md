# ADR [NNNN]: <Title of Architectural Decision>

> **Status:** `proposed` | `accepted` | `superseded` | `deprecated`  
> **Date:** <YYYY-MM-DD>  
> **Ticket / Effort:** <Link to ticket or effort>

---

## 1. Context & Problem Statement

<Describe the context, the forces at play, and the specific decision to be made in 1-2 paragraphs.>

---

## 2. Decision Drivers

- **D1:** <Driver 1, e.g. performance, complexity constraint, backward compatibility>
- **D2:** <Driver 2>
- **D3:** <Driver 3>

---

## 3. Considered Options

1. **Option A:** <Title / Summary>
2. **Option B:** <Title / Summary>
3. **Option C:** <Title / Summary>

---

## 4. Decision Outcome & Rationale

**Chosen Option:** <Option X>

**Rationale:**
<Direct explanation of why Option X was chosen over the others, referencing decision drivers.>

### Epistemic Validation
- **Verified Invariants:** <What was verified against benchmarks/code>
- **Inferred Outcomes:** <What logically follows>
- **Assumed Properties:** <Assumptions made about future load/evolution>

---

## 5. Consequences & Ponytail Upgrades

### Positive Consequences
- <Advantage 1>
- <Advantage 2>

### Negative Consequences / Tradeoffs
- <Tradeoff 1>
- <Tradeoff 2>

### Ponytail Simplifications & Upgrade Path
- *Deliberate Simplification:* <e.g., In-memory cache with simple TTL>
- *Known Ceiling:* <e.g., Will exhaust memory beyond 50,000 active sessions>
- *Upgrade Path:* <e.g., Replace with Redis cluster when session count crosses 20,000>
