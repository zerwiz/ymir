## harness · unversioned · 2026-11-22 — the figures served through the MCP, and a gate for MCP parity

### Why
A figure existed only in Ymir's own repository (one agent harness had none outside it), and the doors built on 2026-11-21 and 22 had no MCP tool. The Allfather: the figures must not be put into projects; they are loaded through the MCP, and a sent agent carries its kit (plan 358).

### Files
- `bin/mcp/figures.py` (new), `bin/mcp/ymir-mcp.py`, `bin/mcp/doors.yaml` (new), `bin/mcp/tests/test_figures.py` (new)
- `bin/gates/guards/mcp-parity-guard.sh` (new), `bin/gates/guards.sh`, `bin/gates/tests/test_mcp_parity_guard.sh` (new), `bin/gates/tests/test_new_doors.sh`
- `docs/features/the-figures-over-mcp.md`, `docs/features/_catalogue/entries/02-132-the-figures-over-mcp.md`

### What
The MCP lists each `.agents/agents` card as a prompt and the frame's and the current project's skills as resources. `ymir_figure(name, task, project)` returns the kit, and `ymir_research(question, project, plan)` searches, reads the main content, and keeps the finding in the library. `bin/mcp/doors.yaml` registers the doors that must have a tool, and `mcp-parity-guard.sh` fails when one has none. It is seeded with the Veil, the board sync, the publish door, fleet-tell and the plan tools; the context gauge waits for its door.

### Verified
`python3 bin/mcp/tests/test_figures.py` starts the real server from a temporary repository that has its own skill: the prompts list, `ymir_figure forseti` returns that repository's skill, rules and outcomes, and no file is written into the repository. `bash bin/gates/tests/test_mcp_parity_guard.sh` passes.

## CHANGE LOG

- **2026-11-22** — opened.
