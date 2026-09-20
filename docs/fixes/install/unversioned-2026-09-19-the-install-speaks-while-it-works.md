## install · unversioned · 2026-09-19 — the install speaks while it works

### Why
- Progress renders two ways, both proven: a terminal rewrites one line in place
  (`[ 3/19] apps … → [ 3/19] apps — 12s`), a pipe or a log gets one plain line each with
  no escapes. Verified by running the real function against dummy steps and counting the
  clear-line escapes when piped: 0.

- After the user accepts with `y`, the installer says how many steps follow, then each
  step announces itself (`[ 3/19] apps …`) and reports its elapsed time. Silence during a
  minutes-long step read as a hang: "the user don't know if something are happening".
- Progress goes to **stderr**, so the TOON report on stdout stays clean for anything that
  parses it. Without a terminal the lines are printed whole instead of rewritten in place.

### Files
- `(see the body)`
