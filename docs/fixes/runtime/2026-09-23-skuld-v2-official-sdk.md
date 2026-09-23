# runtime · 2026-09-23 — Skuld v2 on the official MCP SDK

## Why
Plan 43's corrective: the hand-rolled JSON-RPC wire was not a proper MCP.
The tickets + plans + comments + blocks now ride `@modelcontextprotocol/sdk`
(StreamableHTTP, the McpServer, zod schemas) — same store, same laws.

## What
- `tools/tickets-mcp/server.mjs` — the official SDK: the McpServer,
  the streamable-http transport, zod-anchored tools: tickets_create/list/get/
  update, plans_create/list/get/update (the Allfather's approval: drafted ->
  approved -> shipped), comments_list/post, blocks_status/clear, namespaces_list
  (the 20 registered projects). The blocking laws ride inside: the review
  march, the Done-witness (the description 10+), the operator's hand.
- The served mode carries the CORS; the psql spine stays (deps-free literals).

## Files
- `tools/tickets-mcp/server.mjs`
