## install · 2026-09-24 — the install enables ONE target and proves the boot

### Why
- The installer's `fleet` step ran `fleet-ensure.sh ensure` and mapped any gap to
  a WARN — a program that cannot rise must be a FAILURE the installation reports,
  with the unit and the reason (law, 2026-09-24).
- Nothing asserted Linger: on a headless seat (heart/forge/server) every enabled
  user unit is dead until someone logs in, and no surface said so.
- The `services` step raised the web stack by running `scripts/start.sh` and
  hoping; nothing at boot called it.

### Fix
- `step_fleet` now FAILS (not WARNs) when the role-gated ensure cannot raise a
  required program, naming the unit.
- New `step_autoboot` checks `loginctl show-user $USER -p Linger`, enables linger
  on headless seats (or fails with the exact remedy), and reports the Linger
  value on every seat in the install summary.
- `step_services` proves the raise with `bin/ymir-autoboot.sh verify` instead of
  re-running the old start.sh road (the road is retired for boot; the services
  are units).
- `step_validate` runs both the live checks and the boot proof as the final gate.
- The step table and this asset document the role-gated program sets
  (`bin/ymir-autoboot.sh` owns the one table).

### Files
- bin/ymir-install.sh (step_fleet · step_autoboot · step_services · step_validate)
- .agents/skills/galdr-ymirsystem/assets/installation.md (+ tyr mirror)
- .agents/skills/galdr-ymirsystem/assets/memory-well.md (+ tyr mirror)