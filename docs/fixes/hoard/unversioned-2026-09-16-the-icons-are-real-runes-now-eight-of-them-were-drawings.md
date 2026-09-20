## hoard · unversioned · 2026-09-16 — the icons are real runes now (eight of them were drawings)

### Why
The Allfather looked at the icons and said what no check had: *"the icons must be
based on real runes."* He was right, and the fault was in the **glyph set**, not
just in the two icons I had minted.

`midgard/design-system/icons.md` claims every glyph is an Elder Futhark rune and
gives each its unicode. **Eight of the twenty-one files were drawings** — a hall
(`valhalla`, which Óðrerir was wearing), a horn, a shield, a spear, a well, a
squirrel, a gate, a world-tree. Replaced with the real runes their own rows
declare:

```
gjallarhorn ᚷ Gebo · gungnir ᚦ Thurisaz · heimdall ᚺ Hagall · mimirsbrunn ᛜ Ingwaz
ratatoskr ᛒ Berkanan · utgard ᚢ Uruz · valhalla ᚹ Wunjo · yggdrasil ᛃ Jera
```

Gungnir was claiming Gebo, which Gjallarhorn already holds, so it takes
**Thurisaz** (the thorn — the spear) and `icons.md` is corrected to match.

**Five apps, five different runes:** Hlidskjalf `ehwaz`, mobile `raidho` (the
road), Óðrerir `valhalla`→ now genuinely `ᚹ Wunjo`, Sessrúmnir `sowilo`, Smíðja
`kaunan` (the torch). The install table drives both mint and install now — it had
been guessing paths, which is why the Smíðja visualizer had been given
Hlidskjalf's icon.

Also this pass: the visualizer gained its furniture (description, canonical,
manifest, OG + Twitter), Óðrerir's Electron shell asks for a window icon, and the
apple-touch PNGs are rasterised (ImageMagick is present).

### Files
- *(carried from the frozen CHANGELOG.md)*
