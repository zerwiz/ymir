# Fix — a not-clean day is not a missing brief

**What was wrong.** The daily brief publishes its file and *then* exits 1 when a draft has aged past its limit. The
scheduler treats any non-zero row the same way and says:

> job failed (rc=1): bin/time/nornir-job-daily-briefing.sh — briefing: NOT CLEAN — drafts: 2 of 7 older than 2 days …

True, and misleading: "job failed" reads as *the brief did not happen*, while the brief is on disk, complete, carrying its
own warning about the day. A reader looking for a missing document would find one that was never missing, and a reader
skimming the first clause would conclude the morning had no brief at all.

**What was done.** The failure sentence now reads the job's own words first. When the last line of the log says
`NOT CLEAN`, the notice becomes:

> job failed (rc=1): bin/time/nornir-job-daily-briefing.sh — **the work was done, but not clean** — drafts: 2 of 7 older
> than 2 days …

**What was checked, and what did not need fixing.** Every reader was looked at, not assumed:

```
readers[4]{reader,what_it_reads,verdict}:
  "the scheduler (nornir-cron-start.sh)","the exit code, for the notice","the only reader of the code — fixed here"
  "the Runes","briefing.written on every run, briefing.drafts_aged when aged","both written; the record already told the truth"
  "day.py · mimir-recall-today · home-sync-clock · forgejo-git","the FILE, never the code","unaffected — several already say 'unable' rather than zero"
  "the brief itself","its own warning callout at the top and section 1c","published before the exit, so it is there to read"
```

**Proof.** `cron_fail_detail` on the real tail:

```
$ cron_fail_detail "$HOME" "bin/time/nornir-job-daily-briefing.sh" 1 'briefing: NOT CLEAN — drafts: 2 of 7 older than 2 days — "spec v2.5" (3 days)'
the work was done, but not clean — drafts: 2 of 7 older than 2 days — "spec v2.5" (3 days)
```

## CHANGE LOG

- 2026-11-16 — review-mend: added missing heading for #807
