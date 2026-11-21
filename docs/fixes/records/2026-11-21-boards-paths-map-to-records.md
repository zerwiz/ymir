## records · unversioned · 2026-11-21 — the fixes guard maps `bin/boards/*` to records

### Why
`bin/boards/*` mapped to no component, so a correct records note covered none of the board tools' paths and the guard could only say it could not tell.

### Files
- `bin/gates/guards/fixes-guard.sh`

### What
`path_component` now maps `bin/boards/*` to `records`, where the plan-sync notes already live.
