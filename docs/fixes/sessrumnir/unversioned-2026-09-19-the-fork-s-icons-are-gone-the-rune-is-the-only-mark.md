## sessrumnir · unversioned · 2026-09-19 — the fork's icons are gone; the rune is the only mark

### Why
- `apps/sessrumnir/resources/icons/` still carried the fork's icon set — charcoal blue
  `#36454F` with an orange dot — so every surface that read the app's own icons showed the
  old colours beside the brown/gold rune. Every size is regenerated from the rune glyph
  (`#0e0c09` / `#c9973f`), `icon.ico` is a real multi-size ICO again (written through PIL —
  ImageMagick's ICO delegate emitted a TGA), and the macOS-only `icon.icns` is removed.
- The Allfather's instruction: *"those should be deleted and only the new should be used."*

### Files
- `(see the body)`
