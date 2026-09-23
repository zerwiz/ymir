## agents · unversioned · 2026-09-23 — the seat arms its own handoff

### Why
- **Every seat road except `bin/eindri-dispatch.sh` finished a worker into silence.**
  `bin/eindri-dispatch.sh` was the only script that called
  `bin/eindri-watch.sh arm "$NAME" "$SEAT_CWD"` after starting the agent.
  `bin/herdr-run.sh` and `bin/pi-seat.sh` started the agent, injected the task,
  and returned — the worker completed, but Brokk never knew. The coordinator had
  to poll by hand or wait for the session to end. Plan 42 built the arm
  infrastructure (`eindri-watch.sh`, `eindri-seen.sh`, `eindri-acclaim.sh`) but
  left it un-armed on the two seat roads.

### Fix
- **`bin/herdr-run.sh`** — after the inject loop (which retries up to 10 times
  until the prompt lands), calls
  `bin/eindri-watch.sh arm "$NAME" "$SEAT_CWD"` to register the when-source.
  `$SEAT_CWD` resolves to the Yggdrasil worktree path (when isolation is active)
  or `$PWD` (when `--main` is set). The arm sits after `hdr agent start` and
  the inject loop, never before.
- **`bin/pi-seat.sh`** — after the optional task injection
  (`[ -n "$TASK" ] && herdr agent prompt`), calls
  `bin/eindri-watch.sh arm "$NAME" "$DIR"` to register the when-source.
  `$DIR` resolves to the Yggdrasil worktree path (when isolation is active)
  or `$PWD` (when `--main` is set). The arm sits after `herdr agent start` and
  the task prompt, never before.

Components touched: `bin/herdr-run.sh` `bin/pi-seat.sh`

### Files
- `bin/herdr-run.sh`
- `bin/pi-seat.sh`
