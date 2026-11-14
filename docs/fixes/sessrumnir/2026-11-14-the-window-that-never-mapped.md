# Two windows that were not there: the frozen one, and the one that never mapped

**Date:** 2026-11-14 · **Component:** sessrumnir · **Doors:** `apps/sessrumnir/bin/sessrumnir.js`, `apps/sessrumnir/src/main/file-service.ts`, `bin/desktop/sessrumnir-launch.sh`, `bin/host/graphics-lib.sh` · **Plan:** 283

## What the Allfather saw

*"Sessrúmnir starts over and over."* Two separate faults, both measured on heimdall tonight.

### One — it started and then froze

Hyprland's "Application not responding" dialog fired on a Sessrúmnir window at 02:28:00, 02:28:09,
02:33:46, 02:33:54 and 02:35:52; the window closed each time. With DevTools detached, so the debugging
session was not the cause: for the first 60–90 s the main process held its JS thread at 100 %, three V8
worker GC threads at 100 %, reached 1.5 GB RSS and 43 s of CPU, then fell idle.

A CPU profile of the main process (`--inspect=9229`, 500 µs sampling) named the work instead of guessing:
`lstat` under chokidar's `_addToNodeFs`, and chokidar's own matcher spending its samples in
`path.resolve`/`path.relative`. It was the **first walk of the disk watcher**, over a workspace carrying
this house's 198 worktree checkouts in `.yggdrasil/`.

- `.yggdrasil` is an ignored directory now.
- the walk starts 2.5 s after a workspace becomes active (`FileService.startWatching` arms the timer,
  `attachWatcher` does the work, `stopWatching` clears a pending start), so the window answers first.

Measured after: main-process RSS at start 1.5 GB → 213 MB, CPU after the walk under 10 %, and no dialog.

### Two — the window mapped nowhere at all

Then the app ran, answered DevTools (`document.visibilityState: visible`), and the compositor listed **no
client**: the operator had nothing to click, and clicked again. Five launches, the same board:

| flags | window in the compositor |
|---|---|
| none | yes |
| `--disable-gpu` | **no** |
| `--disable-gpu --disable-gpu-compositing` | **no** |
| `--disable-gpu --ozone-platform=x11` | **yes** |

This machine's graphics policy resolves to `software`, so every launch takes the GPU-off path: every launch
here has been opening an invisible window. The launcher keeps the policy's flags and adds
`--ozone-platform=x11` for a Wayland session, with the measurement beside it.

## The settings became the operator's, not the code's

His word: *"are this settings able to be set from env files for diffrent users ? we probly need that."*
They are now: `$YMIR_HOME/config/desktop.env` is read by every app launcher (`desktop_env_load` in
`bin/host/graphics-lib.sh`), with `YMIR_DESKTOP_DISABLE_GPU` (`auto`/`1`/`0`),
`YMIR_DESKTOP_OZONE_PLATFORM` (`auto`/`wayland`/`x11`) and `YMIR_DESKTOP_PIN`. An explicitly exported
value still wins over the file, and the home is found through its one resolver. The template ships as
`.agents/config/desktop.env.example` with its row in `.agents/home-contract.yaml`; the how-to is
`docs/features/desktop-env.md`.

## Proved

From the pin `7ae529759d0b` on heimdall: the window mapped at 18 s and was still there after 5 min 18 s,
RSS steady at 213 MB, no not-responding dialog in `browserkill-trace` for the whole window. nidavellir was
offline at the time of this note (`tailscale status`: last seen 1h ago), so its row is owed and named in
plan 283.
