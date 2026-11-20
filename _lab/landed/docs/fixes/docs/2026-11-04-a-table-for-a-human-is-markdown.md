## docs · 2026-11-04 — a table that is the answer is written for the eye, not for a parser

### Why
His word: *"make the tables human readable."* The card catalogue had been built from dense `cards[16]{…}` TOON rows —
correct for a gate, unreadable for the man deciding what to buy. RULES/38 banned column tables in his replies; it said
nothing about a document where a table genuinely is the right shape.

### Mend
Appended to `RULES/38-the-answer.md`: a document is not a reply; when a table is the answer it is Markdown with a
header row and a heading; `key[n]{…}` shapes stay machine-facing; and the test is one glance — if he must decode a
schema to find a price, the table is wrong.

### Proven
`hodd/docs/machines/the-card-catalogue.md` rewritten from three TOON blocks into three Markdown tables with units in
the headers, a verdict column, and one plain paragraph under each saying what it means.

## CHANGE LOG

- **2026-11-09** — the note was carried into the integration branch whole, its history with it.
