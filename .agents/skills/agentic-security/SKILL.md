---
name: agentic-security
description: "Use when the diff touches auth, payments, untrusted input, secrets, or SSRF-shaped fetches. Also the HIGH critic fan-out persona."
---

# Agentic Security

On a HIGH diff that hits a HIGH `risk_paths` glob (and `critic.fanout: true`), the gate writes
`.agentic/state/payload-<NN>/BRIEF-security.md` only after the critic findings are judged.
A separate reviewer (persona `.agents/personas/security-auditor.md`) writes
`.agentic/journal/<NN>-critic-security.md`. Do not start this seat in the same turn as the critic.

The report is a findings list, same shape as the critic report. The author judges it in
`.agentic/journal/NN-critic-security-response.md` (`F1: fixed` or `F1: declined`) before ship.

Review only the changed lines and the logic those lines implement. Anything else is forbidden:
unchanged files, unchanged lines, imagined inputs, encodings, cousin cases, a verdict, and
claim commands.

A finding names the lower-trust principal, the boundary that was crossed, and the observed
result on a changed line. A missing header, a missing rate limit, or a second copy of a
`guard.sh` or floor-guard hit is not a finding.

## In scope, on a changed line

- Untrusted input at the boundary (injection, path, SSRF). Server-side URL fetch: https, allowlisted hosts, no link-local or metadata IPs.
- Authentication and authorization are decided in code on the server side of the boundary, not in the prompt. Secrets not logged, not committed, not interpolated into shells.
- LLM output is untrusted: no `eval`, raw SQL, `innerHTML`, or pipe-to-shell of model text.
- Prompt injection in a skill, a ticket, a journal file, or a fetched page, when that text reaches a sink: `eval`, SQL, `innerHTML`, a shell, or a tool call with a side effect. User text inside a prompt is not `prompt-injection` by itself.
- Supply chain: no `curl | sh`, no unexpected `postinstall`. `new_deps` must match the lockfile diff.

Class id on every finding line: `injection`, `authz`, `secret`, `supply-chain`, or `prompt-injection`, plus a changed `file:line`.

## Out of scope

- Denial of service, resource exhaustion, and theoretical races.
- "You did not add a hardening header."
- A missing check in client-side code.
- Anything the diff did not change.
