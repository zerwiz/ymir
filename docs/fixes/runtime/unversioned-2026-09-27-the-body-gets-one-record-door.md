## runtime · unversioned · 2026-09-27 — the body gets one record door (the MCP gateway, plan 51 P6)

### Why

An MCP address was a literal heart IP baked into every seat's config. When the
heart moves — and plan 51 Part 7 moves it to the always-on box — every seat's
`mcp-adapter.json` must be rewired, and a seat whose heart is down (or whose
network is gone) cannot reach its record MCPs at all. `skuld` hanging once had
already proved a single unreachable transport can kill the ticket hall.

P6 closes the MCP surface: **one local gateway per body** fronts the record MCPs
(well/engram · skuld tickets · bolthorn skills), so the harness points at a door
that remembers how to degrade.

### What

- **`bin/bridge/mcp-gateway.sh`** — the door: `serve` (foreground), `start`/`stop`
  (background, pidfile), `status`, `resolve` (the role-resolved upstream map),
  `sync`, `catalog`. It resolves upstreams through `bin/topology.sh`'s registry
  (`$YMIR_HOME/hodd/data/fleet.json`, read at runtime, never shipped) with
  tailnet → LAN → loopback preference, and degrades cleanly when the registry is
  absent (the well still serves loopback).
- **`tools/mcp-gateway/server.mjs`** — the engine, dependency-free: attached it
  proxies the resolved heart endpoints; detached/offline it serves the cached
  tool catalog (and last-read results), queues tool calls into the body's own
  journal (`state/journal/<host>.jsonl`, via `bin/records/journal-append.sh`), and
  reports upstreams unreachable. Its `sync` tool pushes the journal
  (`bin/records/journal-reconcile.sh`) and refreshes the catalogs — reconcile without
  shell access. The well is local-first: its own door is tried before the
  heart's. It never blocks a harness (a bounded per-upstream timeout).
- **`bin/bridge/mcp-config.sh`** — now emits the gateway as the door for well/bolthorn/
  skuld (`http://127.0.0.1:8316/mcp/<server>`); the config is role- and
  heart-address-independent, so a heart move is a re-resolve, not a rewire.
- **`bin/fleet-ensure.sh`** — `wire_mcp` writes the gateway door for the record
  MCPs (snotra still resolves the heart directly); the `mcp-gateway` unit is
  materialized (web-style, `__YMIR_BIN_DIR__`) and raised; `--well-url` still
  forces an explicit well door past the gateway.
- **`bin/autoboot-lib.sh`** — `mcp-gateway` is a role-owed program (heart ·
  forge · dev) with its description and the new unit template
  `tools/mill/systemd/mcp-gateway.service`.
- **`bin/bridge/mcp-gate.sh`** default target unchanged (`mcp-adapter.json`); no door
  renamed.
- **Tests:** `.agents/tests/mcp-gateway.test.sh` — the P6 gate: a REAL
  refused-network run (upstream killed → real ECONNREFUSED) proves
  initialize→tools/list served from the cache, a write journaled, and the
  journal flushed on reconnect with the catalog refreshed. `.agents/tests/
  mcp-config.test.sh` updated to prove the config points at the gateway and is
  identical across two different hearts.
- **Smoke:** `.agents/skills/lifecycle/smoke_test.sh` gains `mcp:gateway`
  (initialize→tools/list against the local door; skips when not raised).
- **Assets:** `harness-integration/README.md` (the pi MCP renderers) and
  `installation.md`'s `fleet` row describe the gateway door. Incidental truth-fix
  in the same block: the `install[29]` header declared 29 rows while 30 stood —
  corrected to `install[30]` (the TOON gate had been failing on it, pre-existing).

Honest scope (also in the PR body): the gateway caches the tool **catalog** and
last read **results**; it does not replay arbitrary detached writes at the heart
beyond the journal the P2b fold already owns. Snotra is not behind the gateway
yet. The unit is raised by `bin/fleet-ensure.sh ensure`; a seat not yet raised
reports `mcp:gateway` as a skip, and its configured record doors fail the
handshake until the raise runs.

galdr-reread: `harness-integration/README.md`, `installation.md`.

### Files

- `bin/bridge/mcp-gateway.sh` (new)
- `tools/mcp-gateway/server.mjs` (new)
- `tools/mill/systemd/mcp-gateway.service` (new)
- `bin/bridge/mcp-config.sh`
- `bin/fleet-ensure.sh`
- `bin/autoboot-lib.sh`
- `.agents/tests/mcp-gateway.test.sh` (new)
- `.agents/tests/mcp-config.test.sh`
- `.agents/skills/lifecycle/smoke_test.sh`
- `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md`
- `.agents/skills/galdr-ymirsystem/assets/installation.md`
