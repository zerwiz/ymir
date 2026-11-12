## engine · unversioned · 2026-11-12 — every service and app runs from the pinned runtime, from the first install, through one register and one writer

### Why

A collaborator's pre-push ward `runtime-pinned` refused his push because `garmr-brain.service` and
`gna-desk.service` ran straight from his working tree. Four holes let that happen (plan 269):

- `bin/engine/ymir-install.sh` never seated the pin. A fresh install had no `~/ymir-runtime` and no
  `config/runtime.env`, so every service ran from the tree it was installed from.
- Gróa skipped an update with "no pinned runtime configured", so the hole was never closed.
- `runtime-deploy.sh` restarted a fixed list of ten units. `gna-desk` was not on it.
- Unit and launcher writers used the tree they ran from: mail (`WorkingDirectory=$ROOT`), the seven forge
  watchers, and Bilskirnir's launcher, which on 2026-11-12 pointed into an errand worktree.

### What changed

- **One register.** `config/units.yaml` lists every Ymir systemd user unit, each as `render` (the register
  describes the whole unit) or `adopt` (another installer writes it; the writer only moves its paths). No
  machine path is in it. Desktop launchers and an app's own unit templates are discovered from
  `apps/*/{electron,resources}/*.{desktop,service}.in`, so a new app joins by shipping its template.
- **One resolver.** `runtime_pin_dir()` (`src/ymir_runtime/paths.py`) and `arm_pin_dir`
  (`bin/pi/arm-pin-lib.sh`) gain the one documented default `~/ymir-runtime`, used once install has seated a
  checkout there. `identity.py` now imports the default instead of stating it a second time.
- **One writer.** `bin/engine/units.sh write|check|list` renders every unit and launcher against the pin,
  writes only what changed, reloads systemd, restarts a changed unit that was running, and logs every
  replaced line to `<state>/units-replaced.log`. Mail, `issue-watch`, `queue-warden`, `review-watch`,
  `ship-watch`, `pr-watch`, `review-seat` and `review-shelf` keep their entry points and call it.
  Bilskirnir's setup and `desktop-place.sh` render launchers against the pin. Rödd's templates and her
  `--install-unit` are unchanged.
- **Install seats the pin.** New install steps `runtime` (clone `~/ymir-runtime` from origin/main, record
  `runtime.env`, write the units) and `units` (a late sweep, because steps in between write units of their
  own). `bin/engine/runtime-seat.sh` is the idempotent door both use.
- **Gróa seats a missing pin** through the same door instead of skipping, and sweeps the units on every
  update.
- **`runtime-deploy.sh` restarts the units the register owes** (timers included), not a fixed list.
  `YMIR_RUNTIME_UNITS` stays as an override. `--no-restart` fetches and moves the pin only.
- **Eir's `runtimepin` surface** fails when any Ymir unit or launcher is off the pin or not in the register;
  `fix` runs the seat door.

### What was not changed, on purpose

- `apps/sessrumnir/src/main/autostart-linux.ts` writes the autostart entry with the running app's own
  path (`$APPIMAGE` or the packaged binary), not a tree. Nothing to move.
- `apps/smidja-factory/apps/visualizer/desktop/main.js` uses `__dirname` for its icon and preload only;
  it writes no unit. `apps/hvergelmir` ships server deploy units, not seat units.
- `groa-agent.service` keeps `YMIR_REPO` on the working tree: that is the checkout Gróa fast-forwards.
  The register marks it `keep: [YMIR_REPO]`.
- A drop-in that deliberately names a tree (this seat has a temporary one for the well) is reported by
  `units.sh check` as off the pin until its owner removes it. The writer never edits it away silently.

### Proof

- `bin/engine/tests/test_units.sh` (44 checks, temp HOME, fake systemd directory, no real unit touched):
  a fresh seat leaves every unit and all six launchers on the pin; the seat is idempotent and never
  rewrites an operator's `runtime.env` line; a planted unit on a working tree is found and rewritten with
  its old line logged, in absolute and `%h` form; a launcher pointing into a worktree is rewritten; a unit
  written by code in a worktree names the pin; a new app joins by its template alone.
- `src/ymir_runtime/tests/test_paths.py` covers the default and its refusal to name an unseated path.
- Known failures that predate this change and are not touched by it: `bin/gates/tests/test_queue_warden.sh`
  computes its root one level too high, and two checks in `bin/voice/tests/test_rodd_pin.sh` grep strings
  that `apps/rodd/src/main.js` no longer carries.

### Files

- `config/units.yaml`
- `bin/engine/units.sh`
- `bin/engine/units.py`
- `bin/engine/runtime-seat.sh`
- `bin/engine/runtime-deploy.sh`
- `bin/engine/ymir-install.sh`
- `bin/engine/tests/test_units.sh`
- `bin/agents/groa-update.sh`
- `bin/agents/eir-doctor.sh`
- `bin/mail/install.sh`
- `bin/forge/issue-watch.sh`
- `bin/forge/queue-warden.sh`
- `bin/forge/review-watch.sh`
- `bin/forge/ship-watch.sh`
- `bin/forge/pr-watch.sh`
- `bin/forge/review-seat.sh`
- `bin/forge/review-shelf.sh`
- `apps/bilskirnir/setup.sh`
- `bin/desktop/desktop-place.sh`
- `bin/pi/arm-pin-lib.sh`
- `src/ymir_runtime/paths.py`
- `src/ymir_runtime/identity.py`
- `src/ymir_runtime/tests/test_paths.py`
