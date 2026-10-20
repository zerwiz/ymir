## snotra · unversioned · 2026-10-20 — the meeting can be invited and mailed

### What

Two write doors, each with its own grant and its own audit line:

- `bin/time/snotra/google-auth.sh` — one consent for `calendar.events`,
  `gmail.send`, `gmail.compose`, `gmail.readonly`; stores
  `SNOTRA_GOOGLE_REFRESH_TOKEN` in the vault.
- `bin/time/snotra/calendar-invite.sh` — `create|cancel|status`; attendees, Meet link
  (`conferenceDataVersion=1`), `sendUpdates=all`, record id in extended properties.
- `bin/time/snotra/mail-send.sh` — MIME with attachments → Gmail **draft**, and
  `send <draft-id>` through `gmail.send` after approval.

Mánagandr stays read-only; the write grant is separate.

### Verified

- Consent stored; `calendar-invite.sh status` → `calendar_write ready`.
- Created a real event `Snotra test invitation` with a Meet link
  (`meet.google.com/zsn-zmsg-poy`) and an invite to the operator; cancelled it.
- Created a real Gmail draft with `minutes.md`, `decisions.md`, `actions.md` attached,
  then sent it to the operator (`gmail sent 1a15a490aadba666`).

### Not verified

- No attendee list from a record yet — attendees are passed explicitly (the pilot
  record has no partner emails).
- No approval UI: approval is the explicit `send <draft-id>` call.
- Sending to partners was not exercised; only to the operator.
