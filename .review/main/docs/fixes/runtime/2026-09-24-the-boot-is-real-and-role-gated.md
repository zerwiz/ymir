## runtime · 2026-09-24 — the boot is real, role-gated, and proven

### Why
- Every unit template in `tools/mill/systemd/` shipped an `[Install]` header with
  **no `WantedBy`**, and `ratatoskr.service` had no `[Install]` at all. A unit
  with no `WantedBy` is `static`: `systemctl --user enable` is a **silent no-op**.
- `bin/fleet-ensure.sh` bet the whole raise on that broken enable and swallowed
  every failure with `|| say "$u: could not raise (warn)"`. A fresh seat booted
  with none of the fleet services running, and no install surface said so.
- Four services nevertheless looked enabled on whynot because symlinks from an
  older hand sat in `default.target.wants/` — the state looked healthy and was
  accidental.
- `embed.service` crash-looped at boot (restart counters 249 on the heart, 3608
  on heimdall) on a missing executable/model — enabled, so it looped forever.
- The dev web stack (Hlidskjalf :3888, the gate :3889, Mimir :4602, Bifrost
  :4603, Smiðja :8437) had no units at all; only `scripts/start.sh` raised it,
  and nothing called that at boot.

### Fix
- Every unit template now carries `[Install] WantedBy=ymir.target`; a new
  `ymir.target` (materialized per seat) pulls the whole role set, and the install
  enables THE ONE target. Every restart unit gains `StartLimitIntervalSec`/
  `StartLimitBurst` so a broken unit lands in `failed` loudly instead of looping
  forever.
- The web stack becomes user units (`tools/web/systemd/`): hlidskjalf-spa ·
  hlidskjalf-gate · mimir · bifrost · smidja · nornir, all joined to `ymir.target`
  on dev seats. `bin/mimir-bridge.sh` and `bin/bifrost-bridge.sh` gained
  `--foreground` so systemd supervises the process itself.
- `bin/fleet-ensure.sh ensure` is role-gated (roles from `hodd/data/fleet.json`),
  materializes only what the seat owes, purges stale unit files (the old
  accidental enables), retires the manual start.sh stack by port, asserts Linger
  on headless seats, and then **verifies**: a role-owed program that is not
  enabled or not active is a FAILURE with its reason — never a `warn`.
- `bin/ymir-autoboot.sh status|verify` is the boot proof — per role, every
  program with enabled/active; `verify` exits non-zero when a role-owed program
  is disabled or not standing. Nornir's truth is its scheduler loop (the unit is
  a oneshot wrapper); its down-with-no-session state is understood, its
  down-while-session-live state is a failure.
- `embed.service` is heart/forge-gated, runs the fleet's ONE canonical engine
  (`/usr/local/bin/llama-server`) CPU-bound (`-ngl 0` — it must never fight the
  rail for the GPU), and its unit is written only when both the binary and the
  model exist; otherwise the install fails loudly with the remedy. No written
  unit, no loop.
- `bin/eir-doctor.sh` gained the `autoboot` surface: `verify` is the health,
  `fleet-ensure ensure` is the mend.

### Files
- tools/mill/systemd/*.service (install contracts + start limits)
- tools/web/systemd/ (ymir.target + the six web units)
- bin/fleet-ensure.sh · bin/autoboot-lib.sh · bin/ymir-autoboot.sh (new)
- bin/mimir-bridge.sh · bin/bifrost-bridge.sh (--foreground)
- bin/eir-doctor.sh (autoboot surface)
- bin/ymir-install.sh (fleet/autoboot/services/validate steps)