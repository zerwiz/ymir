# odrerir · 2026-09-27 — the hall reads the living door again

## Why

Two wounds left the React hall dark, and only one of them was the one first
measured.

1. **The door named a retired heart.** `apps/odrerir/src/skuld.ts` still
   defaulted `SKULD_URL` to `http://whynot.<tailnet>.ts.net:8320`, the Astro
   door's address. The 2026-09-27 cutover (plan 51 Part 9) retired whynot's Skuld
   unit and moved the record to the heart (zerwizserver), so every board call —
   tickets, plans, comments — rang a dead seat. The book read empty.
2. **The replacement door had no browser road.** The one local gateway
   (`bin/mcp-gateway.sh`, :8316) fronts Skuld over the heart and resolves it at
   request time, which is the right door — but the gateway answered no CORS
   preflight (`OPTIONS` → 405, no `access-control-allow-origin`). The retired
   skuld server HAD opened that road (`b0c1569`, "Skuld's CORS opened for the
   browser"); the gateway dropped it, so a page could not read the door even
   when the door was alive.
3. **The hall board's sample flag is governed by the FEED, not by Skuld.** The
   "Not connected — this board is the saga's sample" note
   (`src/hall/lh-board.js:506`) is removed only when `/livehall.json` answers a
   feed. `bin/hall-snapshot.sh` writes `public/livehall.json`, but a build bakes
   that file into `dist/` — and a packaged install carries NO snapshot (the file
   is gitignored), so the saga note could stand forever with a perfectly healthy
   Skuld door. The measurement in the errand ("falls when skuldInit cannot reach
   the door") read the wrong cause; the true cause is the static, unbuilt feed.

## What

- **`apps/odrerir/src/skuld.ts`** — the door is now THIS BODY's gateway:
  `http://127.0.0.1:${VITE_MCP_GATEWAY_PORT:-8316}/mcp/skuld`. The app names no
  heart; the gateway resolves it at request time. `VITE_SKULD_URL` still
  overrides the whole door. The port default (8316) is the gateway's own
  (`MCP_GATEWAY_PORT` in `bin/mcp-gateway.sh`).
- **`tools/mcp-gateway/server.mjs`** (engine v1.1.0) + **`bin/mcp-gateway.sh`** —
  the door admits browser readers: `OPTIONS` answers 204 and every answer carries
  `access-control-allow-origin`, `…-allow-headers`, `…-allow-methods`,
  `…-expose-headers`, `…-allow-private-network`. The gateway binds 127.0.0.1, so
  only this body's own pages can reach it.
- **`apps/odrerir/vite.config.ts`** — `ymir-livehall-feed` serves
  `public/livehall.json` from disk on EVERY request in dev and preview
  (`cache-control: no-store`). The feed is whatever the snapshot job last wrote;
  absent → 404 → the board honestly keeps the saga's tale. A build no longer
  bakes (or loses) the feed.
- **`bin/odrerir-mcp-smoke.sh`** — defaults to the gateway door and parses the
  gateway's plain-JSON `tools/list` as well as the heart's SSE frame (the
  alignment assert was reading only `data:` frames, so it failed on the gateway
  even with 13 real tickets answering).
- **`.agents/skills/lifecycle/smoke_test.sh`** — the `boards` row probes the
  gateway's `/health` and skips when it is not raised (a loopback door, not
  another seat's name).
- **`.agents/tests/mcp-gateway.test.sh`** — asserts the browser road (preflight
  204 + CORS on an answered call).
- Assets updated in the same change: `odrerir-hall.md` (the owning asset) and
  `harness-integration/README.md` (the MCP door story).

## Verified

- `node --check tools/mcp-gateway/server.mjs`; `bash -n` on the four shell files.
- `.agents/tests/mcp-gateway.test.sh` — **ALL PASS** (19 assertions, incl. the 3
  new CORS assertions).
- `apps/odrerir`: `tsc --noEmit` exit 0; `vite build` exit 0.
- **Live read through the door, the updated engine on a throwaway port (8326)**
  against the real heart: `initialize` → the gateway identity; `tools/call
  tickets_list {namespace:"ymir"}` → 13 real rows with
  `access-control-allow-origin: *` on the browser-origin request.
- **`bin/odrerir-mcp-smoke.sh`** against the running gateway (`:8316`):
  `tickets ok 13`, `plans ok 0 (empty)`, `tickets/get ok 11 fields`,
  `comments/list ok`, `alignment ok — every tool the boards call exists on the
  server`.
- **Hall board cleared the sample flag (headless Chromium, `vite preview` on
  :4323):** `saga-note` count 0; `lh-asof` = `live · 2026-09-27T20:14:37Z`;
  `lh-count` = "read live from the hall's own snapshot". The feed is
  request-time: regenerating `public/livehall.json` changed the served body
  without a rebuild; deleting it produced 404 (the tale stands honestly).
- **Tickets board rendered live (same headless run, built with
  `VITE_SKULD_URL=http://127.0.0.1:8326/mcp/skuld` so the proof carried the NEW
  engine):** chip `book connected`, title "…/mcp/skuld — tickets_list answered",
  and the real row "The numbered book is live".

## What still blocks on this box (honest)

The running `mcp-gateway.service` (user unit, `ExecStart=/bin/bash
$HOME_SEAT/ymir/bin/mcp-gateway.sh serve`) still runs engine **v1.0.0** from
the tree at merge time, so the canonical `:8316` door answers no CORS yet and the
board's default build shows `book NOT connected — tickets_list: Failed to fetch`
(verified). **After the merge, restart the body's door:**
`systemctl --user restart mcp-gateway` — it then loads v1.1.0 and the hall reads
live on the default door, no override needed.

## Files

- `apps/odrerir/src/skuld.ts` · `apps/odrerir/vite.config.ts`
- `tools/mcp-gateway/server.mjs` · `bin/mcp-gateway.sh`
- `bin/odrerir-mcp-smoke.sh` · `.agents/skills/lifecycle/smoke_test.sh`
- `.agents/tests/mcp-gateway.test.sh`
- `.agents/skills/galdr-ymirsystem/assets/odrerir-hall.md`
- `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md`
