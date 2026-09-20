## sessrumnir · unversioned · 2026-09-13 — the carved cloth reaches the seat-hall (Sessrúmnir)

### Why
- **The landing's cloth is now the seat's own look.** Every semantic token in
  `apps/sessrumnir/src/renderer/src/index.css` `@theme` was mapped to its carved
  twin from the landing page's `:root` (`CodeP/ymir-homepage/src/lore.html`):
  stone `#0e0c09` (app) with panels `#151209`/`#1a1610`/`#14100b`, bone text
  `#cfc3a9`/`#9a8f75`/`#6b6250` (faint/ghost as bone washes), bronze
  `#c9973f` accent and `#7d5f2a` brass rule for `border-strong`, blood
  `#c2584a`/`#7c3a30` for error, steel `#96a0a8` for success. Semantic names are
  unchanged — only the values moved.
- **Fensalir** (the weaving halls) is registered as a built-in theme
  (`themes/fensalir.json`, id `fensalir`, appended to `BUILTIN_THEME_IDS` — an
  additive change that keeps every persisted id resolving). The seat's own
  built-in `sessrumnir` theme was carved to the same cloth, so the default look
  of an existing profile is the cloth on restart. A new test holds the two
  together (`the cloth is one`) and another holds the CSS `@theme` base to the
  theme file (`never drift`).
- **Cloth is the default, not a cage:** the ThemeEngine's ordering is untouched —
  every other built-in theme, any user theme, and `high-contrast` still win when
  chosen.
- **Type:** Cormorant (display), Newsreader (body), IBM Plex Mono (mono) bundled
  from `@fontsource*` (offline, `font-src 'self'`), with Inter/JetBrains Mono
  kept as

### Files
- *(carried from the frozen CHANGELOG.md)*
