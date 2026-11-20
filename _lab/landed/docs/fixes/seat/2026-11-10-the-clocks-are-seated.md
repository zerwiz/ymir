# 2026-11-10 — the clocks are seated

bin/seat/clocks.sh seats plan-watch, ship-watch and update-loop as user systemd
timers. install is idempotent and refuses a missing ExecStart; status shows the
last journal line per loop.

## CHANGE LOG

- 2026-11-10 — created.
