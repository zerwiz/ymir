# The theme gallery — Sessrúmnir's own well

This is the in-app community gallery for Sessrúmnir, served from the ymir
monorepo itself (plan 39's fold: one tree, one well). The app fetches
`index.json` from

```
https://raw.githubusercontent.com/zerwiz/ymir/main/apps/sessrumnir/themes/index.json
```

(The raw URL is pinned in `src/main/theme-store.ts` as `GALLERY_RAW_BASE`.)

## The contract (what `index.json` must hold)

The gallery is a first-party directory whose `index.json` is an **array** of
entries:

```json
[
  {
    "name": "My Theme",
    "kind": "dark",
    "file": "themes/my-theme/theme.json",
    "author": "The Allfather",
    "description": "..."
  }
]
```

- `name` — a non-empty string shown in the gallery.
- `kind` — `dark` or `light`.
- `file` — a path **relative to this directory**, matching
  `themes/<slug>/theme.json` (folder form) or `themes/<slug>.json` (flat
  form). The install URL is built from `GALLERY_RAW_BASE` + `file`, never
  taken from the entry, so a bad entry can only point inside this directory.
- An optional `screenshot.png|jpg|webp` beside the theme file is shown in the
  preview. The install itself always re-fetches and re-validates the canonical
  `theme.json` — the index entry is only the browse card.

## Adding a theme

1. Write the theme under `themes/<slug>/theme.json` (or `themes/<slug>.json`).
2. Add an entry to `index.json` naming it.
3. Optional: drop in `themes/<slug>/screenshot.png`.

`theme.json` is validated by the same validator as any installed theme — a bad
file is refused at install even if the gallery card renders.