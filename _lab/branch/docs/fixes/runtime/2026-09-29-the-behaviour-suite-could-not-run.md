# The behaviour suite could not run at all

**Component:** runtime (test harness) · **Date:** 2026-09-29

## The symptom

Running any `.agents/tests/*.test.sh` produced nonsense rather than a verdict:

```
chmod: cannot access '/self-held-lock/fakebin/tmux': No such file or directory
_: line 2: .../.agents/bin/fm-wake-lib.sh: No such file or directory
not ok - self-held lock was not reclaimed cleanly (rc=10)
```

Fixture paths rooted at `/`, `$ROOT/bin` unresolvable, every assertion failing.

## The cause

`.agents/tests/lib.sh` sits at `<root>/.agents/tests/lib.sh`, so the repo root is
**two** levels up. It resolved **one** level up:

```bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # -> <root>/.agents
```

Every sourcing test then built fixture paths against `$ROOT`, which pointed at
`.agents/` — so `$TMP_ROOT` was empty, `mkdir` wrote to `/`, and `$ROOT/bin`
never resolved.

## Why it went unnoticed

The suite **still printed `ok -` and `not ok -` lines**, so it looked like a suite
with failures rather than one that never ran. A test harness that cannot execute
and a test harness with real failures look the same in a terminal, and the
obvious reaction to real failures is to ignore them.

This is the same class of defect as the arm's silent exit: **failure that carries
no signal.** Every supervision bug this suite could have caught — the watcher not
waking, the arm mis-binding, the twins drifting — was invisible for as long as it
could not run.

## The change

One line, plus the comment explaining why it is two levels and what it looked
like when it was one.

## Proof

`bash .agents/tests/fm-wake-queue.test.sh` now runs and reports five passes:

```
ok - self-announced appends suppress only their own bytes and fail toward waking
ok - historical annotations replay nothing already announced and keep everything new
ok - concurrent append plus drain preserves durable records through acknowledgement
ok - signal written while no watcher runs is caught on next run
not ok - watcher did not exit for stale pane
```

**The last line is a real, previously-invisible bug**, not a regression: the
watcher did not exit for a stale pane. It is now reachable and worth its own fix
note. Everything else in `.agents/tests/` should be re-run now that it executes.

## Note for the wards

Any test that cannot *run* must fail loudly and distinguish itself. A green-ish
terminal full of lines is not proof of a suite. This is a candidate invariant:
`bin/pr-pretest.sh` should assert that the shell suite reports a real verdict,
not merely that it exited 0.