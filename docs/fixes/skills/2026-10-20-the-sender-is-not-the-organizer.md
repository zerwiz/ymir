## skills · unversioned · 2026-10-20 — the sender is not the organizer

### What

The follow-up email signed "Kind regards, Reygan Assareh" because it used
`meeting.organizer` — who ran the meeting — as the signature. The Allfather sends the
follow-up: **Lars-Josef Lindbom**. The record now carries `meeting.sender`, rendered in
the signature (falling back to organizer), and the schema allows it.

The pilot record was regenerated: participants and action owners use the full name
`Lars-Josef Lindbom`, and the per-person brief is `briefs/lars-josef-lindbom.md`.

### Verified

- Re-ran the pipeline on the 158-minute export: 6 decisions, 16 actions, 0 warnings.
- `followup-email.md` ends `Kind regards, Lars-Josef Lindbom`.
- Four briefs, one per participant, with the corrected slug.

### Not verified

- No test asserts the signature yet; add `sender` to the render test.
