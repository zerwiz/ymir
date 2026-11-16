# Sessrúmnir, Bilskirnir and Rödd launch on a Mac

**Date:** 2026-11-16 · **Component:** platforms / desktop · **Found while:** opening every Ymir app on a Mac

## What went wrong

Three app launchers used commands that exist only on Linux, so their windows never opened on macOS:

| App | Fault | What the operator saw |
|---|---|---|
| Sessrúmnir | `bin/sessrumnir.js` looked only for `dist/electron`; the launcher used `date -Is` | `Electron not found`, then `date: invalid argument 's' for -I` |
| Bilskirnir | `start.sh` spawned every piece with `setsid`; `setup.sh` hashed with `sha256sum` | the window died silently; `sha256sum: command not found` |
| Rödd | `start.sh` spawned with `setsid`; `setup.sh` hashed with `sha256sum` | no window |

## What changed

- Sessrúmnir looks for the binary at its place on each OS: `Electron.app/Contents/MacOS/Electron` on a Mac,
  `electron.exe` on Windows, `electron` on Linux. The launcher's start time uses a format both `date`s accept, and
  its window probe matches any binary under `electron/dist/`.
- Bilskirnir and Rödd start a new session with `setsid` where it exists, and with Perl's `POSIX::setsid` on a Mac.
  The group stop still works, because each piece is still its own session leader.
- Both setups hash with `sha256sum`, or with `shasum -a 256` where it is missing.

Linux behaviour is unchanged.

## CHANGE LOG

- 2026-11-15 — review-mend: added missing heading for #783
