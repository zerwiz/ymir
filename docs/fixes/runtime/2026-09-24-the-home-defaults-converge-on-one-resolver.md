## runtime · unversioned · 2026-09-24 — the home defaults converge on the one resolver

### Why
Nine scripts once carried their own home default, and a tenth was found a week later only by
reading. Hand-convergence does not hold. Lock 3 (`bin/defaults-guard.sh`) found **45 sites**, so
the convergence was done as a reviewed transform with a dry run, not by hand and not by blind sed.

### What
- **28 files** had the private default replaced with the one resolver.
- **11 files** had the resolver block inserted, because they *used* the home without resolving it.
- **6 files** needed judgement rather than a pattern:
  - the two migrations keep the old home name on purpose, so they carry a **written waiver** on
    the line: naming the old name is the point of the migration;
  - the macOS bootstrap keeps a guest default under a waiver, because a fresh guest has no
    recorded choice yet and that bootstrap seeds it;
  - `bin/npm-install-local-test.sh` **recognizes** another seat's path shape; it does not guess one;
  - the embedded Python in `bin/einherjar-spawn.sh` now resolves `env → the recorded choice → a
    loud failure` instead of guessing, and the Node plugin
    (`syn-watch-arm.js`) now **throws rather than assuming a home**.

### Two regressions this change caused, and how they were caught
Both were found by verification, not by luck, and both are recorded because the route matters:

1. **A self-assignment.** The transform turned `YMIR_HOME="${YMIR_HOME:-…}"` into
   `YMIR_HOME="${YMIR_HOME}"`, which under `set -u` is an unbound variable. Ten scripts were left
   unable to run, including Eir, the healer. The no-op is now deleted and the block required.
2. **A substring standing in for a fact.** The "already resolved" test looked for `hoard-lib.sh`,
   which appears in comments, so it skipped the block exactly where it was needed. That is the same
   mistake this whole exercise is about, and it is why the check now looks for a **call**.

### The lock gained its second class
**The literal rule is structurally blind to the interesting case.** A file can be entirely free of a
default and still not know where anything is, which is precisely how ten scripts were converged and
left unable to run. `bin/defaults-guard.sh` now also refuses a shell script that **uses the home and
never resolves it**, exempting a deliberate assignment and honouring a written waiver. On its first
run it found **11 more**, pre-existing and invisible to the literal rule.

### Verified
- `defaults-guard check`: **0 defaults, 0 unresolved**.
- `bash -n` across every changed shell file: clean.
- The repaired scripts run: Eir, groa-update, mimir-bridge, hodd, daily-log.
- **All 15 governance gates PASS**, including `assets` (the three governed assets were updated in
  this same change, which is the rule the gate exists to enforce) and `config` (Rule 07).

### Files
- `bin/converge-home-defaults.py` (the reviewed transform, kept)
- `bin/defaults-guard.sh` (the second class)
- the 39 converged files
- `.agents/skills/galdr-ymirsystem/assets/{installation,memory-well,nornir-jobs}.md`
