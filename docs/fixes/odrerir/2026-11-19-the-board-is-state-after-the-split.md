## odrerir · 2026-11-19 — the Live Hall's board is written to its state after the split

### Why

Óðrerir left this tree for its own repo. Installed in its own home, its board `livehall.json` is state: the app
contract names `${XDG_STATE_HOME:-~/.local/state}/odrerir`, and each release links `public/` and
`dist/livehall.json` there. Two things in Ymir still assumed the app sat in `apps/odrerir`:

1. **`systems/snotra/services/cron/hall-snapshot.sh`** defaulted its output to
   `$APP_ODRERIR/public/livehall.json`. On a seat without the app — the heart, where the job's `@heart` cron row
   runs — that became `/public/livehall.json`. Measured: `mkdir: cannot create directory '/public'`, the write
   failed, and the script still exited 0.
2. **`bin/engine/release.sh`** seeded the first board "so the hall never opens on a 404" (plan 275 S16) only
   when `apps/odrerir` was inside the release. After the split that gate never fires, so a fresh install opened
   on the saga's sample with `/livehall.json` answering 404.

### The fix

- The snapshot writes the board to the app's state file on the home road, and on a seat where the app is not
  installed. In a tree (a checkout, the legacy road, an npm package) it keeps writing the app's own `public/`
  copy. A failed write is now `exit 1` with an error.
- `release.sh` seeds the same state board when the hall is installed in its home and the board is still empty.

### Proof

- `tests/test_hall_snapshot_board.sh` — absent app, home road, unwritable board: all three hold.
- On the dev machine, after the snapshot, the window's own refresh read `live · 2026-11-19T02:38:41Z`, the saga's
  "Not connected" note was gone, and the board showed 3749 runes carved and the live smiths.

### Still owed

The snapshot's cron row is `@heart`, while the hall installs on the `dev` seats (`install_default: dev`). A dev
seat's board is therefore written once (by the release seed or by hand) and then never refreshed. Which seats
run the job is the operator's schedule, not this fix.
