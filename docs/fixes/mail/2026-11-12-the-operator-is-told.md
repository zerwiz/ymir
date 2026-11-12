# mail · 2026-11-12 — the operator is told about new mail, by the arm or directly

## Files
- `bin/mail/gna_notify.py` — the wake line asks the arm's holder to tell the operator; `helm_held()`;
  `hotline()`; `needs_you_count()`

## Why
The operator, 2026-11-12: *"I never get told about this. Where do I get told about this?"* and *"the arm should be
told about this, so the arm can tell the user."* Measured: Gná's job wrote one line per batch to the wake queue, and
`arm.sh status` reported `lock none` — no session held the helm, so the line sat in a file nobody read. Gná never used
the hotline (`bin/notify/send.sh`), which reaches the operator by Telegram and the desktop.

## What changed
- Every mail line Gná gives the arm now ends with *"tell the operator (Telegram), and say which need him"*, so the
  agent holding the arm (a Pi seat with its Telegram bridge) relays it instead of only reading it.
- When no session holds the helm, Gná also tells the operator directly through the hotline: one line naming the count,
  the first messages and how many need him, `MEDIUM` when any need him, with the mail index to open. A failed send is a
  failure in the job's log and a Rune, never silence.
- Unchanged: once per message, batched, inbound only; Gná still cannot send mail.

## Proof
`python3 bin/mail/tests/test_gna.py` → `Ran 37 tests … OK`. `gna_notify.py --pending` → nothing new (the imported
back-catalogue was marked seen in the home's ledger first, so old mail does not arrive as news).
`bin/notify/send.sh --source cron --severity MEDIUM … --dry-run` → `send`.

## Appended 2026-11-12 — mail he already paid attention to is not news
The operator: *"if we have paid attention [to it], we don't need [to be told]"*. `gna_notify.attended()` skips a
message Gmail no longer marks `UNREAD` (he opened it) or one he wrote in after it arrived, in the same thread (he
answered it). The desk and the importer count an answered mail as **done**. Measured on the operator's inbox: needs-you
92 → 90, done 195 → 197; `test_gna.py` 37 tests OK.
