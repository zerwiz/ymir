# Nornir judges each job on the seat that owns it, and a script at two times fires twice

Date: 2026-11-24 · Component: time (Nornir) · Part of plan 365 (the work road)

## What was wrong

- **A job that belongs to another seat showed as DOWN.** The Hlidskjalf Cron panel marked every row not meant for this seat as DOWN, so a heart job that ran fine looked broken.
- **The same script at two times fired once.** The scheduler kept one stamp per command, and the stamp held only the date. A row at 06:10 and a row at 18:10 for the same script shared it, so the evening run never fired. `private-scan` ran only in the morning for that reason.
- **A comma role gate never matched.** `@heart,forge,dev` was tested as one word. It now splits on commas.
- **The heart's log looked dead.** The heart's scheduler runs with a state override and logs to `state/cron.log` in the home. The old `~/.local/state/ymir/cron.log` stopped on 2026-11-09. A pointer file `cron.log.now` in the default state dir now names the live log.
- **Forge jobs never ran while the forge was dark.** The forge host has been dark for 34 days.

## What changed

- `bin/time/nornir-status.sh` (and `nornir-status.py`) is the one resolver. It judges each job on its owning seat, from the role in the fleet registry, and reads that seat's last runs over the ssh ring (cached 60 s, 4 s timeout). The states are RAN, ELSEWHERE, DUE, LATE, FAILED, DOWN, DARK, MOVED and IDLE. The headline counts only LATE, FAILED, DOWN and DARK, and every non-green row ends with its next step.
- `ymir nornir`, the Eir surface `nornir` and the panel's `/api/cron/status` all call it.
- `nornir-cron-start.sh --last` prints each job's last run and last failure from the seat's own log.
- The stamp for a fixed-time row now carries the time (`<date> <HH:MM>`).
- `bin/time/forge-dark.sh` lets the heart run `@forge` rows when the forge has been dark for more than 24 hours. The row is then reported as MOVED.

Proof: `python3 tests/test_nornir_status.py`.

## CHANGE LOG

- 2026-11-24 — review-mend: added missing heading for #924
