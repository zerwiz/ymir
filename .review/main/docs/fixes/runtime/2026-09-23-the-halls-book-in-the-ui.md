# runtime · 2026-09-23 — the hall's book in the UI

## Why
Skuld's store + MCP were live on the heart, but the mead-hall's window showed
no tickets or plans. Plan 43 Phase 3: the book in the UI.

## What
- `apps/odrerir/src/pages/tickets.astro` — the hall's book page: the client
  speaks the Skuld MCP (streamable HTTP at the heart), lists tickets + plans,
  cuts new ones — and the blocking law's refusals answer right in the page.
- `tools/tickets-mcp/server.mjs` — CORS + OPTIONS preflight on the :8320 wire
  (the browser's fetch needs the door opened).

## Files
- `apps/odrerir/src/pages/tickets.astro` · `tools/tickets-mcp/server.mjs`
