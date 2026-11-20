# odrerir · 2026-09-28 — the gateway pins its door, and the feed lives in both shapes

## Why

Forseti's review of the merged #239 (`eindri/odrerir-live-door`) held the seal
with three items (`$YMIR_HOME/state/eindri-reports/odrerir-live-door-review.md`).
This note is the rework; the security item is named first because it is a live
hole, not a doc slip.

1. **The door was open to any page (the severe one).** `tools/mcp-gateway/server.mjs`
   answered `access-control-allow-origin: *` with
   `access-control-allow-private-network: true`, and the request path carried
   **no origin gate and no token**. `127.0.0.1` is exempt from mixed-content
   blocking, so *any* page the browser loads — an https page included — could
   reach the loopback door, and the door fronts `well`, `bolthorn` and `skuld`:
   a drive-by page could read AND write the record. Forseti verified
   `Origin: https://evil.example` → `204` + CORS. The stated invariant
   ("the gateway binds 127.0.0.1, so only this body's own pages can reach it")
   was false — a browser may reach loopback.
2. **The feed repair did not reach a packaged seat.** `ymir-livehall-feed` lives
   in `apps/odrerir/vite.config.ts`, which is not in the published tarball
   (`npm pack --dry-run`: `dist/` · `electron/` · `README.md` · `LICENSE` ·
   `package.json`). A packaged seat resolves Óðrerir to
   `node_modules/@zerwiz/odrerir` and is served by `vite preview` from `dist/`,
   so the plugin never runs and the board served the publish-time
   `dist/livehall.json` (stale), never the snapshot job's write.
   `docs/fixes/odrerir/2026-09-27-the-hall-reads-the-living-door.md` asserted
   the opposite ("A build no longer bakes (or loses) the feed"), true only for
   the clone shape. (Append-only: that note is history and is not rewritten;
   this note is its correction.)
3. **The owning asset named the wrong knob.** `.agents/skills/galdr-ymirsystem/assets/odrerir-hall.md`
   said the door port came from `MCP_GATEWAY_PORT` in two rows; the app's
   build-time knob is `VITE_MCP_GATEWAY_PORT` (`apps/odrerir/src/skuld.ts:24`).
   The asset's own Knobs row was already correct; the two rows disagreed.

## What

- **`tools/mcp-gateway/server.mjs`** (engine **v1.2.0**) — the door is PINNED.
  The admitted browser set is any origin whose host is loopback
  (`127.0.0.1` · `localhost` · `[::1]`) plus any origin listed in
  `MCP_GATEWAY_ALLOWED_ORIGINS`. An `Origin` outside the set is refused with
  **403 before the method gate** — not merely denied CORS, because a "simple"
  request can carry a JSON body without a preflight. The origin is echoed, never
  `*`; `access-control-allow-private-network` is **removed**. A request with no
  `Origin` is a native MCP client (pi/opencode/curl), never a browser, and is
  admitted.
- **`bin/bridge/mcp-gateway.sh`** — the same story in the owning comment (the false
  "only this body's own pages" invariant is gone), `VERSION="1.2.0"`, and
  `MCP_GATEWAY_ALLOWED_ORIGINS` documented and exported.
- **`.agents/tests/mcp-gateway.test.sh`** — the browser-road block now proves the
  pin: the hall's own origin answers `204` and is echoed (not `*`); a foreign
  origin is refused on the preflight (`403`, no `204`), on a READ, and on a
  WRITE; no answer carries `allow-private-network`.
- **`bin/time/snotra/hall-snapshot.sh`** — writes the snapshot to `public/livehall.json` AND,
  when the app carries a `dist/`, to `dist/livehall.json`. The clone is served by
  the request-time plugin (public/); the packaged seat is served by `vite preview`
  from `dist/`, where the job's write now lands. The served feed is the job's
  last write in BOTH shapes; the publish-time bake is superseded in place.
- **`bin/time/nornir-job-hall-snapshot.sh`** · **`apps/odrerir/vite.config.ts`** —
  comments corrected to describe both shapes (the plugin's own code is
  unchanged).
- **`.agents/skills/galdr-ymirsystem/assets/odrerir-hall.md`** — the two rows now
  name `VITE_MCP_GATEWAY_PORT`; the CORS prose states the pin; a dated section
  records this rework. **`harness-integration/README.md`** — the door paragraph
  now carries the pin and drops the false loopback invariant (engine v1.2.0).
  **`nornir-jobs.md`** — the Hall-snapshot job's owning asset now names both
  write targets (public/ for a clone, dist/ for a packaged seat).

## Verified

- `node --check tools/mcp-gateway/server.mjs`; `bash -n` on `bin/bridge/mcp-gateway.sh`,
  `bin/time/snotra/hall-snapshot.sh`, `bin/time/nornir-job-hall-snapshot.sh`,
  `.agents/tests/mcp-gateway.test.sh` — all green.
- `.agents/tests/mcp-gateway.test.sh` — **ALL PASS**, 25 assertions. The new
  security assertions, live on a real gateway:

```
ok - preflight: the hall's own origin answers 204
ok - preflight: the origin is echoed (pinned, not *)
ok - preflight carries no allow-private-network widening
ok - preflight: a foreign origin is REFUSED (403, no 204)
ok - foreign preflight carries no widening
ok - a foreign origin is refused a READ (403)
ok - a foreign origin is refused a WRITE (403)
ok - the hall's own origin is served (200)
ok - an answered call carries the pinned origin
```

- **Item 2, the packaged tarball.** `npm pack --dry-run` in `apps/odrerir` still
  ships only `LICENSE · README.md · dist/** · electron/** · package.json` — no
  `vite.config.ts`. A throwaway packaged-shape dir (`dist/` only, no config),
  served by `vite preview`:

```
before the job:  {"generated_at":"2026-09-25T05:00:37Z","stale":true}   (the bake)
run: YMIR_ROOT_DIR=<fake root> bin/time/snotra/hall-snapshot.sh
after the job:   generated_at: 2026-09-28T01:56:27Z | stale flag: None   (no rebuild, no restart)
wrote:           apps/odrerir/public/livehall.json  AND  apps/odrerir/dist/livehall.json
```

- **Item 2, the clone shape** (`vite preview` with the plugin present): absent
  `public/livehall.json` → `404`; after the job's write → `200` with
  `cache-control: no-store`, no rebuild. Both shapes serve the living feed.
- **Item 3:** the asset rows at §1 and §4 now read `VITE_MCP_GATEWAY_PORT`;
  `grep -n 'MCP_GATEWAY_PORT'` shows the app-facing rows agree with the Knobs row.
- `bash bin/gates/guards.sh` — PASS (runtime-guard, defaults-guard).
- `bash .agents/skills/galdr-ymirsystem/scripts/compliance-check.sh` — 15/15 PASS
  (governed assets current).

## Scope, stated plainly

The clone shape serves `public/livehall.json` through the request-time plugin;
the packaged shape serves `dist/livehall.json` written in place by the snapshot
job. Both are the job's last write. The publish build may still copy a
`public/livehall.json` into `dist/` if one exists at build time, but the job
overwrites that file on the seat, so the served feed is never the bake.

## Files

- `tools/mcp-gateway/server.mjs` · `bin/bridge/mcp-gateway.sh`
- `.agents/tests/mcp-gateway.test.sh`
- `bin/time/snotra/hall-snapshot.sh` · `bin/time/nornir-job-hall-snapshot.sh`
- `apps/odrerir/vite.config.ts`
- `.agents/skills/galdr-ymirsystem/assets/odrerir-hall.md`
- `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md`
- `.agents/skills/galdr-ymirsystem/assets/nornir-jobs.md`
