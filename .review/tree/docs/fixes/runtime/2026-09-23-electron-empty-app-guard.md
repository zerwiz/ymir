## runtime · unversioned · 2026-09-23 — the electron empty-app guard (the SIGTRAP crash)

### Why
On heimdall the Sessrúmnir window died with **SIGTRAP (int3)** 75 s after the
install's desktop step raised it. The core's own command line was the verdict:
the app path reached electron MALFORMED (`…/apps/sessrumnir s/sessrumnir`) and
the app abort-checked. The root: the app resolution can return EMPTY
(`app_dir sessrumnir` resolved "" on that seat) and nothing stopped the launch.

### What
Resolve-or-die guards in both launchers: an empty/unresolvable app path now
prints a clear error + the mend (npm ci) and exits — **electron is never
launched with an empty or concatenated path again**.
- `scripts/electron.sh` — the guard after the app resolution.
- `bin/sessrumnir.sh` — the guard before the launch.

### Files
- `scripts/electron.sh` · `bin/sessrumnir.sh`
