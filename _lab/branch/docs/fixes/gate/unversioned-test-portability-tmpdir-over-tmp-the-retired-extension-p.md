## gate · unversioned · 2026-10-17 — test portability: TMPDIR over /tmp, the retired extension path, and a seed_repo that made no dirs

### Why
Hardcoded /tmp is unwritable on Termux; ymirhome-door pointed at the retired .pi/shared/extensions/; seed_repo never created its nested dirs.

### Files
- `.agents/tests/verify-seat.test.sh`
- `.agents/tests/ymirhome-door.test.sh`
- `.agents/tests/defaults-guard-seat-paths.test.sh`
- `.agents/tests/install-role-gate.test.sh`
- `bin/forge/npm/npm-pretest.sh`
- `bin/forge/npm/npm-install-local-test.sh`