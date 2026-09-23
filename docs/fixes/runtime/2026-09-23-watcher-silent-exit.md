## runtime · unversioned · 2026-09-23 — the watcher must not exit silently on an unchanged queue

### Why
- **Problem:** Supervision flapped. The watcher would not stay armed: it exited
  within a second, the Pi extension classified the close as
  `watcher: FAILED - arm cycle ended without an actionable reason`, retried five
  times, and gave up. `gna_watch_arm` had to be called again and again.
- **Root cause:** in `bin/syn-watch-arm.sh`, `actionable()` treated a **non-empty
  but unchanged** wake queue as actionable *and returned success without printing
  anything*:
  ```sh
  if [ -s "$STATE/.wake-queue" ]; then
    _h=$(md5sum < "$STATE/.wake-queue" | awk '{print $1}')
    _prev=$(cat "$STATE/.wake-last-hash" 2>/dev/null || true)
    if [ "$_prev" != "$_h" ]; then
      printf '%s' "$_h" > "$STATE/.wake-last-hash"
      printf 'signal: wake queue\n'
    fi
    return 0          # <-- exits the loop even when it printed nothing
  fi
  ```
  So a single unacknowledged wake (the 7 session-start wakes sat unacknowledged)
  made every re-armed watcher leave silently, forever. The flood-brake's intent —
  "an unchanged queue stays silent" — was defeated by the `return 0`.
- **Fix:** an unchanged, unconsumed queue was already signalled once: **stay
  silent and keep watching** (`return 1`), never exit. A *changed* queue still
  raises exactly one `signal: wake queue` and exits, so the flood brake holds.
- **Impact:** the watcher stays armed through an unacknowledged queue, so
  supervision no longer flaps and the turn-end guard stops firing blind.

### Files
- `bin/syn-watch-arm.sh`
- `.agents/tests/syn-watch-arm-silent-exit.test.sh` — regression: an unchanged
  queue keeps the watcher alive (it must not exit); a changed queue signals once
  and exits.
