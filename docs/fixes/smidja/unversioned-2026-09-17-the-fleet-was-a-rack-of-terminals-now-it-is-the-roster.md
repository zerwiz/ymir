## smidja · unversioned · 2026-09-17 — the Fleet was a rack of terminals; now it is the roster

### Why
- **We were tracking the tools.** `.agents/agents/` holds **21 agent definitions** —
  Brokk, Sindri, Bragi, Forseti, Mímir, Kvasir, Snotra, Huginn, Hnoss, Sága, Muninn,
  Frigg, Gróa, Jörð, Sýn, Týr, Galdr… — and the Fleet served **13 panes all named
  "OpenCode"**, role `opencode`. The board showed seats and never the smiths who might
  be standing in them.
- **`bin/hlidskjalf-agents.sh` now reads the roster** (`.agents/agents/*.md`, canonical
  per RULES/02) and joins each agent to its standing pane: figure, craft, model from
  the definition's frontmatter, and `live{}` only when a pane answers to it. An
  **unseated agent is still an agent** — hiding it is what made the board a rack.
- Harness seats that answer to no one on the roster are kept visible and named
  honestly, never dressed as agents.
- Served: **34 entries — 21 agents (roster first) + 13 harness seats, 14 joined**.

### Files
- *(carried from the frozen CHANGELOG.md)*
