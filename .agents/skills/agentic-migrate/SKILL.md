---
name: agentic-migrate
description: "Use when changing schemas or removing APIs. Expand/contract. In-place rename/drop fails the migration gate unless reversibility is expand-contract."
---

# Agentic Migrate

Never rename or drop a column in place.

1. Expand: add the new column nullable. Deploy.
2. Dual-write. Deploy.
3. Backfill in throttled batches.
4. Switch reads. Bake.
5. Contract: stop writing the old column; drop later.

`reversibility: expand-contract` on the ticket. Down-file required for DROP/TRUNCATE/ALTER TYPE.

## Verification

`gate.sh pr` migration_gate green. Rollback is the down migration or the previous expand step.