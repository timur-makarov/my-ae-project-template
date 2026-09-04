---
name: agentic-ui
description: "Use when changing user-facing UI. Composition over config bags. WCAG 2.1 AA. No generic AI aesthetic. Pair with /agentic-browser."
---

# Agentic UI

- Colocate component, styles, tests. Composition (`Card` + `CardHeader`) not a config blob.
- Real copy, not lorem. Keyboard-reachable controls (`button`, not `div onClick`).
- Contrast 4.5:1. Focus trap in modals. Don't invent a purple palette if the project has tokens.
- Mobile and desktop if layout changed.

## Verification

`/agentic-browser` on the changed flow. Empty/error/loading states visited.