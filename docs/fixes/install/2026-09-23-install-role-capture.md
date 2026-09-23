## install · unversioned · 2026-09-23 — the installer captures the machine's role (plan 51 P1, install half)

### Why
- **Problem:** Plan 51's P1 was half-built: `bin/role.sh` could declare and
  validate a role, but the **installer never called it**, so a fresh machine
  arrived with no role and every role-aware surface (cron gates, MCP config,
  model placement, dispatch) had nothing to read.
- **Fix:** a new install step, `step_role`, run right after host learning:
  - reads this machine's role from the fleet registry by hostname;
  - if the host is **absent**, registers it as **`dev`** — the safe default,
    because a dev body owns no record and runs no record jobs;
  - reports the role and the live link (`topology.sh`), e.g.
    `role: heart,forge (link: attached)` on the server;
  - honors `YMIR_HOST` (so the check is testable), and `--check` writes nothing
    (it warns instead of registering).

### Verified
- `bin/ymir-install.sh --check` on this box (registry: `dev`) →
  `"role","OK","role: dev (link: attached)"`.
- As `whynot` (registry: `heart,forge`) →
  `"role","OK","role: heart,forge (link: attached)"`.
- With an empty registry and `YMIR_HOST=absentbox` →
  `"role","WARN","not in the fleet registry — a real run registers 'absentbox' as dev"`.
- `bash -n` clean; `compliance` clean.

### Files
- `bin/ymir-install.sh`
