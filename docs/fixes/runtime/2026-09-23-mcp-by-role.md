## runtime · unversioned · 2026-09-23 — MCP config by role (plan 51 Phase 3)

### Why
- **Problem:** `~/.pi/agent/mcp.json` hardcoded **literal LAN IPs**
  (`bolthorn`/`skuld` at `192.0.2.111`), hand-edited per machine. A synced
  config naming one machine's LAN address is the same trap family as the lock
  pointer; and if the heart moved, every body broke.
- **Fix:** `bin/bridge/mcp-config.sh` **generates** the harness MCP config from the
  machine's role:
  - The record servers — **well/engram** (`:8317`), **skills/bolthorn** (`:8319`),
  **tickets/skuld** (`:8320`) — live on the **heart**.
  - A **body** addresses them by the heart's **tailnet** (or LAN) name from the
    registry; the **heart itself** uses `127.0.0.1`.
  - **firecrawl** stays local (stdio).
  - `show` prints the JSON; `write` writes `$HOME/.pi/agent/mcp.json` (with a
    backup). Ports are env-overridable (Rule 07).

### Verified
- `.agents/tests/mcp-config.test.sh` — **ALL PASS**: a dev body's well/tickets
  point at the heart's tailnet; the heart uses loopback and never self-addresses;
  the config parses; a missing registry falls back to loopback, no crash.
- On this box (dev): `well → http://whynot.<tailnet>.ts.net:8317/mcp`.

### Files
- `bin/bridge/mcp-config.sh`
- `.agents/tests/mcp-config.test.sh`

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: the forge. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #758
