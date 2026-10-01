# Project Map

> **Destination:** <one sentence from the human: what this project is for>
> **Where things stand:** `scripts/gate.sh next --all` (in flight, open, blocked, recently closed).

## Standing Notes

- **Workflow:** `AGENTS.md` § The railroad. A new ticket stays `blocked-on-answers` until a human sets `status: open`. Skills: `/agentic-task`, `/agentic-implement`,
  `/agentic-critic`, `/agentic-pr`, `/agentic-archive`, `/agentic-status`, `/agentic-grill`,
  `/agentic-handoff`, `/agentic-postmortem`; intake `/agentic-idea`, `/agentic-interview`;
  craft (when `craft_skills: true`) `/agentic-debug`, `/agentic-api`, `/agentic-security`,
  `/agentic-migrate`. `/agentic-audit` runs only on explicit request.
- **Domain context:** `.agentic/context/CONTEXT.md`.
- **Decisions:** `.agentic/context/adr/` — [0001 Enforcement vs convention](context/adr/0001-enforcement-vs-convention.md).

## Out of Scope

- Live forge branch-protection settings (the workflow ships; humans set required checks).
- A PID registry for long-running dev servers.
- Harness-owned OS sandboxes and cloud IAM (tool sandboxes are configured, not enforced from bash).
