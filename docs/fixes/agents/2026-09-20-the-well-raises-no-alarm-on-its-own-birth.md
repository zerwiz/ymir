## agents · unversioned · 2026-09-20 — the well raises no alarm on its own birth race

### Why
- **The `ymir-well` extension crashed at session start with an unhandled
  rejection** — `Extension "…/ymir-well.ts" error: Unable to connect. Is the
  computer able to access the url?` at `ymir-well.ts:25:28`, thrown from the
  `session_start` probe (line 120). The well (`bin/mimir-bridge.py` on `:4602`)
  was born **three seconds after** the session: `bin/saga-session-start.sh`
  raises it while the digest runs, so the extension's single `/health` fetch
  struck the window when nothing listened yet.
- **`call()` only understood HTTP answers.** It handled `!res.ok`, but a refused
  or timed-out connection makes `fetch` *reject* instead of returning a
  response — so the rejection escaped `call()`, the `session_start` handler
  threw, and pi logged the extension as broken. The file's own contract says a
  tool that throws teaches the model nothing and the well should say so once,
  plainly; the network failure was exactly the case the shape did not cover.

### Fix
- `call()` now wraps the `fetch` in a try/catch and shapes a connection failure
  as the same `{ok:false, status:0, body:…}` answer every other miss uses — so
  `well_recall` and `well_observe` report the outage into the thread instead of
  throwing out of it.
- The `session_start` probe retries `/health` up to six times at one-second
  spacing (a five-second grace for the bridge's birth) before it declares the
  well down and registers the `ymir-well-offline` message renderer. A birth
  race is no longer a crash — it is a beat of patience.
- A deploy only takes effect in a **new** session — a running one holds the code
  it loaded. Redeployed via `bin/valknut-load.sh --pi` (the shared source is
  the canonical file; the installed copy is a copy, verified identical after
  the deploy).

galdr-reread: `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md` —
the well's section and the extension one-home rule unchanged by this mend.

### Verify
- `curl -s http://127.0.0.1:4602/health` → `{"status":"up",…}` and a fresh
  session opens with **no** extension error; the tools answer friendlily when
  the bridge is down.

### Files
- `.pi/shared/extensions/ymir-well.ts`
- `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md`
- `docs/fixes/agents/2026-09-20-the-well-raises-no-alarm-on-its-own-birth.md`