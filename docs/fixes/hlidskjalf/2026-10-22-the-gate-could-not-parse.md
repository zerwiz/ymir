## hlidskjalf · unversioned · 2026-10-22 — the gate could not be read, so the whole data face was dark

### Why

The Allfather reported four faults at once: Mánagandr not showing his calendars fully, the Yggdrasil
worktrees panel saying `SyntaxError: Unexpected end of JSON input` with "no worktrees", the well
reading `Bridge DOWN · COLD · 0 episodes`, and stats not syncing with pi's or opencode's database.
They were one fault wearing four faces.

`apps/hlidskjalf/server/index.ts` did not parse. Commit `068f0872` (2026-10-21) added the assistant row
to the watchtower and **ate the `return {`** that opens `wardState()`'s object literal — and lost the
`assistant` key with it, so the block was computed and then dropped. Since a module is read before it
runs, the gate API died at load, and every restart died the same way:

```
:3889              nothing listening        → the vite proxy: ECONNREFUSED, in the journal all evening
every /api/*       500, 0 bytes              → the SPA: "Unexpected end of JSON input"
well panel         DOWN / COLD               → mimir-bridge.py was healthy on :4602 the whole time
stats              empty                     → nobody asked, because the door was dead
```

### The fix

`return {` restored, and `assistant,` restored to the object it belongs to (the tower's assistant
block, which plan 101's audit believed existed at `index.ts:2643`, was being computed and thrown away).

Two sibling faults were found while the gate was open:

- **Þráðr asked for a door that was never built.** The panel calls `/api/terminal/status`; no such
  route existed, so it printed `terminal status 404` where a capability belongs. The route now
  reports the seat's real state — `enabled` follows `YMIR_TERMINAL`, and a `reason` says plainly that
  this gate holds no pty (the terminal backend is plan 93).
- **pi's usage was read one level too high.** `bin/desktop/hlidskjalf-usage.sh` read `usage` at the
  top of each JSONL record; pi writes `{"type":"message","message":{"usage":{…,"cacheRead":…}}}`. It
  counted **23** messages in 30 days where the session files carry 30,903 — measured after the fix,
  with cache keys `cacheRead`/`cacheWrite` now read as well.

### Verified

```
gate                 :3889 alive, /api/health 200 after login (401 unauthenticated)
routes               34 probed authenticated: all 200; the only gap (/api/desktop) is not a server route
worktrees            200, 8,807 b, real branches
well                 /api/well 200, 43,823 b; /api/mimir/health {"status":"up"}
stats                pi 30,903 msg · 173.4M in · 18.7M out · 8.05B cache_read
                     opencode 6,847 msg · 49.7M in · 2.59M out
thradr               /api/terminal/status 200, enabled=false, reason named
app-functional-guard parses PASS · routes PASS (44 UI calls answered) · live PASS
```

The ward proved itself against the real wound: with the `return {` removed again it reports
`Parse error` and exits 1; restored, it passes. Law: `RULES/29-the-apps-stay-whole.md`.
