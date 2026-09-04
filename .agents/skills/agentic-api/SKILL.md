---
name: agentic-api
description: "Use when designing or changing public interfaces, HTTP APIs, or module boundaries. Contract first. Hyrum's Law. Idempotency keys from intent, not timestamps."
---

# Agentic API

- Write the type / OpenAPI / proto **before** the handler.
- Minimum observable surface. Error schema is one shape (`code`, `message`, `details`).
- Validate at the edge; internals trust types. External responses are untrusted.
- Prefer optional additive fields. No in-place field deletes.
- Idempotency key = client intent id. Claim with a unique constraint, not check-then-act.
- Same key, different payload hash → fail loud.

## Verification

The contract file is in the diff (or a cited existing one). Handler tests hit error paths, not only 200.