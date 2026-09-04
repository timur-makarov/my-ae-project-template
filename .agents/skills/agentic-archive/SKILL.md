---
name: agentic-archive
description: "Use when a ticket's work has been merged or accepted and the ticket should be closed, indexed, and distilled into long-term memory."
---

# Agentic Archive: Closure & Memory Compaction

Close a verified ticket, index it, and distill what the project learned. History is append-only: never edit closed tickets or journal entries.

## 1. Closure criteria (all must hold — otherwise report what's missing and stop)

Run `scripts/gate.sh archive <NN>` (or `scripts/gate.sh archive <NN> --accepted-by "<verbatim human words>"` when the human explicitly accepts as-is). The gate writes `.agentic/state/close-authorized-<NN>`; the guard hook **denies** moving any file into `tickets/closed/` without that token. Do not skip the gate and move the file by hand.

The gate requires: ticket lint, fresh green stamp on this HEAD, critic APPROVED for MEDIUM/HIGH, no ASSUMED rows, Done Contract / constraint / Definition of Done boxes checked, and either a new `lessons.md` line or the sentinel `Lessons: none`.

## 2. Archive

- Ticket header: `Status: closed (closed at: YYYY-MM-DD HH:MM)`.
- Move `tickets/open/<NN>-<slug>.md` → `tickets/closed/<NN>-<slug>.md`.

## 3. Update the map

- §2 Decisions So Far: `- [<NN> — <title>](./tickets/closed/<NN>-<slug>.md) — <one-line gist>`.
- Remove from §3 Active Frontier.
- **Advance the frontier:** any §4 ticket blocked only by this one graduates to §3. Name the newly unblocked tickets in your report.

## 4. Distill memory

- `context/CONTEXT.md`: new terms → glossary; new invariants or risk boundaries → their sections. Then check the line count against `limits.context_md_max_lines` — over the cap, **compact** (merge related entries, drop stale ones) rather than append. CONTEXT.md is distilled memory, not a log.
- Major architectural decision (affects multiple modules or external systems) → ADR in `context/adr/` from the template, indexed in CONTEXT.md.
- Real defects the critic or review found → confirm they're in `journal/lessons.md` (one line each). If nothing to distill, append or keep the sentinel `Lessons: none` (the line must exist either way).

## 5. Tracker sync (only if `tracker: github-issues`)

`gh issue close <issue> --comment "Closed: <gist>. PR: <url>"` for the mirrored issue recorded in the ticket header.

## 6. Report

Sentence 1: ticket closed, archived, map updated. Proof: paths to the closed ticket and updated map. Next: the newly unblocked frontier tickets ready for `/agentic-implement`.
