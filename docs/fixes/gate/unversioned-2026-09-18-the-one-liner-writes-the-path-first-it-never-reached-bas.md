## gate · unversioned · 2026-09-18 — the one-liner writes the PATH first (it never reached .bashrc)

### Why
- **The bug, exactly:** install.sh passed `"${@:-}"` to npm, which with no arguments is an
  EMPTY argument — npm errored, and the script exited **before** the PATH block. So the
  command was never added to .bashrc, on any machine without it already.
- **The order is now right:** the PATH is written into the shell files FIRST, then the
  package is installed with a proper argument array — so a failed install still leaves
  the command reachable, and a second run picks up where the first left off.

> **Frozen 2026-09-18.** This file is the historical record and is no longer
> written to (Rule 06: a record is never rewritten). New work is recorded as fix
> notes — one file per fix, per component — under `docs/fixes/`, written with
> `bin/fixes.sh record` and guarded by `bin/fixes-guard.sh`.

### Files
- `bin/fixes-guard.sh`
