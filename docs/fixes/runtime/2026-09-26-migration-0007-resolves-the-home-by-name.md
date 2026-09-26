## runtime · unversioned · 2026-09-26 — migration 0007 calls the home resolver by name

### Why
The `defaults-guard` ward's second class — "uses the home, never resolves it" —
greps the tree for `ymir_home_root` being **called** in a file that mentions the
home. `.agents/migrations/0007-one-state-dir.sh` resolved the operator state
through `hoard_state_dir` (which calls `ymir_home_root` internally) but never
named the call itself, so the ward flagged it and CI's `gates` stood red on any
branch carrying the migration.

### What
`0007-one-state-dir.sh` now calls `ymir_home_root YMIR_HOME_ROOT` explicitly
(guard-idiomatic: env → recorded choice → the one default), beside the existing
`hoard_state_dir HOARD_STATE` resolution. No behaviour change — the migration
already resolved the home; now the ward can see the call.

### Files
- `.agents/migrations/0007-one-state-dir.sh`