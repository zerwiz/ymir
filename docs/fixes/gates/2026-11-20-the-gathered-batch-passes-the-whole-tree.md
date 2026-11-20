# The gathered batch passes the whole tree

**Component:** gates · **Date:** 2026-11-20

## What was wrong

The batch of `claude-seat-road`, `hypr-door` and `push-road` was green on the pre-push road and red on CI's
whole-tree gate, for three reasons that only a full tree shows:

- `bin/desktop/display-lib.sh` named a breadth-first list `todo`, and the mocks scan reads a bare `todo` in
  shipped code as a half-built door.
- `bin/gates/checks/push-road.test.sh` clones the checkout and expects the clone to have `origin/main`. A CI
  checkout has no local `main`, so the clone had none and the test stopped at its first row.
- The capability register did not name the new `claude_seat` modules.

## What changed

- The list is called `queue`. The behaviour is the same.
- When the clone has no `origin/main`, the test fetches the checkout's own `refs/remotes/origin/main` into
  it. A machine with a local `main` takes the old path.
- `bin/gates/capabilities.sh` was run, and the register and its fragments were committed.

No ward was changed or turned off.
