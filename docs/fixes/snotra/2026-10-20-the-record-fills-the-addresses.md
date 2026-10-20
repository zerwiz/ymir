## snotra · unversioned · 2026-10-20 — the record fills the addresses

### What

- `bin/time/snotra/calendar-attendees.sh` — reads **one** calendar event live (never the
  count-only cache) and prints `displayName, email, responseStatus`.
- `bin/time/snotra/participants-fill.sh` — matches those addresses into a record's
  `participants[].email`; unresolved names are reported, never guessed.
- `calendar-invite.sh --from-record` and `mail-send.sh --from-record` take the recipients
  from the record's filled participants instead of a typed list.
- `calendar-invite.sh` now accepts `Name <email>` attendees, so the calendar holds a
  display name as well as an address.

### Verified

- Created an event with `Lars-Josef Lindbom <josef@way-of.com>`; `participants-fill`
  filled the address; the event was cancelled.
- Created a Gmail draft with `--from-record`; recipients came from the record; the test
  draft was deleted.
- Earlier: real event with Meet link created/cancelled; real mail with three attachments
  sent to the operator.

### Not verified

- Partner addresses are not in the pilot record yet, so no partner-facing send.
- Matching uses name containment; a duplicate name is reported unresolved by design.
