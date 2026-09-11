# CHANGELOG

## 2026-09-11 — Single-tenant workspaces shipped

- **First setup:** `bin/ymir-install.sh` (8 steps) + `bin/workspace-provision.sh`.
- **Model:** single tenant; workspaces (personal|work) over domains; houses = brands.
- **UI:** Login onboarding (name/kind/domains), Topbar workspace chip, AccountMenu/Profile relabelled.
- **Engines:** treehouse → `yggdrasil.sh pool`; sandcastle → `utgard.sh sandcastle`; no-mistakes → Mjollnir gate.
- **GitHub:** `bin/project-git.sh` reads `workspace/projects.yaml` `git{}`.
- **Verified:** build green, compliance 8/8, smoke 8/8, lint 4/4.


All significant runtime, policy, and architectural changes for the Ymir platform.
Entries are appended chronologically; never rewritten.

## 2026-09-11 — Hardcoded per-page feeds (header + stream)

- **New:** every gate has its own hardcoded, domain-appropriate rolling feed
  (16 pools, `src/data/feeds.ts`) — Fleet, Tasks, Well, Runes, Reviews,
  Processes (Valhalla), Files, Chat, Forge, Runtime, Cron, Sessions, Trace,
  Decisions, Stats, Profile. Extra Kaia “oracle by the well” lines for the chat
  page.
- **Header:** a live `PageFeed` now sits in the page header of every gate
  (glyph + hint on the left, the current page's latest 3 messages on the
  right), rolling.
- **Stream:** the bottom Stream keeps each page's last **40** domain messages,
  with the fleet-wide feed as fallback. A generator tops it up every 2.4s and
  the page is seeded on first visit so it is never cold.
- **Verified:** `tsc` + `vite build` green, SPA 200, compliance 8/8, smoke 8/8,
  lint 4/4.

## 2026-09-11 — Per-page rolling 40 message feeds

- **Change:** the bottom stream is no longer one global 120-line feed. Every gate
  keeps its own rolling window of the **last 40** messages, and events are routed
  to the page they belong to (module → gate: `well`, `sessions`, `forge`,
  `runes`, `cron`, `reviews`, `processes`), with the fleet-wide feed as fallback.
  The stream header shows the current page. `STREAM_WINDOW = 40`, matching the
  chat's `CHAT_WINDOW = 40`.
- **Verified:** `tsc` + `vite build` green, SPA 200.

## 2026-09-11 — Galdr/Tyr assets: symlink, not copies

- **Fix:** `tyr-check/assets` is now a **symlink** to the canonical
  `galdr/assets`, so the two can never drift. A background process had been
  rewriting the registry, flipping the sync gate red; a symlink makes drift
  structurally impossible. Compliance back to 8/8 stable.
- **Verified:** compliance 8/8, smoke 8/8, lint 4/4.

## 2026-09-11 — Chat uses the root Pi model catalog

- **Fix:** the Kaia chat guessed a llama.cpp model id by regex and fell through
  to the Bifrost bridge (`:4603` → 401) when the guess failed.
- **Now:** the gate API reads the operator's root Pi catalog
  (`~/.pi/agent/models.json`) for the exact provider → base URL, model id, and
  key (llama.cpp router `:8080`, `sk-not-key-required`). A chosen local model
  is tried only on its own base; the default is the operator's Pi default
  (`qwen3.6-35b-a3b@iq3_s`). `/api/chat/models` lists the real connected set.
- **Verified:** `gemma-4-12b@q3_k_s`, `qwen3.6-35b-a3b@iq3_s` (default), and
  `qwen3.5-9b@q4_k_s` all answered live; no 401.

## 2026-09-11 — Shared well for every harness; no mock; clickable memories

- **Harnesses:** the engram MCP server is now registered for all four OpenCode
  accounts (`opencode`, `opencode-rd`, `opencode-work`, `opencode-oczer`), Pi
  (`~/.pi/agent/settings.json` + `mcp.json` + `.pi/mcp.json`), Claude, Cursor,
  and Codex. Registered **unscoped** so every harness reads the one shared well
  (per-call `agent_id` still attributes writes).
- **No mock:** purged every test/mock episode (`smoke`/`Test observation`) from
  both the engram store and `episodes.jsonl` → 367 true episodes. Test writes
  never enter the well.
- **UI:** Well memories are now **clickable** — `GET /api/well/episode?id=` and
  a bridge `/episode` endpoint feed a modal with the full memory text.
- **Bridge fix:** `/recent` and `/recall` restored; added `/episode`.
- **Lifecycle fix:** `bifrost-bridge.sh` / `mimir-bridge.sh` now stop by process
  match when the PID file is missing, and record the PID when the port is
  already up — so `scripts/stop.sh` truly lowers the whole system and
  `scripts/start.sh` truly raises it.
- **Galdr:** new asset `.agents/skills/galdr/assets/memory-well.md` (store,
  bridge, MCP, harness matrix, laws, verify), routed in `SKILL.md`; registry +
  harness README updated; mirrored to tyr.
- **Verified:** MCP recall 1.0 / stats 367, full stop→start cycle (3888/3889/
  4602/4603/8437), compliance 8/8, smoke 8/8.

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

## 2026-09-11 — Desktop shell, tunnel, and temporary auth

- **Electron:** `apps/hlidskjalf/electron` + `scripts/electron.sh` open Hlidskjalf
  (and Smiðja) as a native window; raises the stack if down.
- **Tunnel:** `ymirdell.zerwiz.org` → `:3889` via `bin/gjallarhorn-tunnel.sh`
  (cloudflared config in `midgard/infrastructure/ingress/cloudflared-ymir.yml`).
- **Auth:** hardcoded HTTP Basic (`zerwiz:allfather`, `HLIDSKJALF_AUTH`) on the
  gate API, which now also serves the built SPA. Temporary — move to Heimdall +
  `.env.local`.
- **Mobile:** PWA manifest added; recommended APK = Capacitor over the tunnel.

## 2026-09-12 — Updater forged + credential moved to env

- **`bin/brokk-update.sh`** — the sanctioned, guarded updater the `ymir-update`
  skill calls: fast-forward only, refuses a dirty/diverged tree, `--yes` to
  stash+restore, `--check` to report. Never force-pushes.
- **Credential law:** the gate login (`HLIDSKJALF_AUTH`) no longer has an inline
  default; it is read from `.env.local` (Bun auto-loads it). Server falls back to
  an open gate only when unset (dev), with the key added to `.env.example`.

## 2026-09-12 — Ró preference moved out of the tracked tree

- `.agents/config/ro` was a **git-tracked** per-user toggle (calm on/off); any
  toggle dirtied the tree and made `bin/brokk-update.sh` refuse. It now lives in
  the gitignored `state/ro`; `YMIR_RO`/`BROKK_RO` set a default; the legacy
  `config/ro` is read once for upgrade then never written. Tracked file removed.

## 2026-09-12 — Fleet preferences

- `data/fleet.md` (gitignored) holds fleet-wide per-user settings (`ro: on|off`).
- `bin/fleet-apply.sh` applies them to this home + every registered Eindri-home
  (into each home's gitignored `state/`; remote routes reported).
- `bin/brokk-update.sh` re-applies fleet preferences on every sweep — one setting
  reaches the whole fleet, no tracked tree dirtied.
