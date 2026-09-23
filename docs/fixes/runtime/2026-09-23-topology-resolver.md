## runtime · unversioned · 2026-09-23 — topology: role, shape, and the link to the heart (plan 51 Phase 0)

### Why
- **Problem:** Ymir had no answer to the first three questions an operator asks of
  a fleet: *Is this a single computer? Am I connected to a server? Am I one node
  among several — and if the server is down, am I detached or fully offline?*
  Nothing read a machine's role, so install, cron, MCP, models, and dispatch all
  behaved as though every machine were the same machine. That gap is what let a
  dev box run the record jobs, a hand-placed server file pass unnoticed, and 8
  seat schedulers leak.
- **Fix (Phase 0 of plan 51):** `bin/topology.sh` — a sensor that reports, and
  changes nothing:
  - **host · roles · shape · heart · link · journal**, from ONE registry
    (`$YMIR_HOME/hodd/data/fleet.json`, one row per machine, read by hostname) plus
    env overrides (`YMIR_ROLE`, `YMIR_HEART`, `YMIR_HOST`).
  - **link** = `attached` (heart answers) · `detached` (a network but no heart) ·
    `offline` (no route) · `standalone` (no heart configured). Offline and detached
    are **first-class**, per plan 51's law 6.
  - **journal** age — what has not yet reached the heart (the sync-up outbox).
  - `--json` for machines; a missing registry degrades cleanly (role `dev`,
    no crash), because a lone box has no registry.
- **Also:** the lifecycle smoke test gains a tolerant **topology** check
  (attached → OK; detached/offline → SKIP, never FAIL — a machine working offline
  is healthy, not broken); and `.agents/tests/topology.test.sh` proves all four
  states.

### Verified
- `topology.test.sh` — **ALL PASS** (attached, detached, standalone, missing
  registry, JSON parses).
- On this box: `fleet, roles=dev — attached to the heart` (heart `whynot`).
- `smoke_test.sh` — **exit 0**, no FAILs.

### Files
- `bin/topology.sh`
- `config/fleet.json.example`
- `.agents/tests/topology.test.sh`
- `.agents/skills/lifecycle/smoke_test.sh`
