## install · unversioned · 2026-09-25 — the mesh engine rides the install, and the boot table knows it

### Why
The Allfather asked whether the A2A setup was part of the install and the npm
path. It was not: the mesh engine (`a2abridge`) had been seated by hand, and a
fresh seat would have gotten the heart's A2A *node* (`ratatoskr`, via the fleet
step) yet never the engine, its directory, or the MCP wiring. This makes the
setup reproducible and puts the directory under the one boot table.

- **`step_a2a` added to `bin/ymir-install.sh`** (after `step_snotra`): ensures the
  engine via `bin/a2abridge-ensure.sh ensure --install`, then wires the mesh via
  `bin/a2a-mcp.sh install`. Its own post-start probe can race the daemon's first
  bind, so the row is decided by the **status check after**, never the ensure's
  exit alone. Honours `--skip-engines` and `--check` like its siblings.
- **`a2abridge-directory` added to the ONE boot table** (`bin/autoboot-lib.sh`):
  owed by `heart` and `dev`. `bin/ymir-autoboot.sh` now proves it like any other
  program, so a dead mesh directory is a failing check, not a mystery.
- **`bin/fleet-ensure.sh` materializes it as ENGINE-OWNED**: a2abridge's own
  installer writes and enables `a2abridge-directory.service`, so there is no Ymir
  template to copy. Absent, it is named **loudly** with the remedy (never a
  silent skip, never a re-templated unit), and the raise skips it so the failure
  surfaces in the verify, not in a restart loop.
- **`bin/eir-doctor.sh`** — the MCP surface no longer says “a2abridge is retired”
  (2026-09-23, written before the engine returned). When the engine is seated,
  the check now **requires** the `a2abridge` MCP wiring: a seated engine with no
  bridge is the silent half the check exists to catch.
- **Asset updated in the same change:** `installation.md` — the step table gains
  `a2a` (28 → 29 rows) and the `fleet` row names the engine-owned directory.

### Files
- `bin/ymir-install.sh`
- `bin/autoboot-lib.sh`
- `bin/fleet-ensure.sh`
- `bin/eir-doctor.sh`
- `.agents/skills/galdr-ymirsystem/assets/installation.md`

galdr-reread: `installation.md` (the `a2a` step; `a2abridge-directory` in the
fleet/autoboot rows).
