# mail · 2026-11-16 — the RFC headers: a reply can name the message it answers

## Files

- `bin/mail/gna_import.py` — `message_id` · `in_reply_to` · `references` on every row, the IMAP
  thread key taken from the message's own chain, and the `--backfill-headers` door
- `bin/mail/gna_store.py` — the three headers are part of a row's content identity, so a version
  that gains them is a new version and the backfill writes exactly once
- `bin/mail/tests/test_headers.py` (new) — 12 proofs: the fields, the backfill, the header join,
  and a reply drafted through the letters door that names the message it answers
- `bin/mail/README.md` · `docs/features/gna-the-one-mail-desk.md` — the door and how to use it

## Why

Measured in the store on 2026-11-16: **226 messages, `thread_key` on 226 of 226, and not one row
with a `Message-ID`.** Every message the desk had ever read was identified by Gmail's own id, and
every conversation was a key derived from the subject — the one thing a reply is free to rewrite.
So the house could say *what arrived* and could not say *which message this answers*, and a reply
that changed its subject would have been joined to a stranger (or to nothing).

The RFC 5322 headers are the standard answer, they are carried by every ordinary message, and they
were already in the response the importer had in its hand.

## Fix

**The headers are read from the payload that was already fetched.** The Gmail road reads each
message with `format=full`, which carries every header in `payload.headers` — so `Message-ID`,
`In-Reply-To` and `References` cost no second request. The proof counts the calls: one message read
per message, `format=full`, and no metadata read for a message the body read already answered.

**The IMAP road, which has no `threadId`, is joined by the same chain.** Its `thread_key` is now the
**root** of `References` (the first message of the conversation), falling back to `In-Reply-To`, then
to the message's own name. Before this it took the first token of `In-Reply-To` — the *parent*, which
splits a three-message chain into two conversations.

**Every row says when its headers were read** (`headers_at`), so *"this message has no In-Reply-To"*
(a fact about the first message of a thread) can be told apart from *"nobody kept it yet"* (the
backfill's own question).

**`--backfill-headers` fills the rows already written.** One `format=metadata` read per row — the
three header names and nothing else, never a body — then a new version of that row is appended
(the store is append-only, so the row that lacked the headers stays in the history), stamped with
`headers_at` and `actor: gna-backfill-headers`. It is **idempotent by construction**: a row is
complete when it carries the message's name and that stamp, so the second run finds nothing, asks
nothing and writes nothing. A message the mailbox no longer has is counted in `gone` and named;
it is not an exception, and its row keeps what it had.

**The store's identity hash carries the three headers** (`gna_store._sha`). Without that, a filled
row would hash exactly like the unfilled one and be skipped as unchanged — the backfill would have
reported success and written nothing. `headers_at` is deliberately **not** hashed: stamping when the
headers were read must not turn every re-read into a new row.

The transport that cannot be backfilled is refused by name: `--backfill-headers` asks Gmail, and an
`imap` account's headers arrive with the message its own fetch already carries — the door says so
instead of meeting a second protocol here.

## Verified

```
python3 bin/mail/tests/test_headers.py
Ran 12 tests in 4.5s
OK
```

| Proof | What it shows |
|---|---|
| `ImportStoresHeaders::test_1` | the row carries `<m-1@letters.test>`, an empty `In-Reply-To` (a first message), `headers_at`, and Gmail's own `threadId` still as `thread_key` |
| `ImportStoresHeaders::test_2` | exactly one read per message, `format=full`, and **no** metadata read — the headers cost no request |
| `BackfillHeaders::test_1` | two legacy rows are filled from `format=metadata` with the three `metadataHeaders`; `written: 2`; `thread_key` (`t-old`) survives |
| `BackfillHeaders::test_2` | the spine holds **two** versions of the row: the one without the headers and the one with them |
| `BackfillHeaders::test_3` | a second run: `missing 0 · filled 0 · written 0`, zero API calls, spine unchanged |
| `BackfillHeaders::test_4` | a message the mailbox no longer has is listed in `gone`, the other rows are still filled, nothing raises |
| `ThreadedByHeader::test_1` | two messages, subjects `The invoice for October` and `Re: something else entirely`, both keyed `first@letters.test` |
| `ThreadedByHeader::test_2` | a third, deeper reply still lands on the same key (the **root** of the chain) |
| `ThreadedByHeader::test_3` | the subjects really do disagree — joined by subject they would be strangers |
| `ThreadedByHeader::test_4` | the join has an effect, not just a key: the reply inherits `invoice` with `matched_by: thread` |
| `LettersDoorNamesTheMessageItAnswers::test_1` | **the loop closed**: the importer stores `<alpha-1@letters.test>`; `systems/snotra/services/letters/mail-send.sh draft --reply-to alpha-1` produces a letter whose `In-Reply-To` **is** that value and whose `References` contains it, with the subject defaulted to `Re: …` |
| `LettersDoorNamesTheMessageItAnswers::test_2` | the letters door asked for `format=metadata` and the `Message-ID`/`References` headers — it never read the body to learn the name |

The whole desk still passes, and the door's own fast check grew two proofs:

```
python3 -m unittest discover -s bin/mail/tests -p "test_*.py"   → Ran 74 tests, OK
python3 bin/mail/gna_import.py --self-test                      → 13/13 passed
```

**Run against the operator's own store, dry run, nothing written** (2026-11-16):

```
gna · <the account> · headers
  rows     405 stored · 405 without the message's name
  filled   405 (dry run — nothing written)
```

405 rows, each one read over `format=metadata` and nothing else, no `gone` line — every stored
message is still in the mailbox. The real fill appends one new version per row to the home's
spine, so it is the operator's (or the helm's) to run:

```
python3 bin/mail/gna_import.py --account <the account> --backfill-headers
```

## What this does not do

It does not re-import a mailbox, rewrite a body, or touch a message in Gmail: the backfill is a
metadata read and an append, nothing else. It does not send, and it adds no send path — the reply in
the proof is drafted by the letters door, which is where sending has always lived, behind the
operator's approval.

## CHANGE LOG

- **2026-11-16** — note written: the three headers on every row, the IMAP key from the chain, and
  `--backfill-headers`.
