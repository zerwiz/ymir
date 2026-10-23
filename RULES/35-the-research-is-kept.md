# Rule 35 — what was learned outside is kept

> Adopted 2026-10-23, at the Allfather's word: *"everytime an agent do online research that research
> should be stored by folder structure and indexing with the sources in ymir home so we know what we
> learned."* Plan 115 §3 · the door is `bin/records/library.sh research …`.

## The law

1. **Every research episode an agent performs is kept**, in the home, by date, in one structure:

   ```
   $YMIR_HOME/hodd/library/research/<YYYY>/<MM>/<YYYY-MM-DD>-<slug>/
       note.md        question · finding · owner · route · tags, then the sources for a human
       sources.json   the same sources as data: url · title · kind · fetched
   $YMIR_HOME/hodd/library/research/INDEX.md      generated from the folders
   ```

2. **A finding with no source is an opinion.** `keep` refuses it (exit 1). The only exception is a
   **negative result** — what was looked for and *not* found, with the queries tried — because a
   dead end paid for once must not be paid for twice.

3. **The note is in our words, never the page pasted.** A library of pasted pages is a cache. The
   finding is the answer we reached; the sources are the evidence for it.

4. **The route is part of the record.** `route:` says how it was reached — a direct fetch of the
   primary source, a search index, a local file. A fact from a fetched primary source and one from a
   snippet are not the same confidence, and the reader must be able to tell.

5. **An episode is never rewritten.** A correction is a new episode that cites the old one.

6. **Nothing private enters the library** (Rule 15 wins): no vault content, no NDA material, no
   meeting audio or transcript. The library holds what can be read outside.

7. **The index is derived** (Rule 34 §3–4): `research index` renders it, and `research check` fails a
   hand-written or stale one.

## Why

Measured on the day it was adopted: `hodd/docs/research` held **1** file, `hodd/life/personal/research`
held **5**, there was no shelf, no index and no rule — and `bin/assistant/research.py` is deliberately
built so that *nothing fetched is ever learned*. That is correct for Skírnir's approved-facts digest
(he must not learn from the web) and wrong for the house: a search paid for once was paid for again,
and a claim in a PR had no source behind it.

## Enforcement

`bin/records/library.sh research check` — every episode carries a question, a finding, its header and
its sources; the index is current. `library.sh self-test` proves the refusals in a temp root (an
unsourced finding refused, an episode never rewritten, an emptied source list caught).
