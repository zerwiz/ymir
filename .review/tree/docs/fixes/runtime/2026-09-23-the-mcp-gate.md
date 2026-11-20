# runtime · 2026-09-23 — the MCP gate (arm/disarm)

## Why
The seat's boot raised every configured MCP server, schemas and all — a
context budget eaten by tools a boot rarely needs (chrome-devtools above all:
dozens of tools, tens of thousands of tokens). Leaner boot, same toolbox.

## What
`bin/mcp-gate.sh <arm|disarm|status> [server]` — an on-call server is
AVAILABLE but not raised at boot; the entry moves in/out of the seat's pi
mcp.json (next session). `chrome-devtools` is the first citizen; others join
as their specs are seated. Measured before: bolthorn 105 B, skuld 2.3 KB,
the well ~2-4 KB — the served fleet's sum ~1.5 K tokens — the local chrome
seed dwarfed them; the gate is the answer to that one.

## Files
- `bin/mcp-gate.sh`
