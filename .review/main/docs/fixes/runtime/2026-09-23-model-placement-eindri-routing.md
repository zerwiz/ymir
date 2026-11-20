## runtime · unversioned · 2026-09-23 — model placement and Eindri routing by role (plan 51 Phase 5)

### Why
- **Problem:** models are hardware-bound and the fleet is heterogeneous (A5000,
  3080 eGPU, 3050 Ti, P2000, GTX 770M), but nothing said **which machine hosts
  which model** or **which machine should host an errand**. A body could pull a
  20 GB model onto a laptop, and an errand went wherever the session happened to
  be.
- **Fix, two role-aware planners:**
  - **`bin/model-placement.sh`** — reports every **forge** host's rail
    (`http://<tailnet>:8080`), whether it answers (offline-safe), and this
    machine's one-local-model lock. The forge owns the heavy rail; a body calls it
    over the tailnet instead of downloading.
  - **`bin/eindri-route.sh <kind>`** — maps an errand to the role that fits:
    `model|bench|gpu|train|inference → forge`; `ui|desktop|app|design|theme → dev`;
    `record|ledger|memory|backlog|plan|sync|ticket|audit → heart`; anything else →
    `any` (this machine first). Prints the target host(s) from the registry.
    `--kinds` documents the table; `--json` for machines.

### Verified
- `.agents/tests/model-eindri.test.sh` — **ALL PASS**: the forge rail is listed
  and non-forge hosts are not; a model errand routes to the forge, a record errand
  to the heart, a ui errand to a dev body; an unmatched kind defaults to `any`
  with this machine first; route JSON parses.
- On this box: rails `whynot` (reachable), `zerwizserver` (no); `record → whynot`.

### Files
- `bin/model-placement.sh`
- `bin/eindri-route.sh`
- `.agents/tests/model-eindri.test.sh`
