# A trouble notice is retried until it is sent, and every machine owes the panel

**Date:** 2026-11-21 · **Component:** ward (`bin/ward/trouble.py`, `bin/ward/tests/test_trouble.sh`,
`.agents/config/units.yaml`) · **Plan:** 339.5, 339.6, 341.4 · **Rework of:** PR #874
(`docs/fixes/ward/2026-11-20-the-house-says-it-is-in-trouble.md`)

## What was wrong, and what changed

The judge returned NEEDS-REWORK. Each item and what changed:

| Item | What was wrong | What changed |
|---|---|---|
| 1 · a notice that failed was never retried | `check()` stored RED whatever `send.sh` answered, so a failed or `duplicate` send was never tried again. The per-hour key also made red, green, red inside one hour a `duplicate` | What was said is kept apart from what was read, in `state/trouble/<host>.announced.json`. A turn is marked said only when `send.sh` decided `send` and exited 0. The key is per turn to red (`trouble:<host>:<signal>:t<epoch>`), so retries of one turn share a key and a new turn gets its own |
| 2 · the hand was left out | the timer and `fleet` covered heart, forge and dev only, while plan 339.6 says every machine in `fleet.json` | the timer is `roles: all`; `fleet` asks every machine in the registry, and `TROUBLE_ROLES` only narrows it |
| 3 · four faults had no planted test | no Hyprland error, pin past its line, unpushed errand branch or dead/stalled errand was planted | `test_trouble.sh` plants each one with a healthy twin, plus a failing send, a `duplicate`, and red-green-red inside an hour |

One side effect, stated so it is not a surprise: `check` without `--notify` no longer marks a red as said, so
the next `check --notify` still announces it. A dry run marks nothing either.

Proof: `bash bin/ward/tests/test_trouble.sh` passes all of its checks.
