## install · unversioned · 2026-09-23 — the fleet services ride the install

### Why
A fresh seat had the ward and the apps, but NOT the federation's surfaces
(the served well-MCP, the A2A node, the mill, the stone, the cards) — every
step of that was hand-run on whynot. The append makes a fresh seat raise them.

### What
- `bin/fleet-ensure.sh` — `status|ensure [--well-url]`: copies `tools/` to the
  seat, templatizes the five user units (path-substituted), raises them
  (best-effort, never a fail), and points the seat's pi `mcp.json` at the
  served well URL.
- `bin/ymir-install.sh` — new `fleet` step (after `the warden`), STEP_TOTAL 21.
- The Galdr asset's steps table + the count (25 rows, 27 functions).

### Files
- `bin/fleet-ensure.sh` · `bin/ymir-install.sh`
- `.agents/skills/galdr-ymirsystem/assets/installation.md`
