## agents · unversioned · 2026-09-22 — the version stamp: a seat names its build

### Why
The install audit found the package lane drifting (0.1.24 vs 0.1.39) with no
way for a seat to name what it runs. One truth: repo `main` + the package tag.

### What
`bin/version-stamp.sh` — prints `ymir-<git describe>[@<pkg>]` (or `--json`), so
Brokk and any seat can say exactly which build stands there. Dev seats run
source (the stale global pkg is removed); the npm package stays the
container-era artifact.

### Files
- `bin/version-stamp.sh`
