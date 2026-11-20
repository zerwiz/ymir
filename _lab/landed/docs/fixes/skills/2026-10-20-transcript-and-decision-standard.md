## skills · unversioned · 2026-10-20 — transcript and decision standard

### What

- The renderer writes `transcript.md`: every segment in order, with its timestamp and
  speaker, beside the curated record. The record is the reading; the transcript is the
  evidence.
- The decision log now carries the standard it is judged by — one sentence, one decider,
  a reason, a reversal cost, options ruled out, a witness, a next look, and dissent when
  there is any.
- Optional fields `impact`, `alternatives`, `options`, `tradeoffs`, `benefits`,
  `dissent`, `authority_limit` are accepted by the schema and rendered, never invented.

### Verified

- Synteon pilot: 10 documents, including `transcript.md` at 139 KB; the decision
  standard prints at the top of `decisions.md`.

### Not verified

- No extraction of `options`/`dissent` from the transcript yet; the fields render only
  when a review supplies them.
