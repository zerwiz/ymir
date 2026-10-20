## snotra · unversioned · 2026-10-20 — the assembly signs

### What

- `snotra-signoff.sh` — `init`, `record`, `ask`, `render`, `status`. It writes
  `signoffs.json` from the record and `signoff.md` for the humans, and drafts one
  sign-off request per pending participant.
- The follow-up letter now says how to sign: `confirm` or `objection: <what is wrong>`,
  and that the record becomes official when the Chair signs.
- The PDF carries the sign-off sheet.

### Why

The Þing framework separates the Chair (what was decided), the Secretary (whether the
record is true) and the Adjuster (whether it was tested). A record is signed for its
**accuracy**, not for agreement with the decision; Grade A needs everyone, Grade C
accepts silence.

### Verified

- Synteon pilot: sign-off initialised for 4 people and 10 decisions; state `draft`;
  `signoff.md` rendered; test message `1a15a9ccfec4ede5` carries 12 attachments.
- Team draft prepared, unsent: `r4113750804890987305`.

### Not verified

- No inbound reply parser yet; a confirm/objection is recorded by the Secretary with
  `snotra-signoff.sh record`.
- Grade B/A thresholds are written but not enforced by the tool; it approves only when
  every person is confirmed or abstained.
