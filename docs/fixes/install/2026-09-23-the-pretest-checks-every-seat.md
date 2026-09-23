## install · unversioned · 2026-09-23 — the pretest checks every seat, not one

### Why
The Allfather's decree: the exact tarball a publish would ship must **install and
smoke on the seats** before the shelf sees it. The gate honoured the *local* seat
and one remote — defaulting to `heimdall`, which was the seat the pack ran on, so
the leg had no road (`ssh heimdall` from heimdall: no `known_hosts`, no alias).
A one-host default also checked only wherever the pack happened to run, never the
fleet.

### Fix
- **`NPM_PRETEST_HOSTS`** — a **list** of remote seats (default
  `omarchy whynot`); the leg runs once per seat. A seat that IS this machine runs
  its leg **locally** (same sandbox install, same smoke, no loopback ssh).
- **`NPM_PRETEST_HOST`** — kept for a single seat (back-compat).
- The help text now names the real default instead of `heimdall`.

### Verification
**`PRETEST PASS`, every leg green:**

| Seat | Result |
|---|---|
| **heimdall** (this seat) | local leg — 171 bin tools, `ymir.js --version` answers, the `.agents` dotfolders ship, 5 fleet servers in the installed tree |
| **omarchy** | `REMOTE_PASS` |
| **whynot** | `REMOTE_PASS` |

`bash -n` clean. Compliance 15/15.

### Files
- `bin/npm-pretest.sh`
