## runtime · unversioned · 2026-09-14 — A vacant helm is entered, not punted (watcher wake repair)

### Why
- **Problem:** a watcher wake reported the Pi extension could not restore
  continuity — "this session no longer owns the lock". Root cause found by
  inspection: an **empty/truncated** machine lock (`~/.local/state/ymir/brokk.lock`)
  was classified by `gna-pi-watch.ts` `lockOwnership()` as `other` (another
  live session) and by `bin/syn-watch-arm.sh`'s gate as read-only — so a helm
  with *no verifiably-live holder* was refused and punted to a manual
  `saga-session-start.sh` reclaim.
- **Fix (both seams in one change):** the extension now classifies an empty
  lock as `missing`, so `gna_watch_arm`'s reclaim takes the helm in place; the
  arm script, on finding no owner (or an owner verifiably gone), runs
  `gleipnir_lock_acquire` itself — which refuses only a genuinely live other
  session — instead of printing read-only. The "run saga-session-start.sh"
  punt is gone; a vacant helm is entered by the watcher's own hand.
- **Verified:** scratch-state test — empty machine lock → `watcher: started`,
  lock bound to the session pid + starttime sidecar, `.supervision-armed`
  touched; `gleipnir-machine-lock.test.sh` ALL PASS (zombie, recycled,
  migration); compliance 10/10; harness-integration asset updated in the same
  change (the governed rule).

### Files
- *(carried from the frozen CHANGELOG.md)*
