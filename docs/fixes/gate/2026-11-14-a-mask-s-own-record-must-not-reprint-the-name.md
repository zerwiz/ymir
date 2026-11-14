## gate · 2026-11-14 — a mask's own record must not reprint the name

### Why

The helm's audit of `eindri/kaia-to-volundr` found four added lines naming the seat a measurement was
taken on. They were fixed, and the fix note that recorded them printed the old wording in its
"before" column — so a second pass of the same audit counted four machine names again, this time
inside the record of the mask.

That is a rule for any sweep that masks a name, not a detail of one note: **the record of a mask must
be masked too.** A note that writes *"it used to say 'measured on \<the seat>'"* unmasks the name in
the only place a reader will look for it. The before-column says `<the seat>`, `<one user's home>`, or
`$HOME/...`, and the finding stands without it.

### What changed

- `docs/fixes/smidja/2026-11-14-the-proofs-name-the-machine-no-longer.md` — its "it said" column is
  masked (`<the seat>`, `<one user's home>`), with a line saying why the column is masked at all.
- Nothing else: no code, no behaviour, no test.

### Proof

- `git diff origin/main...HEAD`, added lines: **zero** lines naming the machine — a grep for the seat's
  own name over the `+` side returns nothing.
- The four lines the helm named remain fixed: the test's comment, the proof quote, the store path (now
  `$YMIR_HOME/smidja/smidja.db`) and the DevTools sentence all read as the agnostic law requires.

### How to check it next time

Run the audit against the added lines and treat the record's own quotation as added text — it is. A
mask that leaves one copy behind is not a mask.
