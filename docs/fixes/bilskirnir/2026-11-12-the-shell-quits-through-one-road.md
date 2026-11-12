# The Bilskirnir shell quits through one road

**Date:** 2026-11-12 · **Component:** bilskirnir · **Door:** `apps/bilskirnir/electron/main.js`

## What was wrong

Four SIGTRAP core dumps (`coredumpctl`, 2026-11-12 01:42–02:05) came from closing the shell's test windows. The old
shell kept no handle on its window and went on waiting for the hall (up to 30 seconds) after the window was closed, then
called `loadURL` on a destroyed window.

## What was forged

- Every ending goes through `app.quit()`, including SIGINT and SIGTERM.
- A `quitting` flag stops the wait for the hall, and the window handle is dropped on `closed`.
- A load into a window that closed meanwhile is skipped, and an interrupted load is not reported as a fault.
- The shell raises no backend of its own (`start.sh` owns the gateway and server), so there are no children to reap.
- Test: `apps/bilskirnir/tests/quit-clean.sh` closes the window while waiting and after load, headless, and checks
  exit 0 and no new core.

> [!NOTE]
> I could not reproduce the SIGTRAP here: the old code also exited 0 with no core, headless and on Wayland. The
> original dumps likely came from an external driver closing the window. The change removes the one race I could find
> and the test guards it. If a core appears again, `coredumpctl info` will name the cause.
