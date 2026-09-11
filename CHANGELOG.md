# CHANGELOG

All significant runtime, policy, and architectural changes for the Ymir platform.
Entries are appended chronologically; never rewritten.

## 2026-09-11 — The well is real (Mimirsbrunn / engram)

- **New:** `bin/mimir-bridge.py` + `bin/mimir-bridge.sh` — the `:4602` HTTP face
  the supervision tree named but that upstream never shipped (engram exposes a
  CLI + MCP server only). Endpoints: `/health`, `/recall`, `/recent`,
  `/timeline`, `/inspect`, `/observe`.
- **New:** repo-local store `.agents/memory/kaia.engram`, seeded from the
  368-episode JSONL well.
- **Wired:** gate API `/api/well` now does semantic recall via the bridge (local
  file fallback) and `/api/mimir/health` is live; the Well gate's Bridge tile
  and timeline read real data (mock removed).
- **Harnesses:** the engram MCP server is registered for OpenCode, Pi, Claude,
  Cursor, and Codex; requires the `mcp<2` SDK (`engram-mcp` breaks on mcp 2.x).
- **Lifecycle:** the bridge is raised by `scripts/start.sh` and
  `bin/saga-session-start.sh`; the stale `engram.server` command was corrected.
- **Verified:** bridge up (370 episodes), semantic recall, MCP handshake
  (engram 1.30), compliance 8/8, smoke 8/8.

## 2026-09-11 — Stats 1:1, Kaia chat, Forge prompts

- **Stats:** ported the full Smiðja `StatsResponse` 1:1 into the gate API and
  the Stats gate — runs/success/fail/running/rate, token optimization
  (input/output/cache_read/cache_write, cache-hit ratio, avg CHR/run),
  local-vs-online provider split with per-model table, 40-model commercial
  catalog (cached/total/savings/%), by-chain and by-workflow. A real run
  renders live.
- **Chat (Kaia):** per-session JSONL store (`state/chat/`), list/history/delete
  endpoints, a rolling **40-message** window, query-grounded well recall before
  every dispatch, an animated "Kaia is thinking…" indicator, a session sidebar
  (new/switch/delete), a connected-model datalist (314 models) with free-type,
  and Eindri lane toggles.
- **Forge:** a Prompts mode to read/edit the smithy's
  `prompt_engineering/<agent>/{system,user}.md` (path-guarded save) and a
  connected-model datalist for agent models.
- **Verified:** `tsc` + `vite build` green, live chat via local model with
  recall on, prompt roundtrip + traversal guard, compliance 8/8, smoke 8/8,
  lint 4/4.

## 2026-09-11 — Smiðja views are repo-local

- **Change:** Removed the last external dependency. `bin/factory-observe.sh`
  (which defaulted to `~/command/factory/factory_data/factory.db`) is gone;
  `bin/smidja-observe.sh` reads the repo's own
  `smidja/smidja_data/smidja.db` read-only and reports absence honestly.
- **API:** `/api/factory` replaced by `/api/smidja/{health,sessions,sessions/:id,decisions,stats}`
  (`bun:sqlite`, read-only).
- **UI:** four Hlidskjalf gates added — Sessions, Trace, Decisions, Stats —
  reading the smithy's trace. No `command`/`factory` references remain in the
  runtime or portal.
- **Verified:** `tsc` + `vite build` green, SPA 200, endpoints honest-absent,
  Galdr compliance 8/8, smoke 8/8.

## 2026-09-11 — Gleipnir lock PID binding fix

- **Problem:** The session lock (`state/.lock`) was written with the digest
  helper's PID (a short-lived child) instead of the live Pi harness PID. The
  harness adapter (`gna-pi-watch.ts`) reported "no live session holds the lock"
  and refused to arm the watcher.
- **Root cause:** `BROKK_SESSION_PID` was never injected into the spawn chain.
  `gleipnir_lock_acquire` fell back to `$$` (helper PID).
- **Fix:** `.pi/extensions/syn-turnend-guard.ts` and
  `.pi/extensions/gna-pi-watch.ts` now pass `BROKK_SESSION_PID: String(process.pid)`
  in the spawn env, so the lock binds to the live Pi process.
- **Impact:** Session lock reclamation works on next Pi session start/reload.
  The stale lock (dead PID) is overwritten by the live PID.
