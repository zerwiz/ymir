# The morning brief — and what to do when it is not clean

**What it is.** Every morning at 07:00 one job writes your daily brief: the open forge orders, the
active plans, the meetings, the letters nobody sent, your messages in and out, and the Runes of the
day. It is a file, written from records rather than from memory, and it does not call a model.

Five minutes later a second job reads that morning and tells you what happened — *if* something went
wrong. On a clean day it says nothing at all.

That second job exists because the first one fails badly. The brief publishes its file and *then*
exits with an error when a draft letter has aged, so the scheduler reports:

> job failed (rc=1): bin/time/nornir-job-daily-briefing.sh

Read quickly, that says *there is no brief today*. There is a brief; it is on disk, and it carries its
own warning at the top. Worse, two other mornings say **nothing whatsoever**: a drafts door that never
shipped, and a row that never fired. Both look exactly like a clean day.

## What you need

- Ymir with the Nornir schedule running (`bin/time/nornir-cron-start.sh --status`).
- Two rows in your `config/cron.yaml` — the brief at 07:00 and its watchdog at 07:05:

      @heart 07:00 bin/time/nornir-job-daily-briefing.sh
      @heart 07:05 bin/time/nornir-job-brief-watch.sh

  Migration `0025-brief-watch-row` seats the second row for you on an existing home; a fresh install
  already has both. Changing the row's role to `@dev` moves the brief to that machine instead.

## Do it

Read the brief: it lands at

    $YMIR_HOME/svartalfaheim/<realm>/workspace/memory/daily/YYYY-MM-DD.md

Run the watchdog by hand whenever you want the morning judged:

    bin/time/nornir-job-brief-watch.sh --dry-run     # print the line, send nothing
    bin/time/nornir-job-brief-watch.sh               # send it if the day is not clean

What it will tell you, and what it suggests you do:

| It sees | What it says |
|---|---|
| clean day | nothing; it records a no-op |
| the 07:00 row never fired | the scheduler is not running — check `nornir-cron-start.sh --status` |
| the row ran, no file | read the row's own tail in `state/cron.log` |
| aged drafts | how many, how old, and that they are send-or-discard |
| the drafts door is missing | the pin is stale — run `bin/engine/pin-refresh.sh` |
| the drafts door is not granted | grant the letters door; `bin/mail/draft-age.sh --brief` names the key |
| the grant was refused | re-grant the letters door |
| the row failed for another reason | the row's own last line in `state/cron.log` |
| the log cannot be read | look at it by hand, then check the scheduler |
| the brief has no drafts line | it was written by an older job — the pin is stale, run `pin-refresh` |

## Limits

- One line per day: the day's key is `brief-watch:<date>`, so a re-run does not repeat it.
- It never exits with an error on a not-clean day — otherwise the scheduler would send its own second
  line, which is the noise this job was built to replace. It exits with an error only when it cannot
  deliver, because a watchdog that cannot speak must not be silent.
- It judges the last 90 minutes of the log (`BROKK_BRIEF_WATCH_WINDOW`), not a calendar date, so a
  timezone conversion can never make it wrong.
- It records its last verdict in `state/brief-watch.last` and nothing else; only speaking writes a Rune.

## If it does not work

- **No line on a bad day.** The notify door is quiet below HIGH, or the message was deduped — look at
  `state/brief-watch.last` for the verdict, then run with `--dry-run` to see the line it would send.
- **It reports "the row did not run" every day.** The scheduler is not running, or the row sits on a
  role this machine does not have (`@heart` on a laptop). Check `bin/time/nornir-cron-start.sh --status`.
- **It says the brief is missing but you can see it.** The realm in the path is wrong: the brief is
  written to the *active* realm, and `BROKK_BRIEF_DIR` overrides the whole directory.
- **The proofs.** `bash bin/time/tests/test_brief_watch.sh` — the clean, aged, door-missing,
  row-did-not-fire and old-shape mornings.

## CHANGE LOG

- 2026-11-18 — gathered into the one delivery batch; unchanged since it was written.
