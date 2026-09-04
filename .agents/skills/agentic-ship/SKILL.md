---
name: agentic-ship
description: "Use when preparing a host-product deploy. Rollback field, watchlist, HIGH human merge. Canary numbers live in config if the host uses them."
---

# Agentic Ship

- Ticket `rollback:` is a command you have run in a dry sense, or expand-contract, not "n/a" on HIGH.
- Critic watchlist is the first thing `/agentic-postmortem` reads.
- Canary (if the host has one): advance if error rate within 10% and latency within 20% of baseline; roll back if error rate >2× or latency >50%.
- Feature flags default off; incomplete slices stay behind a flag.

## Verification

PR template Rollback + Didn't-touch filled. HIGH not merged by the agent.