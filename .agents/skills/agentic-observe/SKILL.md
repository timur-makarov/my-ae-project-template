---
name: agentic-observe
description: "Use when adding logs, metrics, traces, or alerts. On-call questions first. RED for endpoints, no PII in metric labels."
---

# Agentic Observe

1. Write 2–4 on-call questions this telemetry must answer. If you can't, don't add a log line.
2. Structured logs, stable event names, request/correlation id. Allowlist fields.
3. RED (rate, errors, duration) for user-facing endpoints. Percentiles, not averages.
4. Alert on symptoms users feel. Every alert links a 3-line runbook.

## Verification

The questions are in the ticket or the log event comment. No raw bodies or secrets.