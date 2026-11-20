## runtime · unversioned · 2026-10-17 — MCP config is written to the name pi actually reads (mcp.json)

### Why
pi 1.3+ reads ~/.pi/agent/mcp.json; only mcp-adapter.json was written, so pi saw no servers after a clean install.

### Files
- `bin/bridge/mcp-config.sh`
- `bin/bridge/a2a-mcp.sh`