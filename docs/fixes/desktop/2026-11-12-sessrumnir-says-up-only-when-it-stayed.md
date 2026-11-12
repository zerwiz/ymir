# Sessrúmnir's launcher says "up" only when the window stayed, and logs why when it did not

**Date:** 2026-11-12 · **Component:** desktop · **Door:** `bin/desktop/sessrumnir-launch.sh` · **Plan:** 271

## What was wrong

`start` printed "up" as soon as the process appeared. The window then ended with `state/sessrumnir.log`
empty, because the node wrapper discarded how Electron ended: on a signal death `code` is null and the old
handler exited 0 in silence.

## What was forged

- `apps/sessrumnir/bin/sessrumnir.js` logs the start and the end (`code`, `signal`, seconds) and turns on
  Chromium's own logging, so the log is no longer empty.
- The launcher holds its claim for `SESSRUMNIR_STAY_S` seconds (default 10). If the window is gone before
  that, it exits 1 and writes the reason to the log and stderr: the app's exit line and any core dump since
  the launch.
- The process match is tighter (`/electron/dist/electron .*sessrumnir`), so a foreign command line cannot
  match.

## The root cause is still open

The real death was not reproduced. Two headless runs were tried and crashed for a reason that has nothing to
do with the app (`--ozone-platform=headless` segfaults even a trivial Electron window), so they prove nothing.
The next real death will now name itself in the log. Proof of the launcher logic is on a stand-in:
`bin/desktop/tests/test_sessrumnir_stays.sh`.

## CHANGE LOG

- **2026-11-12** — written by its errand; change-log section added at the gather.
