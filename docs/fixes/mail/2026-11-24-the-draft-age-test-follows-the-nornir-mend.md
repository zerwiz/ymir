# The draft-age test follows the Nornir mend

**What broke.** `whole-tree` went red on #923 (`draft-weekly` row): `bin/mail/tests/test_draft_age.py`
`test_an_aged_draft_makes_the_brief_not_clean` still demanded exit 1 from
`bin/time/nornir-job-daily-briefing.sh` over an aged draft.

**Why.** The Nornir mend (#907, 2026-11-22) changed the job on purpose: aged drafts are the
Allfather's decision, not a broken job. The brief is written, so the job exits 0; the aged drafts
are named on stdout, carved as a Rune, and put on his to-do list. The test was not moved with it.

**Fix.** The test now expects exit 0 and the `drafts aged` line on stdout, and still demands the
published brief carries the alarm ("Unwritten letters have aged", the subject, the limit).

## CHANGE LOG

- 2026-11-24 — written with the fix (Fulla, gather #923).
