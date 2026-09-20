## agents · unversioned · 2026-09-13 — Gleipnir sees when an agent is turned off

### Why
- **Problem:** the machine lock stuck “held by another Brokk session” forever.
  Nothing released it ( `gleipnir_lock_release` had zero callers; Pi's exit
  hook only stopped the arm child), and liveness was `kill(0)` alone — which
  reports a zombie (dead but unreaped) and a recycled pid as alive, so an
  agent you turned off kept the helm until its pid happened to look gone.
  Worse, the Sessrúmnir desktop RPC session holds the live lock yet never
  arms supervision (no turn ever calls `gna_watch_arm`), stranding every
  other session read-only.
- **Fix:** `bin/gleipnir-lock-lib.sh` now records the owner's starttime in a
  `brokk.lock.starttime` sidecar and reaps a holder whose `/proc/<pid>/stat`
  state is `Z`/`X` or whose starttime no longer matches (pid reuse) — dead,
  zombie, and recycled holders are cleared at session start/acquire. Gná
  (`gna-pi-watch.ts`) mirrors that liveness, reclaims a stale lock directly in
  `gna_watch_arm` (`missing` no longer punts to saga-session-start.sh), and
  drops its own lock on real process exit (`releaseLockIfOwned`); the turn-end
  guard (`syn-turnend-guard.ts`) uses the same zombie-aware check.
- **Impact:** turning an agent off — cleanly, by kill (zombie), or after pid
  reuse — frees the machine lock for the next session. The live desktop seat
  still holds it until that app is closed or its own session arms; that is the
  law (on

### Files
- *(carried from the frozen CHANGELOG.md)*
