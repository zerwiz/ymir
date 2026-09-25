## hoard · unversioned · 2026-09-25 — the operator's state in the code tree: a fallback repeated four times

### Why
The plan's phase-1 `purity` row named it: the operator's own things sat in the code
tree (`state/`), where the next upgrade would erase them. It was not one bug. It was
one fallback pattern, repeated.

- **Four writers fell back to `$ROOT/state`** whenever the home failed to resolve:
  `bin/nidhogg.sh`, `bin/research-round.sh` and `bin/ymir-update-check.sh` each
  ended their resolution with `${...:-$ROOT/state}`, and `scripts/electron.sh` both
  mkdir'd the tree's state and wrote its pid and log files there
  (`pid_file`/`log_file`). All four now **resolve-or-refuse**: the home resolves via
  `bin/hoard-lib.sh`, and a failure to resolve is said out loud rather than written
  into the tree. A silent write is how drift becomes history.
- **Three neighbours were correct and were left alone:** `bin/autoboot-lib.sh`,
  `bin/topology.sh` and `bin/fleet-ensure.sh` resolve `$YMIR_HOME/state` through
  their home root, not the tree.
- **One reader is the detector and must not change:** `bin/ymir-plan.sh` reads
  `$ROOT/state` on purpose — it is the `purity` row. Changing it would hide the very
  drift it exists to show.
- **Fifteen drift artifacts were cleared** from the tree: `cron.log`, `observer.log`,
  `observer.last`, the electron logs and pid files, `runes.lock`, `backups/`, the
  `pre-pull` and `pre-update` notes, `.cron-fired`, `.cron-locks`. Duplicates of the
  home's copy were removed; the rest were moved into the home. (`mv -n` was tried
  first and lied: it skips an existing target and still returns success, so every
  file appeared moved while none had.)
- **Two markers remain, and are named rather than moved:** `.lock-path` and
  `.session-start-complete` belong to the session lease, and a ward refuses a
  hand-edit of the lock outright. The `purity` row stays red until their WRITER
  resolves the home, which is a session-start/lease change and not a hoard one.

galdr-reread: `installation.md` (Rule 04; the `purity` row: never write `$ROOT/state`).

### Files
- `bin/nidhogg.sh`
- `bin/research-round.sh`
- `bin/ymir-update-check.sh`
- `scripts/electron.sh`
