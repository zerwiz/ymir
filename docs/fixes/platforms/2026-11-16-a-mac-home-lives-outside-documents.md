# A Mac home lives outside ~/Documents

**Date:** 2026-11-16 · **Component:** platforms / install · **Found while:** raising the launchd service layer on a Mac

## What went wrong

The default home was `~/Documents/ymirhome` on every platform. On macOS, `~/Documents` is protected by TCC. A launchd
agent that opens it is refused, so `smidja` failed with `unable to open database file` and kept restarting. The
folder is also often synced by iCloud, which put heavy load on the machine.

## What changed

| File | Change |
|---|---|
| `bin/vault/hoard-lib.sh` | On Darwin the default home is `~/ymirhome`; other platforms keep `~/Documents/ymirhome`. |
| `bin/engine/ymir-install.sh` | `step_home` warns (`home-mac`) when a Mac home sits under `~/Documents`, `~/Desktop`, `~/Downloads` or iCloud Drive. |

A recorded home (`~/.config/ymir/home`) and `YMIR_HOME` still win, so an existing install is not moved silently. The
warning tells the operator to move it and record the new path.
