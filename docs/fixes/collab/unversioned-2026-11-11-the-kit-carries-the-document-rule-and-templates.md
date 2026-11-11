## collab · 1.5.0 · 2026-11-11 — the kit carries the document rule and a template shelf

### Why

The same fault as the house's (`docs/fixes/docs/unversioned-2026-11-11-a-document-is-written-for-a-person.md`). The
kit's own README and `docs/headers.md` were written in TOON blocks, and the kit gave a repository no template for any
document but a ticket. The Allfather asked for *"templates etc in the collab kit to use. find some and download them to
the kit"*, and for the same in the Bragi skill.

### What changed

- **`kit/RULES/20-documents-are-for-people.md`** (new): the kit's form of Ymir's Rule 52.
- **`kit/docs/templates/`** (new): the same shelf as `.agents/skills/bragi-documents/assets/templates/`, byte for byte.
  `standardise.sh --apply` copies it into every repository, as it copies every kit file.
- **`kit/README.md`** and **`kit/docs/headers.md`**: their TOON blocks are converted to Markdown tables. This is
  format only, and every cell is carried over. The README names the two new pieces and the count goes from nineteen to
  twenty-one.
- **`standardise.sh`** `VERSION` 1.4.0 → 1.5.0, with the dated comment.
- **`tests/test_collab.sh`** gains section 8. The kit's templates must match the skill's (`diff -r`), and the kit must
  carry `RULES/20`. Both pass.

### Not changed, and found

`tests/test_collab.sh`'s check *"a complete baton passes"* fails on `origin/main` before this change as well (21 passed,
1 failed there; 23 passed, 1 failed here). It is not touched by this change and is reported, not hidden.

### Files

- `bin/collab/kit/RULES/20-documents-are-for-people.md` · `bin/collab/kit/docs/templates/**`
- `bin/collab/kit/README.md` · `bin/collab/kit/docs/headers.md`
- `bin/collab/standardise.sh` · `bin/collab/tests/test_collab.sh`

## CHANGE LOG

- **2026-11-11** — Written at the Allfather's word: documents are for people — tables, Mermaid and callouts, never TOON.
