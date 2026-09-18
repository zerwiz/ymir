## hoard · unversioned · 2026-09-16 — every app wears its own rune

### Why
The icon set is runecoded (`midgard/design-system/icons.md`): an Elder Futhark
rune, stroked at the chisel bevel, tinted by the app's house colour. The apps were
wearing the generic Ymir mark — or, worse, the old **blue** logo.

- **`bin/design-icon.sh`** mints an app's icon from a glyph plus a house tint: a
  stone tile with the rune stroked in bronze. `list` shows the mapping.
- Minted and wired: **Hlidskjalf** `ehwaz` ᛖ (the seat), **Óðrerir** `valhalla` ᚹ
  (the hall), **Sessrúmnir** `sowilo` ᛊ (the sun), **Smíðja** `ansuz` ᚨ (Odin's
  breath — the forge). Óðrerir already carried a forge-coloured favicon set.
- **The blue logo is retired**: `public/logo.svg` removed, and Smíðja's *inline*
  copy in `App.vue` — the mark in its own header, still `#0f172a`/`#1e293b` —
  replaced with the ansuz rune in bronze. Rebuilt; no blue in the bundle.

### The hearth stays, and spreads

Sessrúmnir's background fire is **`EmberBackground`** — 26 embers rising with a
gentle sway on a canvas, *"the hearth of the landing page, carried into the
chat"* — used by its home screen and chat panel. It stays. Next: one shared
ember (a framework-neutral `midgard/design-system/ember.js` with a
`prefers-reduced-motion` guard) so Hlidskjalf's shell, the login screen,
Óðrerir's hall and the Smíðja chrome can warm the same fire.

### Files
- *(carried from the frozen CHANGELOG.md)*
