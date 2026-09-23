# runtime · 2026-09-23 — the skills well (skills-MCP :8319)

## Why
The Ymir skill-hoard (`$ROOT/.agents/skills`) was seat-bound: a body either
had the tree (essence-fetch) or reached no skills. The fleet nightman can load
any skill from any seat — served, always the master, no per-seat binds.

## What
- `tools/skills-mcp/server.mjs` — a deps-free stdio MCP server: resources
  (`skills://<name>`, + assets) + a `load_skill` tool; a traversal guard; served
  through `mcp-proxy` on :8319 (`skills-mcp.service`, the unit `%h`-native).
- `bin/fleet-ensure.sh` — mirrors the master `.agents/skills` into
  `~/.fleet/skills` (refreshed each ensure), raises the unit (gated on
  mcp-proxy + the mirror), and writes the `skills` MCP entry beside `well` in
  the seat's pi mcp.json.
- Proven: the wire handshakes (initialize → capabilities, tools, 28 skills in
  resources/list).

## Files
- `tools/skills-mcp/server.mjs` · `tools/mill/systemd/skills-mcp.service`
- `bin/fleet-ensure.sh`
