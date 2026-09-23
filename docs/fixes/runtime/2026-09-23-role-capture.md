## runtime · unversioned · 2026-09-23 — role capture and validation (plan 51 Phase 1)

### Why
- **Problem:** role is the one fact every surface should derive from — install,
  update, MCP config, the cron set, the model rail, dispatch — but nothing could
  *declare or validate* it. The registry existed only as seed data.
- **Fix:** `bin/role.sh` — the writer and the validator for the fleet registry
  (`$YMIR_HOME/hodd/data/fleet.json`):
  - `show [host]` — this machine's roles and the whole roster (heart included).
  - `set <host> <role[,role]>` — sets a host's roles, **refusing an unknown role**
    (known: `heart · forge · dev · hand`), writing atomically.
  - `rm <host>` — remove a row.
  - `validate` — every role in the roster is known, and the named heart is a real
    host row; exit 1 on drift.

### Verified
- `.agents/tests/role.test.sh` — **ALL PASS**: set+show; the roster grows; an
  unknown role is refused; validate passes for known roles and **rejects** an
  unknown one; `rm` removes a row.
- On this box: `heimdall → dev`, roster `heimdall dev · omarchy dev ·
  whynot heart,forge · zerwizserver forge`.

### Files
- `bin/role.sh`
- `.agents/tests/role.test.sh`
