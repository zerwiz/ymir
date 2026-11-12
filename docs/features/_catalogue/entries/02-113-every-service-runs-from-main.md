---
section: agents-work-collaboration
---
| Core | **Every service and app runs from main — from the first install, through one register and one writer** (`config/units.yaml` · `bin/engine/units.sh` · `bin/engine/runtime-seat.sh` · [how-to](docs/features/every-service-runs-from-main.md)) | His word, 2026-11-12: *"aren't we pinning ymir to run from main, all apps etc, when people update and install?"* · *"can they all be connected to the same system?"*. Install seats `~/ymir-runtime` (steps `runtime` and `units`), Gróa seats a missing pin instead of skipping, and `runtime-deploy.sh` restarts the units the register owes, not a fixed ten. One register lists every unit; launchers and app unit templates are discovered from `apps/*`, so a new app joins by shipping its template. One writer renders them against the pin and logs every line it replaces; mail, the forge watchers and Bilskirnir call it. Eir's `runtimepin` surface fails on any unit or launcher off the pin or unregistered. Plan 269 | [docs/features/every-service-runs-from-main.md](docs/features/every-service-runs-from-main.md) |

## CHANGE LOG

- 2026-11-12 — added with plan 269.
