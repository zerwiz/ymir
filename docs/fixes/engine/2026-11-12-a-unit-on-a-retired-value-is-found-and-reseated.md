## engine · unversioned · 2026-11-12 — a unit still running a value its source retired is found and re-seated

### Why

The mail desk's source moved from port 8490 (the gimle share's port) to 8494. On a dev seat the installed
`gna-desk.service` still ran `--port 8490` after every update, so Eir reported the desk silent on 8494.

The cause is the adopt road in `bin/engine/units.py`. The register entry for `gna-desk` says
`if_present: adopt`, so when a unit file already exists, `units.sh write` only moves its paths onto the pin and
keeps every other argument. Nothing compared an installed unit's arguments with its source (plan 278,
problems 1 and 17).

### What changed

- **The register can name what was retired.** A `render` entry may carry `retired: { VAR: [old values] }`.
  `gna-desk` declares `GNA_DESK_PORT: ["8490"]`.
- **`units.sh drift`** exits 1 and names every installed unit whose `ExecStart` flag or `Environment=` value for
  such a variable holds a retired value, with the command that mends it.
- **`units.sh write <name> --render`** re-seats an adopted unit from the register, even where another installer
  wrote the file. The replaced lines are logged to `<state>/units-replaced.log`, as every write already does.
- **Eir's new `unitdrift` surface** asks `units.sh drift`; its mend re-seats exactly the drifted units. It is
  `safe` in `config/surfaces.yaml`, so Gróa's update mends it.
- The fleet's own template `tools/mill/systemd/gna-desk.service` no longer says `:8490` in its description.

### What was not changed, on purpose

- Only declared values are drift. A seat's own `--set` choice (a port the operator picked) is not a retired
  value, so it is never called drift and never rewritten. A full-text comparison would have undone such choices,
  for example the clone path `review-seat` passes.
- Without `--render`, the adopt road keeps an existing unit's shape, as before, so two writers cannot flip-flop.

### Proof

`bin/engine/tests/test_units_drift.sh` (9 checks, temp HOME, fake unit directory, no real unit touched): a desk
unit on 8490 is named with the source's value and the command; the adopt road alone keeps it; `--render`
re-seats it on 8494 and logs the old line; drift is then clean; a seat's own `--set` port is not drift. The
existing `test_units.sh` (50 checks) still passes.

### Files

- `bin/engine/units.py`
- `bin/engine/units.sh`
- `config/units.yaml`
- `tools/mill/systemd/gna-desk.service`
- `bin/engine/tests/test_units_drift.sh`

## CHANGE LOG

- **2026-11-12** — Opened.
