# desktop-main-guard names the fix door

**Date:** 2026-11-12 · **Component:** desktop · **Door:** `bin/gates/guards/desktop-main-guard.sh`

The guard's message now says to run `bash bin/host/omarchy-install.sh` from the main tree, which re-seats every launcher,
and not to edit the `.desktop` by hand. The guard stays a reader, not a second writer of the launcher register.
Test: `bin/gates/tests/test_desktop_main_guard.sh`. On this machine no launcher pointed into a worktree at the time of
the check.

## CHANGE LOG

- **2026-11-12** — Opened.
