## runtime · unversioned · 2026-09-22 — the wake-flood brake (one signal per distinct content)

### Why
An unconsumed wake queue re-injected the identical signal on every poll cycle
(5s) — the 2026-09-22 flood (60+ identical follow-ups). The extension's dedupe
quits when the queue stays fresh, so the source itself must gate.

### What
`bin/syn-watch-arm.sh` emits `signal: wake queue` at most once per DISTINCT
queue content (md5sum cached in `state/.wake-last-hash`). New content → one
new signal; unchanged queue → silence until the agent drains
(`saga-wake-drain.sh`) or the content changes. Verified: 1 signal across 10
polls, 0 across 25 more.

### Files
- `bin/syn-watch-arm.sh`
