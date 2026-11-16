# The macOS service layer: `systemctl --user` answered by launchd

**Date:** 2026-11-16 · **Component:** platforms / install · **Found while:** raising Ymir's services on a single Mac

## What went wrong

Ymir's services are systemd user units, driven by `systemctl --user` from about sixty places. A Mac has no systemd,
so the units were written during the install and nothing ever started them. The halls, the well and the MCP doors
stayed dark.

## What changed

| File | Change |
|---|---|
| `bin/engine/launchd-user.py` | Answers the `systemctl --user` verbs (enable, start, stop, restart, status, is-active, list-units and more) by rendering each unit as a launchd agent, `org.ymir.<unit>`. Logs go to `~/Library/Logs/ymir/`. |
| `bin/engine/launchd-ensure.sh` | `check`, `ensure` and `remove` for the shim at `~/.local/bin/systemctl`. Darwin only; a real `systemctl` is never shadowed. |
| `bin/engine/ymir-install.sh` | New step `launchd`, right after the runtime step. |
| `bin/engine/autoboot-lib.sh` | A Mac is a login-session seat, so it needs no linger. |

Two faults found while proving it are fixed in the same branch:

- Agents now run with `ProcessType` `Standard`. With `Background`, macOS throttled every service to almost no CPU.
- A restart waits for the old agent to unload before loading the new one. Without the wait launchd answered
  `Bootstrap failed: 5`.

## How it was proved

On one Mac (Apple silicon, macOS 14.7), eleven units came up through launchd and answered on loopback: 3889, 4602,
8316–8321 and 8437. They restart at login.
