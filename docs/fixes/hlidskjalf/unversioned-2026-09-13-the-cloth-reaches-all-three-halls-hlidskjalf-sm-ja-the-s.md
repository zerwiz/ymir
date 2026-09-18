## hlidskjalf · unversioned · 2026-09-13 — the cloth reaches all three halls (Hlidskjalf · Smíðja · the seat)

### Why
- **One look, one source.** The carved cloth (the landing page's `:root`) now
  dresses every hall, each through its own thin adapter, and `docs/design.md`
  gained §0 *The cloth* plus the re-cut §4.1/§4.2 tables — the contract, not a
  wish. `midgard/design-system/tokens.css` keeps every `--ymir-*` **name** and
  changes only the values: stone `#0e0c09`/`#151209`/`#1a1610`/`#221d14`, bone
  text `#cfc3a9`/`#9a8f75`/`#6b6250`, bronze `#c9973f` accent with `#7d5f2a` as
  the brass rule, blood `#c2584a` danger, steel `#96a0a8` ok, brass bevel
  `inset 0 0 0 1px rgba(201,151,79,.12)`.
- **Type.** Cormorant (display), Newsreader (body), IBM Plex Mono (data) — the
  landing's three faces — with Noto Sans Runic appended to every stack so runes
  fall through to the rune family. Hlidskjalf loads them from Google Fonts; the
  visualizer bundles them from `@fontsource` (its `@fontsource/play` is gone).
- **Hlidskjalf:** 24 old-palette `rgba()` literals and every role hex in the
  stylesheets now read tokens (`color-mix(… var(--ymir-ok) …)`); workspace tints
  are cloth (work bronze, personal steel); the `HallsChooser` cards no longer name
  two tokens that never existed (`--ymir-line`/`--ymir-panel`); the login's GitHub
  button is a bone plate; the realm-tint fallbacks in `global.css` follow.
- **Smíðja's eye:** the default theme is **fensalir** (the titlebar toggle cycles
  fensalir →

### Files
- *(carried from the frozen CHANGELOG.md)*
