## runtime · unversioned · 2026-09-25 — nornir is not debt: the ward corrected the audit

### Why
The `.sh` audit (plan 58) claimed `nornir` was the worst offender — “a
`while :` loop under `Type=oneshot`, a contract that contradicts itself”. Seat the
ward, and it flagged exactly that. Reading `bin/nornir-cron-start.sh` shows the
audit is **wrong**.

- The scheduler loop is a **string** (`scheduler='… while :; do …'`) that the
  script runs with `setsid bash -c "$scheduler" &` — it **detaches** the loop and
  exits, writing `state/cron.pid`. `Type=oneshot` is therefore **correct**: the
  unit's job is to ensure the loop is up and return. The `while` is never the
  unit's own foreground process.
- **Rule B now spares a detaching launcher:** `oneshot-loop` fires only when a
  `Type=oneshot` script holds a foreground loop **and** does not use
  `setsid` · `nohup` · `disown`. The allowlist entry
  `nornir.service:oneshot-loop` is **removed**.
- **Proved:** `bin/service-format.sh check` → **3 findings, 0 blocking**, exit 0 —
  `mill-worker` (daemon-in-bash) and `mimir` · `bifrost` (service-in-shim) remain
  the real, declared debt.

This is the ward earning its keep on its first run: it caught its own false
positive, and the record now says so.

galdr-reread: none (the allowlist and the ward are their own record).

### Files
- `bin/service-format.sh`
- `SERVICE-FORMAT.allow`
