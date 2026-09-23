## install · unversioned · 2026-09-23 — the pre-publish gate can run on its own remote seat

### Why
`bin/npm-pretest.sh` is the Allfather's decree: the exact tarball a publish would
ship must **install and smoke on this seat AND on a remote seat** before the shelf
sees it. It defaulted that remote to `heimdall` — and on heimdall itself the leg
died:

```
== the remote leg: heimdall ==
FAIL: cannot reach heimdall
PRETEST FAIL
```

The "remote" **was this machine**. `ssh heimdall` from heimdall needs a
`known_hosts` entry and an alias, and neither exists — a loopback ssh with no road
to travel. So the gate failed on the very seat it was packed on, and a publish
that would have been safe looked unsafe.

### Fix
- **`bin/npm-pretest.sh`** — when `$REMOTE` equals this machine's hostname (full
  or short), the remote leg runs **locally**: the same sandbox install and the
  same smoke, with no ssh. The artifact under test is identical, and the leg's
  purpose — prove the hull installs somewhere other than where it was packed — is
  still served when the pack seat and the install seat are the same box.
- **`NPM_PRETEST_HOSTS`** — the remote leg now tests **every seat in a list**
  (default `omarchy whynot`), not one. The decree is that the tarball installs and
  smokes on the seats — plural — before the shelf sees it; a single default seat
  checked only wherever the pack happened to run. `NPM_PRETEST_HOST` remains for
  one seat.
- A genuine other seat still takes the ssh road unchanged.

### Verification
- `bash -n` clean.
- **`PRETEST PASS`, every leg green:**
  - **heimdall** (this seat) — `heimdall is this machine — running the leg locally
    (no loopback ssh)`: 171 bin tools, `ymir.js --version` answers, the `.agents`
    dotfolders ship, 5 fleet servers in the installed tree.
  - **omarchy** — `REMOTE_PASS`
  - **whynot** — `REMOTE_PASS`

### Files
- `bin/npm-pretest.sh`
