## runtime · unversioned · 2026-09-23 — the turn-end guard reads the operator's state

### Why
- **Problem:** every turn ended with a spurious *"TURN WOULD END BLIND —
  supervision is off"*, even while the watcher was provably alive (heartbeat
  seconds old) and `gna_watch_arm` refused to re-arm because it already owned the
  arm child.
- **Root cause:** `bin/syn-turnend-guard.sh` resolved
  `STATE="${BROKK_STATE_OVERRIDE:-$BROKK_HOME/state}"` — for the primary that is
  the **code tree** (`/home/heimdall/ymir/state`). The live watcher writes its
  `.supervision-armed` marker and `.watch.heartbeat` into the **operator's hoard
  state** (`$YMIR_HOME/state`). Measured at the moment of the false alarm: the
  code-tree heartbeat was **4163 s** stale, the hoard heartbeat **2 s** fresh. The
  guard read the wrong place and declared a healthy watcher dead.
- **Fix:** the guard resolves the operator's state through `bin/hoard-lib.sh`,
  the same order of authority as `syn-watch-arm.sh`, `saga-wake-drain.sh`, and the
  harness readers (`BROKK_STATE_OVERRIDE` → `$YMIR_STATE_DIR` → `$YMIR_HOME/state`
  → the recorded choice → the default). `$BROKK_HOME/state` remains only the last
  fallback for a bare checkout.
- **Impact:** the turn-end guard stops firing blind; the recovery prompt appears
  only when supervision is genuinely off.

### Verified
- Fixed guard: **exit 0** (healthy) against the live hoard heartbeat.
- Old guard at the same instant: **exit 2** (the false alarm).

### Files
- `bin/syn-turnend-guard.sh`
- `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md`
