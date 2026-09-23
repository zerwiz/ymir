## runtime · unversioned · 2026-09-23 — the mid-session sweep: a filed report no longer waits for the next session

### Why
The handoff failsafe (`bin/eindri-handoff.sh`) ran in exactly one place: the
**session start** digest. So a report filed *while a session was running* sat
undelivered until the **next** session — a worker finished and Brokk was never
told. That is the same failure as the original one, one layer in: the sweep
existed but had no mid-session beat.

### Fix
- **`bin/syn-watch-arm.sh`** — the watcher's poll loop now runs
  `eindri-handoff.sh sweep` **every cycle** (before its `actionable` check), so a
  filed report or question becomes a wake within seconds of landing. The watcher
  is already the only thing polling during a session, so it is the natural beat;
  no new timer, no new process.
- The sweep is idempotent (one delivery marker per item), so running it every
  cycle never re-fires old news.

### The honest boundary
This fix, like the extension fix, is **not live in the current session**:

```
worktree bin/syn-watch-arm.sh : 3 refs to eindri-handoff.sh   ← the fix
main     bin/syn-watch-arm.sh : 0 refs                        ← what runs
```

The extension spawns `${fmRoot}/bin/syn-watch-arm.sh` — the **main tree's** copy —
so the sweep is live only after the merge lands and pi restarts with the fixed
extension. A running session keeps both the extension and the watcher script it
started with.

**A live background test was refused, correctly:** `syn-watch-arm.sh` cannot be
backgrounded by hand ("do not background the Brokk watcher arm; the extension
owns continuity"). So the end-to-end proof must wait for a session that carries
the fix — which is the point of the change.

### Verification
- `bash -n` clean.
- The sweep itself is proven to find and deliver a filed report
  (`eindri-handoff.sh status` → `"REPORT","probe",…`), and to be idempotent
  (a second sweep reads 0).
- The call sits inside the watcher loop, immediately before `actionable`.

### Files
- `bin/syn-watch-arm.sh`
