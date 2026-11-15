# Fix — a failed row now says which failure it was

**What was wrong.** Every failed scheduled row got the same sentence:

```
job failed (rc=127): bin/records/gimle-tunnels-check.sh --quiet — no output
```

`no output` is true and useless. It cannot be told from a job that ran and said nothing, and the two faults have
entirely different mends: a row that was **never found** means the tree the scheduler stands in has gone stale; a row
that **ran and said nothing** means the program is broken. The house had the first, 213 times across 28 days from
2026-10-12, and every one of them read as the second (plan 292, the engine fix of the same date).

**What was done.**

1. **`bin/time/cron-fail-lib.sh`** — one function, `cron_fail_detail <home> <command> <rc> <tail>`, returning one line
   of at most 200 characters:
   - **127** — *"not found: `<home>/<first word>` — the row ran from `<home>`; that tree is stale
     (bin/engine/pin-refresh.sh brings the pin home)"*;
   - **126** — *"not executable: `<path>` — found, but the row may not run it"*;
   - anything else — the tail of the log, or *"no output — the row exited `<rc>` and said nothing"*.
2. **`bin/time/nornir-cron-start.sh`** grew one `run_row` body that both branches (flock and no-flock) call, so the
   notifier can no longer drift from itself; it sources the lib when it is present, and falls back to the tail-only
   message when the tree it runs from is older than the lib. A failed row also writes a `cron FAIL` line to the log
   with the same sentence, so the record and the notice cannot disagree.

**Proof.** Cases 6 of `bin/gates/tests/test_pin_refresh.sh` cover the four sentences — 127 with the path named, 127
when the path appears afterwards, 126 as not-executable, a real failure keeping the log's last line, and a silent
failure naming its exit code instead of claiming "no output".
