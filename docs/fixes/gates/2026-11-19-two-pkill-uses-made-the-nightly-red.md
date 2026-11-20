# Two tests killed by name, so the nightly NSR round went red — and stayed red

**Date:** 2026-11-19 · **Component:** gates (`check_platform`, the nightly `nornir-job-nsr-compliance.sh`) ·
**Errand:** `heavy-lanes`

## What was wrong

At 05:41 on 2026-11-19 the nightly arrived as a failure with no output:

```
[cron/HIGH] job failed (rc=1): bin/time/nornir-job-nsr-compliance.sh — no output
```

The job is quiet by design — it carves a Rune and exits — so the reason had to be asked for:

```
$ bin/time/nornir-job-nsr-compliance.sh
nsr-compliance: gates=5 passed=4 failed=1 check_platform
```

and the gate, run on its own:

```
[check_platform] NON-PORTABLE: ./bin/engine/tests/test_heavy_slot.sh uses 'pkill'
    126:pkill -f 'sleep 30' 2>/dev/null || true
[check_platform] NON-PORTABLE: ./bin/seat/tests/test_desk_failsafes.sh uses 'pkill'
    79:pkill -f "$T/pi" >/dev/null 2>&1; sleep 1
```

Two tests killed leftovers **by name**. A pattern kill is not portable, and — worse — it is not
necessary here: in both cases the process was one the test had started and could have kept the pid of.

## What was built

| file | change |
|---|---|
| `bin/engine/tests/test_heavy_slot.sh` | the signal proof runs `sh -c 'exec sleep 30'`, so the runner's `TERM` reaches the process itself; the `pkill` clean-up line is gone |
| `bin/seat/tests/test_desk_failsafes.sh` | the fake agent is started with `( … exec "$T/pi" 60 ) &` and its pid kept in `PI_PID`; the death is `kill "$PI_PID"`, exact |

Both are the same shape of repair the platform gate asks for: **name the process you started, never the
pattern you hope matches it.** No `kill -9` was needed, so nothing is declared with `# kill:`.

## The proof

```bash
$ bash .compliance/gates/check_platform.sh
[check_platform] PASS

$ bash bin/engine/tests/test_heavy_slot.sh | tail -1
heavy-slot: 20 passed, 0 failed

$ bash bin/seat/tests/test_desk_failsafes.sh | tail -1
test_desk_failsafes: 44 passed, 0 failed
```

The nightly round is green on the branch that carries this:

```
nsr-compliance: gates=5 passed=5 failed=0
```

## What this does not decide

**It does not go green on `main` until this branch merges.** Measured while the branch was open: the cron
job resolves `ROOT` to the checkout the session runs in (`$BROKK_ROOT_OVERRIDE` when it is set, else the
tree the door walks up to), not to the worktree, so a fix on a branch cannot mend the nightly by sitting in
a worktree. The nightly stays red, and
says so honestly, until the merge.

## CHANGE LOG

- 2026-11-19 — written the night the cron failed.
