## runtime · unversioned · 2026-09-23 — the skuld query bug, and fleet deploy on install

### Why
Two problems, found while filing a ticket through the `skuld` MCP.

1. **`o.split is not a function` — every `tickets_create` failed.** The v2 server
   called `rows(q(...))` at many sites, passing the **query object**
   (`{ok,out,err}`) where `rows()` expects the **string**. `rows = (o) => o ?
   o.split("\n") : []` therefore threw. The create path hit it at the namespace
   check, so no ticket could be made. Fixed by appending `.out` at every call
   site (`rows(q(...).out)`), nine of them across create, update, plans, counts,
   and the snapshot.
2. **`npm install` never refreshed the running server.** The package updates
   under `node_modules`, but a service executes a copy under `~/.fleet/` (made by
   `bin/fleet-ensure.sh`). So an install left the LIVE server on the old code —
   which is exactly how the bug above survived an install.
   - **`bin/fleet-deploy.sh`** (new): copies the tools from the package into
     `~/.fleet/` and `try-restart`s the units that are installed. Best-effort,
     `--dry-run` supported, and **Rule 10's deployer** for the postinstall path.
   - **`package.json`** gains `postinstall: bash bin/fleet-deploy.sh || true`, so
     an install now updates the running fleet too.

### Verified
- `node --check tools/tickets-mcp/server.mjs` clean; no `rows(q(` without `.out`
  remains.
- `bin/fleet-deploy.sh --dry-run` reports the files it would refresh and the
  units it would restart.
- After deploying the fix to `whynot` and restarting `skuld`, the ticket hall
  creates tickets again (a real ticket filed through the MCP).

### Files
- `tools/tickets-mcp/server.mjs`
- `bin/fleet-deploy.sh`
- `package.json`
