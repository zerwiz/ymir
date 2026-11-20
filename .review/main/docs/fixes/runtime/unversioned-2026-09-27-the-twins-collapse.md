## runtime · unversioned · 2026-09-27 — the port twins collapse: one name, one behaviour (plan 58, Phase 5)

### Why
The Firstmate port was **duplicated, not adapted**. Four supervision libraries
stood twice — `bin/brokk-*` and `.agents/backend/fm-*` — drifting apart by hand:
classify **262** diff-lines, wake **384**, lease **110**, wake-grant **24**. A
change to the supervision protocol had to be made twice, and the two copies had
already diverged in ways that matter: the vendored lease lib read the legacy
`state/.lock` instead of the resolved `state/.lock-path` (the Phase 0 fix), the
vendored wake-grant wrote `fm-branch-eligible-owner-v1` where the Pi branch
extension reads `brokk-branch-eligible-owner-v1`, and the native
`bin/brokk-classify-lib.sh` sourced a `bin/brokk-timeout-lib.sh` that **did not
exist**, so the classifier's bounded worktree probe had no `fm_run_timed`. This
is plan 58 Phase 5: the twins delete, the doors stay, the extension ABI is
untouched.

### What
**The native side is the one implementation; the vendored name is a thin
adapter.** The plan's own shape — "`brokk-*` and `fm-*` become thin adapters over
it, or one alias table":

```
one_library[5]{native,adapter,evidence_for_native}
  "bin/brokk-classify-lib.sh",".agents/backend/fm-classify-lib.sh","native verbs are Allfather-named; the vendored default crew-state door (brokk-crew-state.sh) does not exist"
  "bin/brokk-wake-lib.sh",".agents/backend/fm-wake-lib.sh","native calls bin/hamr-harness.sh and names the stall markers eindri-home"
  "bin/brokk-lease-lib.sh",".agents/backend/fm-lease-lib.sh","native carries the resolved state/.lock-path read (Phase 0)"
  "bin/brokk-timeout-lib.sh",".agents/backend/fm-timeout-lib.sh","the native file is the one that exists; the vendored classify's bin/brokk-timeout-lib.sh was missing"
  "bin/brokk-wake-grant.sh",".agents/backend/fm-wake-grant.sh","native writes brokk-branch-eligible-owner-v1, the marker the Pi branch extension reads"
```

- **`bin/brokk-timeout-lib.sh` (new, the missing leg).** The bounded-execution
  owner is ported from `fm-timeout-lib.sh` (`fm_timeout_mechanism` ·
  `fm_run_timed` · the perl/bash/external fallbacks). It is the file
  `bin/brokk-classify-lib.sh` already sourced; the classifier's worktree-write
  probe is whole again.
- **`.agents/backend/fm-{classify,wake,lease,timeout}-lib.sh` and `fm-wake-grant.sh`
  are now thin adapters.** Each maps the upstream `FM_*` env dialect onto the
  native `BROKK_*` names (the upstream caller's own word is final) and sources
  the one library. They define **no behaviour**; a body added to one is the
  second implementation this change exists to end. The upstream verb names
  (`status_is_captain_*`, `fm_wake_secondmate_stall_*`) were repointed onto the
  native names in the vendored callers in the same change, so no translator body
  and no imported name is left in the adapters. `fm-wake-grant.sh` is the same
  shape over the native door, with `exec` so no wrapper process is left behind.
- **The island's own resolution is preserved.** When a caller set no `FM_`
  location the vendored wake library resolved root = `.agents/`; the adapter
  keeps exactly that default, so a bare island caller reads where it read before.
  An explicit `FM_STATE_OVERRIDE` (what `bin/eindri-watch.sh` exports) still
  wins.
- **The vendored lease door** (`fm-lease.sh`) reads the one library's
  `BROKK_LEASE_*` names, since the lease contract's variables are the native ones.

### What is NOT touched (the ABI is the point)
- No `bin/` **door** changed: `bin/brokk-lease.sh`, `bin/brokk-wake-grant.sh`,
  `bin/skuld-branch-outcome.sh`, the Pi extension's two calls, and the arm's
  `signal:/stale:/check:/heartbeat:` grammar all resolve the same tools.
- The live vendored route — `bin/eindri-watch.sh` →
  `.agents/backend/fm-procevent-when.sh` / `fm-procevent.sh` — loads cleanly and
  reports the same sources and the same state as before.
- `bin/README.md` gains the new file and its declared count is corrected
  (101 → 103, the block had held one more row than it declared).

### The proofs (run, not asserted)
- `python3 -m unittest discover -s src/ymir_runtime/tests` and the repo-root
  hinge — **103 tests, OK**.
- `bash -n` over every touched file **and** a full sweep of `bin/*.sh` +
  `.agents/backend/*.sh` — clean.
- Load parity: the native classifier loads with no missing-sibling error and
  `fm_run_timed` defined; the fm adapter sources the one library and
  `status_is_Allfather_relevant` answers; a bare island caller resolves
  `state = .agents/state` exactly as the original did (probed against `git stash`
  of the same tree).
- Live parity: `bin/eindri-watch.sh list` and `fm-procevent.sh list` produce the
  same output before and after; `fm-wake-grant.sh` reaches the native door.
- `bin/guards.sh` — PASS · compliance-check **15/15 PASS**.

### What remains (one god per PR — said plainly)
`fm-spawn`/`fm-teardown`/`fm-watch` still stand as gods in the vendored runtime.
`fm-spawn`'s seat road is owned by `src/ymir_runtime/` (Phase 1) for the herdr
route, but the **Utgard sandbox** still rides `bin/einherjar-spawn.sh` until
`container.py` owns it. `fm-teardown` (landed-work gates, PR lookups, backlog
transitions) and `fm-watch` (the watcher) are not owned by the engine yet. Those
are the next errands; this one shipped the twins.

### Files
- `bin/brokk-timeout-lib.sh` (new)
- `.agents/backend/fm-classify-lib.sh` · `fm-wake-lib.sh` · `fm-lease-lib.sh` ·
  `fm-timeout-lib.sh` · `fm-wake-grant.sh` · `fm-lease.sh` (adapters)
- `.agents/backend/fm-push-transition-lib.sh` · `fm-supervise-daemon.sh` ·
  `fm-watch.sh` · `fm-wake-drain.sh` (upstream verb names repointed onto the one library)
- `.agents/tests/fm-classify-corr-token.test.sh` · `fm-daemon.test.sh` ·
  `fm-watch-triage.test.sh` (their verb and `BROKK_ALLFATHER_RE` names follow the one library; the
  suite is separately stale — it still sources `bin/fm-*.sh`, a larger cleanup)
- `bin/README.md` · `.agents/backend/README.md` ·
  `.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md`
