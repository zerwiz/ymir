## docs · unversioned · 2026-11-14 — the documents name roles, not people and machines

### Why

The repository is public and installed on strangers' machines. Plan 287 and plan 288 drew the line: the house's
**craft** lives here, the operator's **life** lives in his home. The first census of the agnostic audit found the
line crossed in `docs/` as well as in the code — a named person in a how-to's example, a client's name in a
meeting path, a machine's name in an architecture page, the operator's own mail domain in a runbook.

### What changed

Outside `docs/fixes/` (17 pages), every person, client, domain and machine is now a role or an invented example:
`Ada Lovelace` and `Grace Hopper` for people, `example.org` for a mail domain, `partner-a` for a peer, and the
fleet's roles — *the heart*, *the forge*, *a dev machine*, *a hand* — where a page had named a particular box. The
lore keeps its own words: the dwarf-halls are written `Niðavellir`, the Old Norse spelling, so the lore word stays
and the box that borrowed it is not named.

Inside `docs/fixes/` the notes are append-only (`RULES/06`), and the earlier decision stands: an old line is
corrected by a **dated entry**, never silently rewritten. Each affected note now carries the entry *Correction
2026-11-14 — the machine and person names above are roles*, which says what the names above are read as and repeats
none of them. One note is corrected beside itself instead of inside it: the note of 2026-09-22 in
`docs/fixes/install/` ends without a terminating newline, so an appended entry would re-publish its last line — a
machine user's name — as text this change added; its correction stands as its own dated entry in the same
directory, and that note's bytes are untouched. Whether the old lines are ever redacted is the Allfather's decision; this change does not make it.

### The proof

`bin/gates/agnostic-audit.sh` (branch `eindri/agnostic-audit`, plan 287 §8) over the whole tree, with the home's
deny list: **0 findings in `docs/` outside `docs/fixes/`** — down from 28. The 272 findings that remain are all
inside the fix notes, which is the append-only history this change is forbidden to rewrite. `bin/gates/fixes.sh
validate` reports 1208 notes valid, and the pre-push wards pass with only the three findings `main` already carries.

### What this does not do

- It does not redact a fix note, and it does not print a redacted name — the audit names the file and the list
  entry's position, never the word (`RULES/18`).
- It does not touch the other shelves: `bin/`, `apps/`, `systems/`, `.agents/` and `midgard/` still carry their own
  findings and belong to their own errands (plan 288 §4, steps 5 and 6).

## CHANGE LOG

- **2026-11-14** — Carved: the docs pages name roles and invented examples; 155 fix notes gained a dated correction
  that repeats no name, and the 2026-09-22 ward note is corrected beside itself so its bytes stay as they were.
