## skills · unversioned · 2026-09-24 — the smoke test reads the INSTALL's ports, and stops needing `ss`

### Why
Two faults in one check, found by running it inside the containerised install:

- **The ports were hardcoded to the dev seats** (`3888`, `3889`, `4602`, `4603`,
  `4322`, `8437`, `8438`). The install publishes `38888`, `38889`, `54370`, so the
  test reported **FAIL on `spa`, `api` and `smidja-api` of a perfectly healthy
  install**. A test that fails on health is worse than no test: it teaches the
  operator to ignore it.
- **It needed `ss` to decide whether a port was listening**, and the install
  container does not ship `ss` (the `oven/bun` image). A hall that *was* raised was
  therefore reported **SKIP**, and the visualizer **FAIL**, for want of a binary.

The ports belong to the install, not to the script: the operator's env file already
declares them (`deploy/env.example`), and the file the services read is the file the
test should read.

### What
- **The ports now come from the operator's env**, via `hoard_local_env`, env first
  and the dev-seat defaults second: `SPA_PORT`, `API_PORT`, `VIZ_PORT`,
  `VIZ_UI_PORT`, `HALL_PORT`, `WELL_URL` (from `MIMIRSBRUNN_URL`), `BIFROST_PORT`,
  `MODEL_PORT`.
- **`listening()` tries a bash-builtin TCP connect first** (`/dev/tcp`) and only
  falls back to `ss`. The test must run where the services run, and it may not bring
  its own toolchain.
- **Every check now names the port it probed**, so a FAIL cannot be misread as the
  wrong door.

### Files
- `.agents/skills/lifecycle/smoke_test.sh`
