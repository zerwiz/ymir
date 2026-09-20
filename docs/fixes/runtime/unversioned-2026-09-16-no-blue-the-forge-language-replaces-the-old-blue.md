## runtime · unversioned · 2026-09-16 — NO BLUE: the forge language replaces the old blue

### Why
The blue had a name. It was the platform's own house tint, `--ymir-house-ymirlabs:
#38bdf8`, carried into every surface that wears Ymir's colours — the login, the
emblem, the realm data, the Smíðja chrome. The design doctrine (homepage repo,
`DESIGN-UNIFICATION-PLAN.md`) says the landing page **is** the language, and that
language is **forge**: stone ground (`#0e0c09`), bronze accent (`#c9973f`), bone
text (`#cfc3a9`).

- `midgard/design-system/tokens.css` — the house tint is bronze now, with the
  reason recorded in the token itself.
- The blue's footprints removed: `Emblem.tsx`, `state/store.ts`, `data/realms.ts`
  (Hlidskjalf), `style.css` (Smíðja visualizer), and Sessrúmnir's terminal accent
  fallback.
- Both built stylesheets rebuilt and verified: **zero blue** in the CSS the browser
  actually receives (`apps/hlidskjalf/dist`, the visualizer's `dist`).
- The visualizer's build was failing on my own earlier edit (unused imports left
  when I moved `repoRootOf` into `db.ts`) — fixed, so `bun run build` is green.

The canonical token home is answered by what already exists: `midgard/design-system/`
(tokens, icons, `ymir-mark.svg`, `icons.md`) — one source the apps import, so a
colour changes once.

### Files
- *(carried from the frozen CHANGELOG.md)*
