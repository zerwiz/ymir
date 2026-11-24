# 2026-11-24 — the ymir-mcp install hint pins `mcp<2`

`bin/mcp/ymir-mcp.py` imports `mcp.server.fastmcp`. The MCP SDK 2.x removed `FastMCP` (renamed
`MCPServer`), so the hint `pip install --user mcp` installed a version the door could not import,
and the door then reported the SDK as missing.

The hint now reads `pip install --user 'mcp<2'`, matching `bin/engine/prereq-ensure.sh`, and the two
feature pages that repeated the old command say the same.

## CHANGE LOG

- 2026-11-24 — review-mend: added missing heading for #923
