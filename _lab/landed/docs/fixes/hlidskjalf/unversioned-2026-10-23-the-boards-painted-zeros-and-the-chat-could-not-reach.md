## hlidskjalf · unversioned · 2026-10-23 — the boards painted zeros, and the chat could not reach the rail

### Why

Three faults, one evening, reported as "why can't I see what's going on", "the omni chat is
broken", and "Nornir and Valhalla are dead". None of the three was a dead service.

1. **A refused call was painted as a zero.** The gate's sessions lived in a `Map` in the API
   process, so every API restart voided every cookie. The SPA checked `/api/session` once at
   mount, and each board swallowed its own failure (`catch(() => previous)`) — so a 401 after a
   restart rendered as **0 jobs declared / STOPPED** in Nornir and **0/0 watched** in Valhalla,
   with nothing on screen saying the board had not been read at all. Measured while the truth was
   the opposite: `bin/time/nornir-cron-start.sh --status` → `running pid=4031203 jobs=33`; `docker ps`
   → 17 containers up, `systemctl` → 39 active, `valhalla.sh list` → 56 processes.
   - Sessions now survive a restart: the cookie is a signed statement (`login.expiry.mac`, HMAC-SHA256)
     verified against one machine key at `$YMIR_HOARD/state/gate-session.key` (0600). No session is
     written to disk or held in memory, so the "no bearer at rest" law still holds while a restart
     stops logging the operator out.
   - The cron board carries the failure: `cronError` names the cause ("the gate is locked — the
     session did not survive the last API restart") instead of showing zeros.

2. **The omni chat could not authenticate to the local rail.** `piCatalog()` built its targets from
   `~/.pi/agent/models.json` and took `apiKey` from that file — but Pi keeps provider credentials in
   `~/.pi/agent/auth.json`, so the rail was called with no `Authorization` header and answered 401
   while it was up and serving. The chat fell through to Bifrost (`:4603`), which proxies LM Studio
   (`:1234`) and answers 500 for every model, and reported "no model backend answered".
   - The catalog now borrows the provider's key from `auth.json` when `models.json` has none.

3. **Nornir was read-only.** The board could report the scheduler and could not raise it, which is
   why "0 jobs" was unanswerable from the UI. `POST /api/cron/start|stop` run the SAME script the
   session start runs (`bin/time/nornir-cron-start.sh [--stop]`), bust the 3 s status memo, and
   return the scheduler's own word. The board's head gains Start/Stop.

### Files
- `apps/hlidskjalf/server/index.ts` — signed session tokens; `piAuthKeys()` + `key: pv.apiKey || authKeys[pkey]`;
  `cronAct()` + `forgetMemo()`; routes `/api/cron/start`, `/api/cron/stop`.
- `apps/hlidskjalf/src/services/api.ts` — `cronStart`, `cronStop`.
- `apps/hlidskjalf/src/state/store.ts` — `cronError`, `cronFailure()`, `startCron`, `stopCron`.
- `apps/hlidskjalf/src/gates/Cron.tsx` — Start/Stop hand; the unread-schedule panel.

### Verified (measured, this seat)
- `/api/chat` with `qwen3.6-35b-a3b@iq3_s` → `live: true`, body `ok`, 15 s (was: 4603 → 500).
- `POST /api/cron/stop` → `cron: stopped pid=4031203`, `running: false`; `POST /api/cron/start` →
  `cron: started pid=560876 jobs=33`, `running: true`.
- **Session survival:** a cookie minted on api pid 671564 still answers `authed: true` against pid
  682055 after a restart — and with it `/api/cron` reads 33 jobs and `/api/processes` 58 daemons.
- `bunx vite build` clean; `tsc --noEmit` 0 errors; new bundle `index-D6N8km53.js` served on :3888.

### Owed, and named
- The chat's model default (no model chosen) resolves to `llama-swap/apodex-1.0-mini` — the 21.7 GB
  preset — so the first message swaps the rail away from the resident model. A default is the
  Allfather's decision, not an agent's guess; the picker is the hand until then.
- Bifrost (`:4603`) answers 500 for every model: it proxies LM Studio on `:1234`, which is down.
- A user-facing Start/Stop deserves its `docs/features/` page and a FEATURES.md row (Rule 14) — not
  yet written, so this change is not "finished" by the house's own law.
