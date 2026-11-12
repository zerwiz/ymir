# fleet · 2026-11-12 — the fleet's doors face loopback, refuse foreign web pages, and Skuld can start

## Files
- `tools/mill/systemd/{cards,skills-mcp,skuld,ratatoskr,snotra}.service`: `YMIR_FLEET_BIND=127.0.0.1` by default, widened only through `~/.config/ymir/fleet.env`; no database password in the Skuld unit
- `tools/tickets-mcp/server.mjs`, `tools/snotra/server.mjs`: listen on `BIND`; no wildcard CORS; a request from a foreign origin gets 403
- `packages/a2a/ratatoskr/server.ts`: `Bun.serve` gets a loopback-default `hostname`
- `tools/tickets-mcp/package.json`, `package-lock.json`: the Node doors' dependencies, declared and locked
- `bin/fleet/fleet-ensure.sh`: deploys `ledger.mjs` and the lockfile, installs with scripts off, and gives the agent card a loopback URL unless one is named
- `tests/test_fleet_doors_loopback.sh`: 26 static checks, registered in `tests/run.sh`

## Why
A fresh install on a stock Fedora Workstation laptop showed five problems. Fedora's default firewall zone admits
every high port, so each of the first three was reachable from the local network.

| Door | What it did | What anyone on the LAN could do |
|---|---|---|
| cards (`:8318`) | `python3 -m http.server --bind 0.0.0.0` | read the agent card, which named the machine's LAN address |
| skills-mcp (`:8319`) | `mcp-proxy --host 0.0.0.0` | call the skills MCP with no credential |
| Ratatoskr (`:8301`) | `Bun.serve` with no hostname | send JSON-RPC with no credential; its executor queries the memory well's recall |
| Skuld (`:8320`) | `listen(PORT, "0.0.0.0")` | read and write tickets with no credential |
| Snotra (`:8321`) | `listen(PORT, "0.0.0.0")` | read meeting minutes with no credential |

Two more problems sat behind those:

- **Wildcard CORS.** Skuld and Snotra answered every origin with `access-control-allow-origin: *`. Even on
  loopback, any web page open in the operator's browser could call them.
- **Skuld could not start.** The deploy copied `server.mjs` but not the `ledger.mjs` it imports, and no
  `package.json` declared `@modelcontextprotocol/sdk` or `zod`. The unit failed on its first start, so a new
  collaborator could not do the runbook's "set up your Skuld first".

## Fix
- **Loopback by default.** Every unit sets `YMIR_FLEET_BIND=127.0.0.1` and reads
  `EnvironmentFile=-%h/.config/ymir/fleet.env`. The servers read the same variable, with `SKULD_BIND`,
  `SNOTRA_BIND` and `RATATOSKR_HOST` as per-door overrides.
- **No foreign web pages.** There is no wildcard CORS. A request carrying an `Origin` header is refused with 403
  unless that origin is listed in `SKULD_CORS_ORIGINS` or `SNOTRA_CORS_ORIGINS`. MCP clients send no `Origin` and
  are unaffected.
- **Skuld starts.** `ledger.mjs` and a locked dependency set are deployed. `npm ci --omit=dev --ignore-scripts`
  runs only when the lockfile changed or the SDK is missing.
- **The card stays local.** Its URL is `http://127.0.0.1:8301` unless `YMIR_FLEET_CARD_URL` names a reachable one.
- **No password in the unit.** `SKULD_PGPASSWORD=skuld` is removed from the template. The code's own fallback is
  unchanged, so behaviour stays the same; the role should get a real password, set in `fleet.env`.

> [!IMPORTANT]
> **A heart in a multi-machine fleet** has hands that reach its Skuld and Ratatoskr through `bin/bridge/mcp-gateway.sh`.
> That heart must now say where it listens: put `YMIR_FLEET_BIND=<its tailnet address>` in `~/.config/ymir/fleet.env`
> and restart the units. Widening the bind does not add a credential. These doors still need one before they face
> anything wider than a tailnet.

## Verified
- `bash tests/test_fleet_doors_loopback.sh`: 26/26 checks pass.
- `bash bin/gates/tests/test_skills_mcp.sh`: 0 failures.
- A live run of the deployed Skuld from a scratch folder installed its locked dependencies with scripts off.
  It bound `127.0.0.1` only, answered an MCP `initialize` with 200, and refused a POST and a preflight from a
  foreign origin with 403.
- `bash -n bin/fleet/fleet-ensure.sh` passes; `node --check` passes on both servers.

## CHANGE LOG

- **2026-11-12** — note written with the fix.
