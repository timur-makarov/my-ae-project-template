---
name: agentic-perf
description: "Use on performance tickets. Measure first. Keep only if the gain beats noise; otherwise revert. Numeric claims without measurement fail critic lint."
---

# Agentic Perf

1. Baseline command + output (Lighthouse, `EXPLAIN ANALYZE`, load test).
2. Change one thing.
3. Re-measure under the same conditions.
4. If within noise or worse: revert. Neutral complexity is a failure.
5. Guard with a budget if the host has one.

Rival-cause hunt is required (critic Attack 2 is not N/A).

## Verification

Before and after numbers pasted. Artifact-lint metric-honesty: `measured` or `not measured`.