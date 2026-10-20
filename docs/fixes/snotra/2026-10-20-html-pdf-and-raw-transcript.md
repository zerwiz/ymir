## snotra · unversioned · 2026-10-20 — HTML, PDF, raw transcript, and the size limit

### What

- **HTML alternative.** `mail-send.sh --html FILE` adds a `text/html` alternative
  beside the plain text, so the letter renders as a page instead of a wall of text.
- **PDF of the record.** `snotra-render-pdf.sh <meeting-dir>` prints the record,
  decisions, actions, a dependency table and the briefs to one A4 PDF with Chromium.
- **Raw transcript.** The renderer now writes `transcript.md` — every segment in order,
  with the source timestamp and speaker — beside the curated record.
- **The write sizes.** A message with a PDF exceeded `MAX_ARG_STRLEN`, so both the raw
  MIME and the JSON payload are passed on stdin / through a temp file, never as argv.
- **The standards.** `decisions.md` now carries the six-test decision standard
  (one sentence, one decider, a reason, a reversal cost, a witness, a next look);
  `actions.md` carries the action standard. `impact` and `alternatives` are optional
  schema fields.
- **Attachment types** are taken from the filename, so a PDF is `application/pdf`.

### Verified

- Test message `1a15a8bd2a750f0c`: HTML body, **10 attachments** — `record.pdf`
  (`application/pdf`), `transcript.md`, `minutes.md`, `decisions.md`, `actions.md`,
  `dependency-map.md`, four person briefs; size ~584 KB.
- Four brief drafts regenerated with real bodies; draft snippet shows the brief text.
- Draft ids may lack the `r-` dash; the parser now accepts both.

### Not verified

- Phone rendering of `.md` attachments; HTML is the fallback for the letter itself.
- The PDF's Mermaid map is a table, not the diagram.
