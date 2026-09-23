## install · 2026-09-23 — the npm publish is a staging door: read-path lag, staged-version conflicts, and the nested node_modules bloat

### Why
Three faults met in one release (0.1.50 → 0.1.52), each able to drown a publish:

- **The registry PUT is a staging door, and an interrupted client leaves a staged version
  that blocks republishing.** A publish whose client is killed after the registry accepted
  the write leaves the version in a "previously staged" state: invisible in every read,
  yet `PUT` answers `409 Cannot publish over previously staged version "<v>"`. This is the
  same drowning class as 0.1.38 (staged by an interrupted publish and never republished);
  it is *not* the rare tombstone — it repeats whenever a publish is cut mid-flight.
  The house remedy is proven in history: **bump forward** and sail the next number.
- **The read path lags the write path badly.** After a successful `PUT 202 Accepted`,
  `npm view` and even a fresh curl of the packument kept serving the old `latest` for
  several minutes; the newest version surfaced only later (0.1.51's commit appeared in
  `time` a full ~10 minutes after its PUT, moments after the next publish's PUT landed).
  A verification that strikes the packument too soon reads "absent", and a "staged"
  conflict read back-to-back invites a wrong tombstone diagnosis. Rule of the hour:
  verification must use a virgin `--cache` dir and the raw packument, and must strike
  again after a settle window before declaring success or failure.
- **The nested visualizer's `node_modules` rode the tarball.** `files[]` excluded
  `apps/*/node_modules/**`, but `apps/smidja-factory/apps/visualizer/node_modules`
  (145 MB) sits two levels deep and slipped past the one-level glob, swelling the
  tarball to 107 MB and shipping the smithy's full dependency tree — a regression of
  the "154 MB → 31 MB" hull discipline.

### Mended
- `package.json` `files[]` gained the nested negation:
  `!apps/smidja-factory/apps/visualizer/node_modules/` and `/**` — the tarball reverts
  to its lean hull.
- The publish flow is understood as expected behaviour, not a fault: `PUT 202` then
  async finalize. The pretest's local leg still gates every sail; verification waits
  out the settle window with a virgin cache.
- Released 0.1.52 (the bump-forward sail) after both earlier numbers were stranded by
  their staging.

### Verify
`bin/npm-pretest.sh` (local leg) packed the exact 0.1.52 tarball, checked the hull
inside it, sandbox-installed it, and smoked the installed essence — PASS.