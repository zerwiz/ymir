# agents · 2026-11-20 — the arm wakes on the errands it dispatched

At the Allfather's word: *"Why aren't the Rödd arm waking you up to check if their Eindris are behaving or done?
This are broken. Fix it."*

## What went wrong

In one night, three workers ended without the arm saying a word:

- Two errands failed with *"[liveness] the pane held no agent"*. The pane was empty, but the status file still
  read `working:`.
- One errand reported *"committed on eindri/…"* on a branch that held zero commits. `git log origin/main..HEAD`
  was empty.

All three were found by reading status files by hand at 04:00. The arm only raised on signals it already
tracked: the wake queue, the lease, a one-shot trigger, a terminal status line. It never asked about the
errands it had dispatched.

## What the arm raises now

The engine (`src/ymir_runtime/watch.py`, `errand_wake`) reads every `state/<id>.meta` touched inside the last
24 hours, beside its `state/<id>.status`. It raises three kinds of line.

| Case | When | Line |
|---|---|---|
| Dead worker | the meta names a pane, `herdr agent list` shows no agent in it, and the status has not ended (`done:` · `resolved:` · `failed:`) | `stale: errand <id> has no agent in <pane> (status: <last line>)` |
| False done | the status says `done:`, and the branch (`eindri/<id>`, else the worktree's branch) has no commits ahead of the remote default branch | `check: errand <id> reported done with nothing committed` |
| False done, off the batch road | as above, but the meta is not `mode=batch` and the branch is missing from the remote, or has commits it does not | `check: errand <id> reported done with no branch pushed` · `… with N commit(s) not pushed` |
| Stalled worker | the status says `working:`, neither file has changed for 30 minutes, and herdr shows the pane's agent `idle` or `done` | `stale: errand <id> has said nothing for <n> minutes` |

A `mode=batch` errand is never asked to push, because its contract is commit-and-never-push.

## How it stays quiet

- **One wake per fact.** Each finding is keyed by errand and kind in `state/.arm.errand-woke`, together with
  the fact it saw: the pane and status line, the `done:` line, or the two file times. The key is written
  before the line is returned. The same fact never wakes twice. A new fact, such as a new status line, wakes
  once more.
- **No guess on a silent door.** If `herdr agent list` does not answer, no worker is judged dead or idle.
- **Old records are left alone.** Errands untouched for 24 hours are skipped
  (`BROKK_WATCH_ERRAND_HORIZON_SECONDS`). A `done:` written before the check existed is never judged against
  git (`state/.arm.errand-epoch`), because a gathered and merged branch reads as empty.
- **Git runs once per `done:` line**, not once per poll. The verdict is recorded even when it is healthy.
- **The check comes before the celebration.** The false-done `check:` is raised ahead of the `signal: <id>
  done: …` for the same line, so the helm reads the warning first.
- **The hourly brake does not swallow these.** The generic brake allows three `stale:`/`check:` lines an hour.
  Errand lines carry their own ledger, so they pass it; the fourth dead worker of a bad night is still raised.
- **A full slot holds the next raise.** The daemon no longer raises while `.arm.event` still holds an
  undelivered line. Before, `publish` dropped the new line, and a trigger or an errand finding was consumed
  with nobody told.

The stall window is `BROKK_WATCH_ERRAND_STALL_SECONDS` (default 1800).

## A second fault found on the way: the first `done:` was swallowed

`.arm.terminal-epoch` (plan 257 H3) was stamped lazily, at the moment the first terminal status line was
met. The epoch was therefore always a moment after that line. So the first `done:` a fresh home ever wrote
was seeded in silence and never raised. Both epochs are now stamped on the first scan. The probe below found
it: the false-done case was silent until this was fixed.

## Proof

`python3 -m unittest ymir_runtime.tests.test_watch` (from `src/`): **86 tests, OK**. There are 16 new cases
(`ErrandWakeTest`, `EagerEpochTest`). They cover the dead, false-done, pushed, batch, stall and quiet cases,
the silent-herdr case, the horizon, the epoch, the brake and the full slot. The false-done cases use real git
repositories with a bare origin.

The real door, `bin/pi/syn-watch.sh run --emit`, was run against a scratch state dir with a fake `herdr` on
`PATH`. Exit 124 means the run timed out without raising anything.

```text
== quiet: a healthy errand ==
[exit 124]
== 1: dead worker, first pass ==
stale: errand probe-errand has no agent in wGONE:p1 (status: working: launched (heartbeat baseline))
== 1: dead worker, next pass ==
[exit 124]
== 2: false done over an empty branch ==
check: errand probe-done reported done with nothing committed
== 2: next pass ==
signal: probe-done done: committed on eindri/probe-done (not pushed)
== 2b: a lone (non-batch) done with a commit but no branch pushed ==
check: errand probe-done reported done with no branch pushed
== 3: stalled earner, quiet for 40 minutes, agent idle ==
stale: errand probe-stall has said nothing for 40 minutes
== 3: next pass ==
[exit 124]
```
