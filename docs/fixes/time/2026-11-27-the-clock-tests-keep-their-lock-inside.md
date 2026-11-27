# The clock tests keep their lock inside the state dir

**Component:** time · **Date:** 2026-11-27

Restoring plan 369 item 17 (see `docs/fixes/gates/2026-11-27-main-whole-tree-is-green-again.md`) made the clock
refuse a `.lock-path` that points outside its state dir. `.agents/tests/nornir-schedule-shapes.test.sh` and
`.agents/tests/nornir-catchup.test.sh` kept their lock in `$WORK/lock`, beside the state dir. On a machine with a live
session lock the clock fell back to that lock and the tests passed; in CI, where there is none, the clock waited out its
grace, no row fired, and 16 cases failed ("the day list fires on its second day: want 2, got 0").

Both tests now keep the lock in `$STATE/lock`.

**Proof:** both PASS with `XDG_STATE_HOME` and `HOME` pointed at an empty directory (no live lock anywhere); before the
change `nornir-schedule-shapes` printed `16 FAILED` the same way.

## CHANGE LOG

- 2026-11-26 — review-mend: added missing heading for #968
