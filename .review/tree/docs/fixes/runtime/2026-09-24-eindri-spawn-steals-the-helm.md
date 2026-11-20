## runtime · 2026-09-24 — the spawn road stole the primary's helm

### Why
Every worker raised by `bin/einherjar-spawn.sh` **took the helm from the primary**.
pi's session-start writes `brokk.lock` and `.pi-watch-extension-loaded`; a worker that
shares the machine state dir overwrites both, so Brokk's watcher loses the lock it lives
by and dies — reporting only *"cannot restore continuity because this session no longer
owns the lock"*. Observed **three times in one afternoon**: after each spawn the lock was
gone, the arm children count fell to 0, and the heartbeat stopped.

`bin/herdr-run.sh:211` and `bin/pi-seat.sh:66` already solved this — they pass
`--env BROKK_MACHINE_STATE_DIR=<seat dir> --env BROKK_STATE_OVERRIDE=<seat dir>` when the
pane/tab is CREATED, which is why their seats (`~/.local/state/ymir/seats/kvasir`,
`sindri-arm`, …) each hold their own `brokk.lock`. `einherjar-spawn.sh` launched through a
bare `herdr workspace create` and passed neither, so its workers contended for the single
machine lock — the exact defect plan 45 named and PR #124 fixed on the other roads.

The first attempt at a fix prefixed the pane command (`VAR=x cmd`) and **did not work**:
the seat dir was created and stayed empty. Proven live instead that
`herdr workspace create --env KEY=VALUE` sets *"an environment variable for the launched
process"*:

```
herdr workspace create --env BROKK_MACHINE_STATE_DIR=/tmp/envtest-probe ...
  → the pane reported  SEATENV=[/tmp/envtest-probe]   (its own environment)
```

### What
- `bin/einherjar-spawn.sh` `launch_herdr()` passes the seat's own machine state on
  workspace create, using the convention the other roads already use —
  `${XDG_STATE_HOME:-$HOME/.local/state}/ymir/seats/<id>`.
- The same assignment also prefixes the pane command on the tmux backend, where there is no
  `--env` flag to pass.
- Seeded by a local workaround on heimdall (2026-09-24) that kept the primary reachable
  through four further dispatches; this is that mend, properly.

### Verified
- `bash -n` clean.
- `herdr workspace create --env` proven to place the variable in the pane's own environment
  (live probe, above), so a worker writes its lock in its own seat dir.
- A dispatch after the change leaves `brokk.lock` owned by the primary with the watcher
  beating.

### Files
- `bin/einherjar-spawn.sh`
