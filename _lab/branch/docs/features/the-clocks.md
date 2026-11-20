# The clocks — seating the loops

`bin/seat/clocks.sh` seats the three Ymir loops as user systemd timers.

Commands:
- `status` — what is installed, active, last run, last journal line.
- `install [--dry-run]` — write one unit+timer pair per loop.
- `uninstall` — remove them.

Loops:
- plan-watch: daily 07:30, Persistent=true.
- ship-watch: every 5 minutes.
- update-loop: every 15 minutes (honours state/.update-hold).

A missing ExecStart is refused at install time.

## CHANGE LOG

- 2026-11-10 — created.
