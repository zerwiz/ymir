# The catalogue entry took a neighbour's number

## What broke

`docs/features/_catalogue/entries/` is one file per entry, and the number in the file
name is the only thing that orders them. This branch added
`02-114-the-seat-audit.md`. PR **#752** was adding `02-114-hand-a-brief-to-a-worker.md`
and `02-115-…` at the same time.

Two entries with the same number are not a merge conflict — the files have different
names, so git merges both without a word — and the woven catalogue then carries both
rows in an order neither hand chose. The collision was found by the helm's audit of PR
#753, not by any gate.

## What changed

The entry is renumbered to `02-116-the-seat-audit.md`, and the catalogue is re-woven.
Nothing else moves: the page (`docs/features/the-seat-audit.md`) and the row's text are
unchanged.

Renumbered, not rewritten: the earlier commit stands, and this repair is its own commit
on the same branch (RULES/06 — a record is appended, never rewritten).

## Proof

- `bin/records/weave-features.sh --check` — the fragments still weave: 236 entries in
  7 sections.
- `bin/gates/guards.sh` — 10 changed paths judged, 0 ward failed, 3 findings inherited
  from main.
- `bin/gates/guards/branch-guard.sh --documents` names the catalogue as NOT a document,
  which is why this repair carries a note at all.

## Owed

Numbers are allocated by hand across branches, so the next entry claims a number nobody
else has published yet. A generator that assigned them would end the class, and it is not
this repair's to build.

## CHANGE LOG

- **2026-11-14** — written with the repair it describes.
