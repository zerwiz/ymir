# The one batch meets CI

**Component:** gates · **Date:** 2026-11-20

## What was wrong

The gathered batch (PR #853) passed every pre-push ward, but CI's whole-tree gate was red on five rows. Each one
came from two good changes meeting in a single tree:

- **mocks-vocabulary.** The generated `bin/records/INDEX.md` names the board's doors, `todo.sh` and
  `todo_board.py`. The scan's to-do excuse covered the files and the config filename, but not those door
  names inside a generated index.
- **push-road.** A CI runner has no git identity. The test's probe commit failed with
  `fatal: empty ident name`, so the test stopped at its first row.
- **private-scan-exit.** Plan 331 moved runtime state from `hodd/state/` to the home's `state/` shelf. The
  scan now writes its queue to `state/private-scan/queue.md`, but the test from #847 still looked in
  `hodd/state/`.
- **surfaces-from-the-home.** The check ran `bash -c 'python3 "$ROOT/…"'`. `ROOT` is not exported, so the
  inner shell saw an empty path and asked for `/bin/…`.
- **capability.** The review judge appends a `## CHANGE LOG` heading to every document it touches. That
  includes `.agents/assets/agents/capabilities.md`, which is generated, so the generator's own staleness
  check called the result stale.

## What changed

- `mocks-scan.sh` treats the door filenames `todo.sh` and `todo_board.py` like `todo-board.yaml`. This is
  the same to-do exception, given at the Allfather's word ("merge all into one PR", 2026-11-20).
- `push-road.test.sh` exports a fixture identity for every repo it makes (its clone and the catch-up check's
  scratch remote), using a noreply address so the identity ward accepts it. It passes with no git identity
  at all (an empty `HOME`).
- `test_private_scan_exit.sh` looks for the queue on the `state/` shelf.
- `0513-surfaces-from-the-home.sh` runs the test directly, with no inner shell.
- `capabilities.sh` writes the `## CHANGE LOG` section itself. The judge and the check now agree, and the
  judge has nothing to append on the next run.

No ward was turned off.
