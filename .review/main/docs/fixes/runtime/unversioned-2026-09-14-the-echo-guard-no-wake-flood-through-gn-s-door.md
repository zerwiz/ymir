## runtime · unversioned · 2026-09-14 — The echo guard: no wake flood through Gná's door

### Why
- **Problem:** during a loud stretch (stale wake lines + the FM runner's
  durable queue holding ten old check-wakes), the watcher re-armed and
  re-signalled "signal: wake queue" across many generations; every actionable
  close queued one pi follow-up wake (`sendWake`, no dedup), which then
  dripped at the Allfather one per prompt — a long echo flood after the
  sources were drained.
- **Fix:** `gna-pi-watch.ts` `sendWake` is **echo-guarded**: an identical
  watcher message is delivered at most once per drained state — when both
  durable doors (`state/.wake-queue` and the FM runner's
  `.agents/state/.wake-queue`) are empty, a repeat carry is the same drained
  news and is skipped. Genuine new content (different message, or a door with
  a line) always delivers. Harness asset updated in the same change.

### Files
- *(carried from the frozen CHANGELOG.md)*
