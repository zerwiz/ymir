# 2026-11-23 — Garmr restarts itself when its heartbeat goes stale (plan 354)

The Allfather: *"make it self-heal"* — Garmr the hound was silent 43 h on the dev desk, and its service stayed
active while its heartbeat died. The fix: a systemd watchdog on `garmr-hound.service`.

## The change

`bin/ward/garmr-hound.service.example` gains:
- `WatchdogSec=120` — systemd sends SIGABRT if no heartbeat arrives in 2 min
- `Restart=always` with `RestartSec=10` — the hound comes back
- `NotifyAccess=main` — the hound's main process is the only one that may notify

The hound (`bin/ward/garmr/hound.py`) gains a `sd_notify("WATCHDOG=1")` call every 60 s, inside the
`Pulse` loop that already writes the heartbeat. If the loop stalls, the watchdog fires within 2 min.

## Install

On every machine that runs Garmr:
    sudo systemctl daemon-reload
    sudo systemctl restart garmr-hound.service

## Verify

    systemctl show garmr-hound.service -p WatchdogUSec -p NRestarts
    # WatchdogUSec=2min 0s; NRestarts=0 after a healthy hour

## Note

The hound runs as root, so the unit file and the restart need sudo. Eir's `housewatch` surface reports
the watchdog's state alongside the hound's heartbeat.

## CHANGE LOG

- 2026-11-23 — review-mend: added missing heading for #919
