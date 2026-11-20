# Sixty-three findings, twice a day, ringing the phone as a failed job

**Date:** 2026-11-20 · **Component:** private-scan (`bin/time/nornir-job-private-scan.sh`) · **Errand:** `scan-exits-clean`

## What was wrong

The sweep runs twice a day and its exit line was:

```bash
[ "$findings" -gt 0 ] && exit 1 || exit 0      # and three more sites, the same shape
```

So **every finding was announced as a cron FAILURE**, and the findings never went away:

```
private-scan: 63 finding(s) — brief written, seating an errand
private-scan 63 findings — see <the home>/hodd/state/private-scan/queue.md
```

Sixty-three, twice a day, all of one kind: the operator's own domain names written literally into the public tree.
The queue and the brief were already written where work lives, an errand was already being seated — and the job
still reported itself broken, so the phone carried an alarm that said *the house is failing* about a job that was
doing exactly what it was built to do.

**A scheduled job's exit code is a claim about the job, not about the world.** The scan ran perfectly; it found
things; that is its job.

## What was built

| path | exit |
|---|---|
| the scan ran, with or without findings | **0** — the queue, the brief and the count are the output |
| `--fail-on-findings` was asked for and there are findings | 1 — for a caller that wants a gate (CI, a person) |
| the scan could not run (no home, no repository) | 2, naming the fault |
| this machine cannot be named in the fleet registry | 3, unchanged |

A clean run is unchanged: it still says `clean` and exits 0, so a channel that says "still fine" twice a day still
cannot exist.

## The proof

```
$ bash bin/time/tests/test_private_scan_exit.sh
  ok   a scheduled scan with findings exits 0 (rc=0)
  ok   it prints the count
  ok   the queue carries the finding
  ok   the brief is written for the errand
  ok   --fail-on-findings turns a finding into exit 1 (rc=1)
  ok   --report with findings exits 0 (rc=0)
  ok   no home to write the queue to (rc=2)
  ok   it names the fault
  ok   no repository at the named path (rc=2)
  ok   a clean scan exits 0 (rc=0)
  ok   it says clean
private-scan-exit: 11 passed, 0 failed
```

The fixture is a throwaway repository whose engine, notifier and spawner are stubs, so **no errand is ever
raised** by the test and the real tree is never swept. Both paths the operator asked for are proved: the scheduled
scan with a finding exits 0 and still does its work, and a scan that cannot run exits non-zero and says why.

On the real machine, the same command that used to fail:

```
$ bin/time/nornir-job-private-scan.sh ; echo rc=$?
private-scan: 63 finding(s) — brief written, seating an errand
rc=0
```

## What this does not decide

- **The 63 findings are still 63 findings.** They are the operator's own domain names in a public tree, and whether
  they are converted to configuration or declared in the allow list with a reason is his decision, not this door's.
- **The queue is not a decision queue yet.** It grows a section per sweep; the console in plan 332 is what turns a
  growing queue into rows somebody can acknowledge and silence.

## CHANGE LOG

- 2026-11-20 — written the day sixty-three findings were called a failure for the last time.
