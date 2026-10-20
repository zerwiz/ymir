## snotra · unversioned · 2026-10-20 — the letter reads like a letter

### What

The follow-up is now **generated from the record**, not hand-written:
`snotra-render-email.sh <meeting-dir>` writes `email.md` and `email.html`.

- The HTML is a designed letter: company band, meeting title, date and attendees, the
  decisions with their deciders, a "who does what" count per person, attachment chips,
  the two questions in a bordered box, and the signature with disclosure.
- The copy no longer explains our internal naming ("not minutes in the old sense").
  The recipients never knew that discussion; the letter simply says what the record is.
- The greeting excludes the sender. It reads the sender from the record.

The decision log also gained the fields the research names as necessary: **options
considered, trade-offs accepted, expected benefit, dissent, and what the decision does
not authorise**. The standard now has eight tests, not six.

### Verified

- Rendered preview inspected at 760×1500; layout is one column, no overflow.
- Test message `1a15a8e56c6d767d`: HTML body and 10 attachments, including the PDF and
  the raw transcript.

### Not verified

- No phone-client test of the HTML.
- Existing decisions have no `options`/`dissent`; the fields are rendered only when the
  transcript supports them, never invented.
