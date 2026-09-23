## runtime · unversioned · 2026-09-23 — servers live in the repo, and the skuld server works

### Why
- **Problem:** the ticket MCP (`skuld`, `:8320`) failed every real handshake with
  *"Already connected to a transport"*. The MCP smoke check had proved it once
  after a restart, then it broke again.
- **Two root causes, both Rule 10 violations:**
  1. **The deployed file was not the repo's.** The running service was a
     hand-placed `~/.fleet/tickets-mcp-v2/server.mjs` that created a **new
     transport per request** and called `server.connect(transport)` on a single
     module-level `McpServer` — which the SDK forbids. The repo's own
     `tools/tickets-mcp/server.mjs` held the correct per-session pattern.
  2. **The repo's source was itself broken.** A merge had left the
     `sync_snapshot` registration **outside** `makeMcp()`, so the repository file
     threw `ReferenceError: server is not defined` and could not start at all —
     the fix could not be deployed because the source was not the source.
- **Fix:**
  - `tools/tickets-mcp/server.mjs` — `sync_snapshot` is registered **inside**
    `makeMcp()` (with the other tools); the file starts and the per-session
    transport map works.
  - Redeployed to the **repo's** fleet path (`~/.fleet/tickets-mcp-server.mjs`)
    and re-pointed the unit's `ExecStart` there (per `bin/fleet-ensure.sh` and
    `tools/mill/systemd/skuld.service`), abandoning the ad-hoc `tickets-mcp-v2`.
  - **New law: `RULES/10-deployed-servers.md`** — every server/service/worker/MCP
    runs from a file the repo owns and is deployed from it; never hand-placed.

### Verified
- Three consecutive handshakes each return `serverInfo.name=skuld` with a fresh
  session id, and `tools/list` returns **15 tools** every time.
- The smoke test: `mcp:skuld OK — connected, 15 tools`.

### Files
- `tools/tickets-mcp/server.mjs`
- `RULES/10-deployed-servers.md`
- `RULES/README.md`
