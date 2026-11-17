# mail · 2026-11-17 — a draft cannot grow old quietly, and the brief cannot call an aged day clean

## Files

- `bin/mail/draft-age.sh` (new): the drafts door. Every draft Gmail holds, oldest first, with its age in days; exit
  `1` — naming each offender — when one is older than the limit (`--days`, default `YMIR_DRAFT_MAX_DAYS` or 2);
  `--brief` for the one line a briefing carries; `--json` for a script. Read-only.
- `bin/mail/tests/test_draft_age.py` (new): 11 proofs against a stub Gmail — the three the brief asks for
  (no drafts · a fresh draft · an aged draft failing), plus the limit moving the line, paging, a refused list,
  a missing grant, the read-only claim, and the brief itself.
- `bin/time/nornir-job-daily-briefing.sh`: the probe, the `### The letters nobody sent` line, the warning at the
  top of the brief, and a non-zero exit while a draft has aged.
- `bin/mail/README.md`: the door in the desk's map.
- `docs/features/draft-age-the-unwritten-letter.md` (new) and
  `docs/features/_catalogue/entries/02-118-a-draft-cannot-grow-old-quietly.md` (new): the page and the row, woven
  into `FEATURES.md`.

## Why

A letter that was written and never sent is the one piece of correspondence that fails in silence: nobody is
waiting for it, so nothing reminds anyone. The morning brief already counted what came in, what went out and what
was owed — but it read the house's own shelves, never the drafts sitting in the mailbox. So two days could pass,
a promised follow-up could rot, and the 07:00 brief would still report a clean day. The Allfather's task of
2026-11-16: *a draft cannot grow old quietly — the brief fails on a draft older than two days.*

## What changed

**The door reads and never writes.** It asks Gmail's drafts list, follows `nextPageToken` (a full first page
cannot hide the oldest draft), and fetches each draft message's metadata for its subject and its instant. The age
is that instant — `internalDate`, else the `Date` header — so a draft edited this morning is a fresh draft: the
age of the letter, not of the idea. "Older than the limit" is measured on the exact elapsed time, not the printed
day count, so two days and three hours is aged under a limit of two.

**Exit codes carry the verdict, and a skip is named.** `0` nothing has aged · `1` aged, each one named ·
`2` usage · `3` the mailbox could not be read, with the reason. A missing Google grant is
`drafts: SKIP — the vault carries no Google client on this seat` with exit `0`: a permission the machine does not
hold is not an empty outbox, and printing `0 drafts` for it is the exact lie this door exists to prevent. The same
is true of a `401`: `UNABLE — HTTP 401`, exit `3`, never a clean zero.

**The brief asks once and does not pass a green verdict over an aged draft.** The probe runs before the brief is
composed, so the alarm can sit at the top of it. When a draft has aged the brief opens with a warning naming the
draft and its age, the line is carried under *The letters nobody sent*, the rune `briefing.drafts_aged` is carved,
and the job exits `1`. An aged draft therefore cannot leave the day looking clean, and a skip or an unreadable
mailbox is carried into the brief by name.

**The brief is published, the clean verdict is not.** It was tempting to refuse to publish at all; a morning with
no brief is a morning with no news, and that is worse than a brief with a red banner. The file lands, the banner
names the letter, the exit code is red.

## Proof

```
python3 bin/mail/tests/test_draft_age.py     → Ran 11 tests · OK
```

- `NoDrafts` — an empty outbox is clean and says *none*.
- `FreshDraft` — six hours old is listed as `0.2` days and passes.
- `AgedDraft` — five days old fails the door (exit 1), is named in `aged[1]`, and the brief publishes the warning
  and exits 1.
- `TheLimit` — `--days 5` passes three days, `--days 3` passes exactly three, the default fails it.
- `NoGrant` — named SKIP, exit 0, and the stub saw no token POST and no mailbox read at all.
- `Unreadable` — `401` is `UNABLE`, exit 3.
- `Paging` — a draft on page two is seen (nine days old, on a stub with two per page).
- `ReadOnly` — the stub's record holds GETs and one token POST, nothing else.
- `TheBriefing` — three briefs: clean with a fresh draft, red with an aged one, named SKIP with no grant.

The pre-existing wards still pass: `bin/gates/inventory.sh --check` (sources clean),
`bin/gates/guards/subsystem-docs-guard.sh` (none), and `python3 bin/mail/tests/test_gna.py` keeps its own
`NoSendCapability` ward — this door carries no send path, and `ReadOnly` proves it behaviourally rather than by
string-matching.

## Owed

The door is only as good as the grant on the machine it runs on. On a seat with no Google key it says `SKIP`
every morning, by name; that is honest, not green. Carrying the grant (or the connect door) to a new seat is the
work that makes the line real there.

## CHANGE LOG

- 2026-11-16 — review-mend: added missing heading for #809
