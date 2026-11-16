# mail · 2026-11-16 — the join that answers "did we answer this", and the lane every thread is in

## Files
- `bin/mail/threads.sh` (new): one row per conversation — thread · direction of the last message · when · whether an
  outbound message came after the last inbound · unanswered age · lane. `--lane`, `--json`, `--store`, `--now`,
  `--nudge-days`. Reads the store and nothing else.
- `bin/mail/tests/test_threads.py` (new): 13 proofs, of which the three plan 305 asks for are the fixtures `answered`,
  `unanswered` and `waiting` — written to a temporary store and judged against a pinned `--now`, so a lane that
  depends on age cannot drift with the clock.
- `bin/mail/README.md`: the door added to the map, and the lanes named.
- `docs/features/mail-threads-and-lanes.md` (new): the plain-language page.
- `docs/features/_catalogue/entries/02-117-mail-threads-and-lanes.md` (new): the catalogue row, woven into `FEATURES.md`.

## Why
The store records mail beautifully and answers neither question the operator actually asks. Measured on his home,
2026-11-16: **226 messages · 133 in · 93 out · `thread_key` on 226 of 226 · `UNREAD` on 20 · `handled_at` on 0**.
Nothing joined an inbound message to the outbound one that answered it, so the house could say *what arrived* and
*what we sent* and never *did we answer this*. That is plan 305 §2.1's first phase: a reader, no new daemon.

## What changed
A single join, in one file, over the one record. Per thread the door derives the direction of the newest message,
its instant, whether an outbound message came after the last inbound (with the answering message id in the JSON face),
and the lane. It writes nothing — no state file, no `handled_at`, not the ledger — because derived state belongs to
the door that owns it, and a reader that writes is how two records come to disagree.

**The lanes, and the one reading plan 305 leaves open.** §2.1 calls both `answered` and `waiting-on-them` "we wrote
last", which is one fact under two names; §2's own flow diagram separates them by time (answered → silence, waiting →
a nudge after N days). So the split here is **age**, and the threshold is the three days §2.4 proposes, carried as
`--nudge-days` rather than baked in. `closed` covers his mark (`handled_at`, on no row today), a tail that owes
nothing (the judge's own verdict — `archive` · `record_notice` · `file_invoice`: a notice, an invoice, a calendar
machine, a bulk sender), and the ping-pong finish the plan names (out … in … out). `needs-you` is what remains of an
inbound tail, and it is the only lane that speaks.

**`unanswered_days` is a number only in `needs-you`.** A notice nobody must answer is not "unanswered for 21 days";
it is closed. Printing an age of debt where no debt exists is the same class of error as a green that hides a borrow.

**A filtered block shows no fake zeros.** Under `--lane` the counts block holds the lane asked for and nothing else,
because a zero that means "not asked for" reads exactly like the true green zero.

**No store is an error, not an empty answer.** Silence and an empty well look identical on a terminal; a missing store
exits 1 and names itself. A row that will not parse is counted, its first line is named on stderr, and it rides in
`totals.unreadable_rows` — a finding, not a blank. An empty store, by contrast, is a real answer and prints zero.

## Measured, on his home, 2026-11-16

```
lanes[4]{lane,threads}:
  "needs-you",24
  "answered",8
  "waiting-on-them",75
  "closed",95
mail: 226 messages · 202 threads · 95 closed without a reply (nothing was owed)
```

The `answered-twice` and `handled` reasons are both **0 on this store**, and the door says so by never printing them:
the store predates phase 3, which is what writes `handled_at`. Twenty of 226 messages carry `UNREAD`, and they sit in
18 threads — those are inside `needs-you`, which is exactly the question he asked.

## Proof
```
python3 bin/mail/tests/test_threads.py      → Ran 13 tests · OK
defaults-guard.sh check                     → none (0 defaults, 0 unresolved links)
language-guard.sh check                     → 3 findings, all in files this change does not touch
read-only                                   → store sha256 e4d6b9b6… and its mtime are identical
                                              before and after four runs (also asserted by a test)
python3 bin/mail/tests/test_gna.py          → 41 tests, 5 failing (3 IMAP-fixture errors, 2 DNS/desk
                                              failures); re-run with this change's files removed: the
                                              same five fail, so they are the environment, not this door
```

## Not in this phase
No re-sync of read state from Gmail (phase 2), no `handled_at` writing (phase 3), no lane on his list (phase 4) and
no change to the desk (phase 5). `ledger.jsonl` is untouched and still to be retired with a dated note, as §2.4 says —
this door reads `messages.jsonl` only, so it neither depends on the ledger nor keeps it alive.

## CHANGE LOG
- **2026-11-16** — written with the change (plan 305 phase 1).
