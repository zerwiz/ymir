## sessrumnir · unversioned · 2026-09-17 — Sessrúmnir stops wearing Pi's clothes

### Why
- **The naming law, broken at the root.** Clicking the Sessrúmnir icon opened a
  window titled **Pi Desktop**: `apps/sessrumnir` is the Pi Desktop shell adopted
  whole, and its product name was still Pi's —
  `export const PI_DESKTOP_PRODUCT_NAME = 'Pi Desktop'` — rendered as the heading on
  the home screen, the sidebar and the chat panel. That is the title the Allfather
  saw, twice, on every launch.
- **Mended at the name:** `SESSRUMNIR_PRODUCT_NAME = 'Sessrúmnir'` (Odin's hall of
  many seats), the three rendering components walked, and the old constant kept as an
  alias so no unwalked import breaks. `tsc --noEmit` exit 0.
- **Still owed:** 1,255 English strings, **86 of them naming Pi** ("Pi is working",
  "Quit Pi Desktop", "Pi Desktop v{{latestVersion}} is available", "Start Pi/OMP
  before planning with Council"), and Pi's logo on the home screen. The locale is the
  one place they live — that pass is the order, not a patch.
- Also in the launcher this session: an icon click now raises THE SYSTEM (converge
  the service, reborn a windowless app, focus a live window), and `stop --view X`
  stops only X — the loop that killed every view is gone. The Hall's own outage had
  a cause: an Astro dev server on :4323 while the app waited on :4322.

### Files
- *(carried from the frozen CHANGELOG.md)*
