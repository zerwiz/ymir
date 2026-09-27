## runtime · unversioned · 2026-09-26 — ci-verify prints the failing gate's own tail

### Why
`bin/ci-verify.sh`'s `gate()` swallowed a failing gate's whole output and
printed only `tail -1 | cut -c1-88` — one line, itself truncated. When
`pr-pretest` failed in CI (the pre-existing electron/install wall), the CI log
showed only `"pr-pretest","FAIL",… PRETEST FAIL` with **no row naming which
check died** — the hull, the sandbox install, or an app-boot surface. Diagnosis
was guessing.

### What
On a gate failure, `gate()` now prints the gate's own output (last 12
non-empty lines, indented) beside the FAIL row. The next red CI run tells us
the actual dying step by name.

### Files
- `bin/ci-verify.sh`