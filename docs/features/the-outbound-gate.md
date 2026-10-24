# The outbound gate — nothing leaves the house until you have read it

**What it is.** One door stands between the house and every person outside it: no email is sent and no calendar
invitation reaches an attendee until **you** have approved the exact words that will leave. The approval is
bound to the content itself, so editing a letter after approving it makes the approval void — not a warning,
a refusal.

**Why it exists.** On 2026-10-23 a letter about how the company runs meetings reached the partners without your
having seen it. Your word afterwards was *"I NEED TO APPROVE THE MAIL."* A gate was built that day, and on
2026-10-24 an audit found it standing in one door while three walked past it: the mail send verb never asked,
the calendar posted with `sendUpdates=all` so Google mailed guests the instant an event was made, and nobody had
written down that Gná (the mail desk) must never grow a send path of her own. All three are closed.

## What you need

- The house's Google grant in the vault (`SNOTRA_GOOGLE_REFRESH_TOKEN`, plus the client id and secret) — already
  there if the meeting letters work.
- The approval records live on **this seat**, outside git, in `$HOME/.local/state/ymir/approvals/` (or
  `$XDG_STATE_HOME`). Nothing to install.

## Do it — a letter

```bash
# 1. compose it. This creates a Gmail DRAFT and sends nothing.
bin/time/snotra/mail-send.sh draft --to partner@example.com --subject "OptiCat review" --body letter.md

#    the door answers:  draft   r-1234567890   /tmp/....eml

# 2. read it, then approve exactly those bytes
bin/time/snotra/snotra-approve.sh approve r-1234567890
#    → approved   mail   r-1234567890   fcd5507d…

# 3. send it
bin/time/snotra/mail-send.sh send r-1234567890
#    → sent   <message-id>
```

What you will see if the word is missing or no longer fits — and nothing is sent in either case:

```
NOT APPROVED — no approval record for r-1234567890; the operator approves with: snotra-approve.sh approve r-1234567890
STALE — the content changed after approval; approve it again
ALREADY SENT — this approval was spent at 2026-10-24T09:12:03Z; a second send needs a new word
```

## Do it — a calendar invitation

Google mails every attendee the moment an event is made, so the door mails **nobody** unless you approve.

```bash
# 1. ask for it. With attendees and no word, this REFUSES and posts nothing:
bin/time/snotra/calendar-invite.sh create --title "OptiCat review" \
    --start 2026-10-30T10:00:00 --end 2026-10-30T10:30:00 --attendees partner@example.com
#    → calendar-invite: REFUSED — nothing was posted and no attendee was mailed.
#      the body is held at …/approvals/pending/evt-2026_10_30T10_00_00.json
#      to release it: …/snotra-approve.sh approve-event evt-2026_10_30T10_00_00  &&  re-run this command

# 2. read the held body, approve it, then re-run the SAME command.
bin/time/snotra/snotra-approve.sh approve-event evt-2026_10_30T10_00_00

# 3. re-run step 1 → created … and mail all
```

An event with **no attendees** needs no approval and sends no mail (`sendUpdates=none`). Cancelling follows the
same law: `cancel <event-id>` mails nobody, and `cancel <event-id> --notify` needs its own approved body.

## See what is waiting, approved, stale or spent

```bash
bin/time/snotra/snotra-approve.sh list
#    OK      mail  r-1234567890
#    SENT    event evt-2026_10_30T10_00_00
#    STALE   mail  r-0987654321  (STALE — the content changed after approval; approve it again)
```

```bash
bin/time/snotra/snotra-approve.sh revoke <key>     # take the word back before it is used
```

## Prove it yourself

Each door carries its own proofs; they run against a local server, never your mailbox:

```bash
bin/time/snotra/mail-send.sh --self-test          # 4 proofs: refused · sent once · refused replay · stale
bin/time/snotra/calendar-invite.sh --self-test    # 6 proofs: no mail by default · approved only · stale · cancel
python3 bin/time/snotra/tests/test_outbound_gate.py   # all 12, including Gná's ward
```

## Notes & limits

- **One approval, one send.** After a successful send the record is marked spent. To send the same letter
  again, compose a new draft and approve it — the old id is dead by design.
- **Edits void the word.** Approving, then changing the body, subject, recipients or an attachment, reads as
  `STALE`; approve again.
- **A refusal is recorded.** Every refusal and every spend is carved into the Runes ledger, with the subject,
  the operator and the reason, so "what did we tell them, and on whose word" is answerable without reading mail.
- **The record is per seat.** An approval given on one machine is not on another (plan 126 sorts which records
  must travel). Approve on the seat that will send.
- **Gná has no send path and must not grow one.** Her drafts and approvals are owed to plan 116 (P1) and must
  come through this same gate. A test fails if a send verb appears in `bin/mail/`.

## If it does not work

- `error: google credentials missing` — the vault grant is missing on this seat: check
  `bin/time/snotra/calendar-invite.sh status` and `mail-send.sh status`.
- `ALREADY SENT` on the first send — the draft was already released once (by a letter run or the Hlidskjalf
  button). Compose a new draft; do not revoke to replay a stale one.
- `UNREADABLE — cannot read the current bytes` — Gmail could not return the draft: it was discarded, or the id
  is not a draft. `snotra-approve.sh list` shows what still exists.
- A calendar refusal you cannot clear — the held body tells you the key; approve that key, then re-run the
  **same** command. If you changed any flag since, approve the key again after the re-run.
