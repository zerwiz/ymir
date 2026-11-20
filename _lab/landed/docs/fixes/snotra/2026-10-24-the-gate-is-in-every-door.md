## snotra · 2026-10-24 — three doors walked past the gate; the gate now stands in each of them

**Plan 124 §7** (the word before the letter), his word 2026-10-24: *"the plans are now capable of sending
out emails first to me so I can validate what's ever going out or made in the correct way."*

### Files
- `bin/time/snotra/snotra-approve.sh` — the word itself: `gate` · `consume` · `approve-event` · `hold` ·
  `pending-of`; an approval is now **single use**, and every refusal is carved into the Runes
- `bin/time/snotra/mail-send.sh` — `send` asks the gate **before** it asks Google; a spent approval cannot replay
- `bin/time/snotra/calendar-invite.sh` — `sendUpdates=none` by default; `all` only on a fresh, approved event
  body; `cancel --notify` gated the same way
- `bin/time/snotra/tests/test_outbound_gate.py` — 12 proofs, one per behaviour, no Google in the loop
- `docs/features/the-outbound-gate.md` — the how-to for the operator

### What was wrong — measured in plan 124 §7, and it was one door standing and three walking past it

```
holes[3]{door,what it did}:
  "mail-send.sh send <draft-id>","POSTed /users/me/drafts/send after a token refresh and never called snotra-approve.sh — the gate was enforced by a CALLER (snotra-letter.py), so every other caller sent freely"
  "calendar-invite.sh create --attendees","posted with sendUpdates=all, so Google mailed every attendee the instant an event was made — an invitation that never passed a gate at all"
  "bin/mail/ (Gná)","had no send path; the debt was real but unwritten, so a later hand could have added one without noticing the gate existed"
```

The first two were the same fault in two shapes: **the check lived in a caller's habit rather than in the door.**
A door that checks nothing is a door; a door that checks is a gate.

### What now stands

- **The check is a verb of each door.** `mail-send.sh send` runs `snotra-approve.sh gate mail <id>` before it
  builds a request, and `calendar-invite.sh` runs `gate event <key> --bytes <payload>` before it decides
  `sendUpdates`. No caller has to remember; `snotra-letter.py`'s own check is now a courtesy, not the guard.
- **An approval is spent by the send it authorised.** After a successful send the record is marked `SENT`
  (a `.sent` sidecar, written once, never rewritten) and a second send is refused with `ALREADY SENT` — the
  send socket is never opened for it.
- **A refusal is as loud as an approval.** `gate-refused` and `gate-spent` are carved into the Runes with the
  subject, the operator and the reason; the door prints the same reason to stderr:
  `NOT APPROVED` · `STALE` (the content changed after the word) · `ALREADY SENT`.
- **Google mails nobody by default.** `create` without attendees posts `sendUpdates=none` and needs no word,
  because nothing reaches a person. With attendees it renders the event body, holds it
  (`approve-event <event-key>` reads exactly those bytes), and refuses with a four-line recipe until the word
  stands. Only then does it post `sendUpdates=all`, and it spends the word.
- **A cancellation is outbound mail too.** `cancel` defaults to `sendUpdates=none`; `cancel --notify` requires
  an approved cancellation body (`evt-<event-id>-cancel`). A fourth hole was not opened while closing three.
- **Endpoints are configuration, not constants** (Rule 07): `YMIR_GMAIL_API_BASE`, `YMIR_CALENDAR_API_BASE`,
  `YMIR_OAUTH_TOKEN_URL` — the three defaults are the real Google doors, and the test stands a local server
  behind them so the gate is proven with no mailbox and no network.

### Measured — 12 proofs, run twice (`mail-send.sh --self-test`, `calendar-invite.sh --self-test`)

```
$ python3 bin/time/snotra/tests/test_outbound_gate.py
Ran 12 tests in 12.602s
OK

  mail    an unapproved draft is REFUSED (NOT APPROVED) · no drafts/send POST · "REFUSED mail r-1" in the Runes
  mail    an approved draft sends exactly once · a second send ALREADY SENT · still one POST · SPENT carved
  mail    a draft edited after approval is STALE · no POST · "REFUSED mail r-3: STALE"
  mail    the check is inside the door: its `gate mail` call precedes `drafts/send` in the send body
  cal     attendees without the word: exit 3, no event posted, body held for reading
  cal     approved: sendUpdates=all, one post, spent; the same word cannot release a second invitation
  cal     an edited event after approval is STALE; nothing posted
  cal     no attendees: sendUpdates=none, no word needed
  cal     cancel mails nobody; cancel --notify needs its own word
  cal     the door itself holds one `send_updates="none"` default and sets `all` in exactly two approved branches
  gná     Gná's own ward still holds (test_gna.py::NoSendCapability) — nothing in bin/mail can send
  tree    no door in bin/ sends without naming the gate
```

### What is refused
- **A send whose approval does not match the bytes that would leave** — NOT APPROVED, STALE, or ALREADY SENT.
- **An invitation that reaches an attendee before the operator has read it** — the default is no mail.
- **A cancellation notice nobody approved.**
- **A second send of the same word.** One approval, one send.

### Owed, and deliberately not built here
- **Gná's send path stays owed to plan 116 (P1: drafts and approvals on the same gate).** `bin/mail/` has no
  send verb, `tests/test_gna.py::NoSendCapability` fails if one appears, and `bin/mail/README.md` says so.
  When her draft verb lands it must call `snotra-approve.sh gate mail` like every other door — never a socket
  of her own.
- The approval record lives in one seat's XDG state; plan 126 sorts which artefacts must ride the vault. Not
  changed here.

### Measured on the real seat, after the change

```
$ bin/time/snotra/mail-send.sh status        → gmail   ready
$ bin/time/snotra/calendar-invite.sh status  → calendar_write   ready
$ bin/time/snotra/snotra-approve.sh list
GONE    mail  r-5050758689714317056  (the subject no longer exists — already sent or discarded)
… seven records, every one GONE: their drafts were sent or discarded days ago, and none of them can now be
  re-released, which is the single-use law doing its work retroactively
```

The seven approvals on this seat were all written before the spending existed. They are readable, and none of
them can release anything: a draft that is gone cannot be hashed, and `verdict` refuses an unreadable subject
before it would ever reach a send socket.
