# Fix — the morning brief is judged, and the mend is written for you

**What was wrong.** The 07:00 brief publishes its file and *then* exits 1 when a draft has aged past
its limit, so the scheduler reports `job failed (rc=1)`. Read quickly, that means *no brief today* —
while the brief sits on disk, complete, carrying its own warning. Two other mornings were worse, and
whispered: a drafts door that never shipped makes the brief exit **0** with a `SKIP` line buried in
the file, and a 07:00 row that never fired writes **nothing at all**. Silence is exactly what a clean
morning sounds like, so the two worst mornings were indistinguishable from the best one.

**What was done.** One row, `@heart 07:05`, running `bin/time/nornir-job-brief-watch.sh`. It reads
three facts — the row's run stamp and exit code from `state/cron.log`, whether the brief file exists,
and the brief's own `drafts:` line — and decides one of a small named set of verdicts:

| Verdict | The one line it sends |
|---|---|
| `clean` | nothing at all; the no-op is recorded |
| `row-missing` | the brief did not run — check `bin/time/nornir-cron-start.sh --status` |
| `brief-missing` | the row ran and wrote no file — read its tail in `state/cron.log` |
| `drafts-aged` | how many drafts, how old, and that they are **send-or-discard** |
| `door-missing` | the pin is stale — run `bin/engine/pin-refresh.sh` |
| `no-grant` | grant the letters door; `bin/mail/draft-age.sh --brief` names the key |
| `unable` | the grant was refused — re-grant the letters door |
| `rc-failed` | the row failed for its own reason — the row's last line is the evidence |
| `rc-unknown` | the log cannot be read — look at it by hand, then at the scheduler |
| `no-drafts-line` | the brief came from an older shape of the job — the pin is stale, run `pin-refresh` |

Each line carries the drafted next act, so the reader does not have to know where to look.

**Two decisions that keep it to one line.**

It never exits non-zero on a not-clean day. The scheduler notifies on a non-zero row, so speaking and
then exiting 1 would send a second, dumber line — the very noise this replaces. It exits 1 only when it
*could not deliver*, because a watchdog that cannot speak must not be silent.

It judges a window, not a date. The log stamps UTC and the row fires in local time; rather than keep a
second clock, "did it fire this morning" is "did the last run stamp land inside the last 90 minutes".
A row that missed lands 23 hours back, which no window confuses.

**What was checked, and what did not need changing.**

| Reader | What it reads | Verdict |
|---|---|---|
| the scheduler | the exit code, for its notice | untouched — the fix note of 2026-11-17 (`a-not-clean-day-is-not-a-missing-brief`) already worded that notice honestly |
| the brief job | the drafts door | untouched — its `drafts:` line is what is now read |
| the notify door | one message and a key | reused as it stands, keyed `brief-watch:<date>` so one full stop per day |
| the operator's home | `config/cron.yaml` | the row is seated by migration `0025-brief-watch-row`, never by a hand-edit |

**Proof.** `bash bin/time/tests/test_brief_watch.sh` — 25 assertions over seven mornings: clean
(silent, and the no-op recorded), aged, door missing, row did not fire, one-message-only, an old-shape
brief with no drafts line, and undeliverable. The notify door is stood in front of by a stub, so "did it
speak" is a file, not an opinion. Both halves were mutated to prove the tests can fail: making a clean
day speak fails the silence proof, and exiting 1 on a not-clean day fails the one-line proof.

The old-shape verdict was not invented at a desk: the live briefs for 2026-11-14, 15 and 16 carry no
`drafts:` line at all (measured), because the drafts door shipped on the 17th. A watchdog that had
treated "no line" as "clean" would have called three of those mornings good.

Measured on the heart before the row existed:

```
$ bin/time/nornir-job-brief-watch.sh --dry-run
brief-watch[3]{verdict,line,dry}:
  "row-missing","brief: the 07:00 brief did not run this morning — its last run stamp is 2026-11-16T05:00:12Z (1389m ago) — next: check the scheduler: ..."
```

That is a true reading of the log at 06:10, before the 07:00 row had fired. The migration was proved on
four planted homes: no `cron.yaml` defers, the row lands immediately after the 07:00 row, a home with no
07:00 row gets it appended, and a second run changes nothing.

## CHANGE LOG

- 2026-11-17 — first written: the watchdog, the row, the migration, and the seven proofs.
- 2026-11-17 — review-mend: the old-shape morning (a brief with no drafts line) is its own verdict and its
  own proof, because the three live briefs before today carry no such line.
