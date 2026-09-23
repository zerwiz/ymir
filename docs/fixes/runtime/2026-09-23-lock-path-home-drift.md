## runtime · unversioned · 2026-09-23 — the lock pointer must name THIS machine's home

### Why
- **Problem:** Supervision would not arm. `gna_watch_arm` failed with
  `EACCES: permission denied, mkdir '/home/heimdallomarchy/.local/state/ymir'` —
  a path belonging to the box's *previous* install (user `heimdallomarchy`), not
  the current user `heimdall`.
- **Root cause (two defects):**
  1. **Writer and readers disagreed on where `state/.lock-path` lives.**
     `bin/gleipnir-lock-lib.sh` resolved the primary's state to `$BROKK_HOME/state`
     (the code tree), while the Pi extension read `$YMIR_HOME/state` (the hoard)
     and the OpenCode plugin read the tree. So the pointer was written in one
     place and read from another — and the hoard copy, frozen on the old machine,
     was never refreshed.
  2. **The pointer was trusted blindly.** `state/.lock-path` records a
     *machine-local, per-user* path but lives in the **synced** home. A box
     reinstalled under a new username inherits the old pointer; both harness
     readers used it verbatim, so the arm tried to `mkdir` a foreign home.
- **Fix:**
  - `bin/gleipnir-lock-lib.sh` — `gleipnir_state_dir` now resolves the operator's
    **hoard state** via `bin/hoard-lib.sh` for the primary (Rule 04), keeping the
    per-home state for an Eindri-home. Writer and readers now agree.
  - `.pi/shared/extensions/gna-pi-watch.ts` and
    `.agents/harness/opencode/plugins/syn-watch-arm.js` — both resolve the same
    hoard state, and both **validate** the pointer: a path outside the current
    user's home is stale, is ignored, and is healed to the path this machine
    derives (machine-global for the primary, per-home for a seat).
  - `.agents/migrations/0006-lock-path-home-drift.sh` — heals an existing home on
    update; `bin/eir-doctor.sh` (`hoard` surface) diagnoses and mends the drift.
- **Impact:** the arm hits the right home on every seat, whatever the username;
  a stale synced pointer can no longer strand supervision.

### Files
- `bin/gleipnir-lock-lib.sh`
- `.pi/shared/extensions/gna-pi-watch.ts`
- `.agents/harness/opencode/plugins/syn-watch-arm.js`
- `.agents/migrations/0006-lock-path-home-drift.sh`
- `bin/eir-doctor.sh`
- `.agents/tests/gleipnir-machine-lock.test.sh`
- `.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md`
- `bin/npm-install-local-test.sh` — a new gate: pack the real tarball, `npm install -g`
  into the real global prefix, smoke the installed `ymir`, report version drift,
  and restore the previous version (the companion to `bin/npm-pretest.sh`, which
  only sandbox-installs).
