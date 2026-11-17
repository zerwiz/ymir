# mail · 2026-11-17 — a conversation closes by evidence, not only by a letter

## Files

- `bin/mail/threads.sh`: reads `hodd/memory/mail/evidence.yaml` when it exists (or a file
  named with `--evidence FILE`), closes a thread on a **document**, a **meeting** or a
  **filing**, names that evidence on the closed line, and marks a fifth kind —
  `answered-elsewhere` — inside `--window DAYS` (default 14).
- `bin/mail/tests/test_threads.py`: ten new proofs, including the one that keeps an
  unsigned development agreement out of a signed NDA. 23 proofs in all, all green.
- `bin/mail/README.md`: the lanes section now names the evidence kinds and the two flags.
- `docs/features/mail-threads-and-lanes.md`: the plain-language page, updated.
- `docs/features/_catalogue/entries/02-118-mail-closed-by-evidence.md`: a new catalogue row,
  woven by `bin/records/weave-features.sh`.

## Why

The lane counted a conversation as open when nobody wrote back. But nine of the biggest
open cluster were resolved by **signing**, not by answering: the mutual NDA was signed on
16 October, confirmed on the 19th, and the mail still read open. A lane that accepts
nothing but a reply marks finished work as debt forever, and the operator then spends hours
on work already done.

The audit of the 49 (2026-11-17) counted five genuinely open and three notices to file, and
it left one lesson in writing: **evidence must be specific**. A rule that matched the
sender's domain alone folded four messages about a *development agreement* — never
completed, chased four times — into the signed NDA, and hid them. One contract being signed
does not sign another.

## What changed

A thread is in one lane, and that has not moved. What changed is how it may reach `closed`.

| Evidence kind | What closes the row | What the row must carry |
|---|---|---|
| **document** | a signed or delivered artefact in the home | a path, and the message id when there is one |
| **meeting** | a meeting record for the day in question | the record, and the message id when there is one |
| **filing** | a notice that needed nothing but reading | the register row, or the reason |
| **reply** | computed from the store, never declared | the outbound letter itself, joined by thread |

The fifth is quieter and is always **marked**: `answered-elsewhere`. We wrote to that same
person inside `--window` days but about something else, so the subject is still open in
substance. It closes the row, it says so, and it is **never counted in the reply totals** —
a letter about another thing is not an answer, and a lane that says otherwise starts lying
to the person reading it.

**A row is checked before it may close anything.** It must name its evidence and it must
narrow to a subject, a thread or a message id. A row that matches on a domain
(`from_domain:`, or a bare `docsigner.example.net` inside `from:`) is refused outright; a row that
narrows to the sender alone is refused for a document or a meeting. Every refusal is named
on stderr and counted in `--json` as `totals.evidence_refused`, because a refused row and
an absent row must never look the same.

A `kind: reply` row is refused too. The letters are the authority on whether a letter was
sent; declaring one in a file would be a claim the store would have to confirm.

## Measured, on the operator's home, 2026-11-17

```
lanes[4]{lane,threads}:            with the evidence file      without one
  needs-you                        5                           7
  answered                         6                           6
  waiting-on-them                  86                          86
  closed                           261                         259
```

Two threads leave `needs-you` because the NDA document answers them. Sixteen rows close as
`answered-elsewhere` and are marked as such. The same store with a domain-only row written
in closes **nothing** and reports `1 refused`: the development agreement stays where it
belongs.

## Proof

```
python3 bin/mail/tests/test_threads.py   → Ran 23 tests · OK
python3 bin/mail/tests/test_gna.py       → Ran 49 tests · OK
bash bin/mail/threads.sh                 → 0.12s over 828 messages / 358 threads
--evidence to a missing path             → exit 1, "no evidence file at that path"
--window many                            → exit 1, "wants a whole number of days"
```

The four proofs the errand asked for are named in the test file: a document row closes
without a letter, a filing closes, a window closure is marked `answered-elsewhere` and is
not a reply, and a row matching only a sender domain closes nothing.

## Not in this change

The evidence file itself is the operator's record, not the door's: this change reads
`hodd/memory/mail/evidence.yaml` and never writes it. Four rows are in it today and all four
are applied. A thread whose sender the file does not name — the NDA-signed notice that
arrived from a third address, for instance — stays open until a row about it exists, which
is the point: only where someone looked.

## CHANGE LOG

- **2026-11-17** — written with the change.
