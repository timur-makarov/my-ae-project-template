---
name: agentic-security
description: "Use when the diff touches auth, payments, untrusted input, secrets, or SSRF-shaped fetches. Also the HIGH critic fan-out persona."
---

# Agentic Security

Spawned as an isolated subagent on HIGH diffs that hit `risk_paths`. Evidence-only. Write `.agentic/journal/<NN>-critic-security.md` using the critic template.

Check:

- Untrusted input at the boundary (injection, path, SSRF). Server-side URL fetch: https, allowlisted hosts, no link-local/metadata IPs, no open redirects.
- AuthZ in code, not in the prompt. Secrets not logged, not committed, not interpolated into shells.
- LLM output is untrusted: no `eval`, raw SQL, `innerHTML`, or pipe-to-shell of model text.
- Destructive/irreversible actions need a human (already HIGH merge).
- Supply chain: no `curl | sh`, no unexpected `postinstall`. `new_deps` must match the lockfile diff.

Numeric "secure" claims without a command are `not measured`.

## Verification

Report has a Verdict line and executed hostile rows. `gate.sh pr` requires APPROVED when fan-out triggers.