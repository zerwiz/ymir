## hlidskjalf · unversioned · 2026-09-11 — Automate the install: consent gate, self-healing prereqs, visualizer-ready

### Why
- **Consent gate:** a real install now prints its plan and waits for the operator
  to accept (`[y/N]`). Declining changes nothing (exit 3). `--check` still previews
  without asking; non-interactive callers must pass `--yes`.
- **New `bin/prereq-ensure.sh`:** self-healing prerequisites in USER SPACE —
  installs `bun` and `uv` via their official installers, `mcp<2>` via pip, and can
  fetch a specific Python (e.g. `3.12`) with uv for packages that need one.
- **New `bin/smidja-bootstrap.sh`:** creates `smidja/smidja_data/smidja.db` from
  the tracer's own schema and seeds a bootstrap session, so the Smíðja visualizer
  has data from the first install. Fixed: it now bootstraps on a bare call
  instead of printing help, and reports failure honestly when the DB is absent.
- **`bin/ymir-install.sh`:** new `smidja` step; prerequisites delegated to the
  self-healing helper; `engram` reported as an honest optional `SKIP` with the
  exact next command; docker-group-permission and build-failure distinguished.
- **Verified:** consent refuse/accept/decline paths; smidja db created and read
  back (8 tables, bootstrap session); compliance 8/8.

### Files
- *(carried from the frozen CHANGELOG.md)*
