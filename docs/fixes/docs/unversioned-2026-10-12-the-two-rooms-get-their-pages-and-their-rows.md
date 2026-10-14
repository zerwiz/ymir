## docs · unversioned · 2026-10-12 — the two rooms get their pages and their rows (Gladsheim · Brimir)

### What

Rule 14 says a feature with no page is a feature no user can use. Two features were named
and designed this day — **Gladsheim** (the fleet room) and **Brimir** (the hall of
Allfathers) — and they had no user page. This adds both, and the `FEATURES.md` rows that
link them.

They are **not built yet**, so the catalogue does **not** claim they are: `FEATURES.md`
gains a clearly-marked **"Planned — named and designed, not yet built"** section, and each
page opens with a **planned** banner to be removed, later, *by a new entry citing this one*
(Rule 06).

### Verified

- Both pages exist and are linked from `FEATURES.md`; the links resolve inside `docs/features/`.
- The rows sit under **Planned**, never under "what Ymir does" — the catalogue does not lie.
- `grep -c '| — |' FEATURES.md` stays 0: every row links a page.

### Files

- `FEATURES.md`
- `docs/features/gladsheim-the-fleet-room.md`
- `docs/features/brimir-the-hall-of-allfathers.md`
