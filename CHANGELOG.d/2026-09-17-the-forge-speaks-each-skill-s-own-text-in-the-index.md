## 2026-09-17 — the Forge speaks: each skill's own text in the index

- **The Forge listed skills as bare names.** `Forge.tsx` rendered only
  `{s.name}` + the aett rune, while the live `/api/skills` index carries every
  skill's `description` (240-char truncation) — the data was there, the
  surface never showed it. The skill list items are now two-line cards: name +
  aett on the head row, the description beneath (`forge-item-desc`, dimmed
  until hover), scoped to the skill variant so the Eindri rows keep their
  side-by-side name+status shape.

galdr-reread: `.agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md` — the
Forge gate bullet (skill list shows name + aett + description).
