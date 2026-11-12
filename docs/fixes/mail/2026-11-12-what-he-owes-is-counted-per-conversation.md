# mail · 2026-11-12 — what the operator owes is counted per conversation, and his to-do follows it

## Files
- `bin/mail/gna_judge.py`: calendar mail is archived (`calendar_mail()`); every no-reply spelling is bulk; a question
  word counts only where the writer's own text asks (`_asks()`); a thread no longer hands down an archive verdict
- `bin/mail/gna_import.py`: `--rejudge [--dry-run]` judges the stored mail again and appends only changed verdicts
- `bin/records/comms.py`: the newest row per message wins; `asks_him()`, `owed_conversations()`; one **open** line per
  conversation; **send** lines for Gmail drafts; **close** proposals when a sent reply answers a house line; password
  resets and test mailboxes are never *waiting*; a tick matches the first mail that answers it, never a draft
- `bin/day/day.py`: the mail fact counts owed conversations through the comms door
- `bin/mail/tests/test_gna.py` (+4), `bin/records/tests/test_comms.py` (+4)
- `docs/features/messages-in-out-and-owed.md`: appended section

## Why
The operator, 2026-11-12: *"are my personal todolist built out to support this information"*. Measured that night:
the mail index said he owed a reply in **100** conversations. About 60 were calendar invitations and RSVPs, two were
Google's own tips (`mail-noreply@` was not recognised as no-reply), and many were notices that matched "what" or "when"
without asking anything. Nothing put the real ones on his to-do. The comms door proposed only for single *reply needed*
mails from the last three days, closed nothing when he answered, and its tick for "Send the board email" cited the
wrong mail, because it took whichever matching mail it read first, drafts included.

## What changed
- The judge: calendar machinery → `archive` (`matched_by: calendar`); no-reply senders → `archive` before any other
  rule; the question class needs a question mark above any quoted reply.
- The re-judge on his store: 306 inbound judged, 158 verdicts appended (64 meetings and 6 replies → archive, the rest
  sharper). Owed conversations: **100 → 26** by the index's rule, **18** by the comms door (which also counts a reply
  sent in a new thread), 7 of them from the last 14 days.
- The to-do proposals: one line per owed conversation (thread-keyed, so never twice); one line per Gmail draft; a sent
  reply proposes closing the house's line, and a close ticks that line in place. His own lines are never edited, and
  nothing is written without his yes.

## Proof
`python3 bin/mail/tests/test_gna.py` → `Ran 41 tests … OK`. `python3 bin/records/tests/test_comms.py` →
`Ran 14 tests … OK`. `gna_import.py --self-test` → `9/9`. On his home, `comms.sh todo-matches` proposes the two true
ticks (the board email cites the 20:42 mail to both Craig and Reygan), seven owed conversations, the one Gmail draft,
and four questions he is waiting on.

## CHANGE LOG
- **2026-11-12** — Written with the change.
