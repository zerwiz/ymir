## sessrumnir · unversioned · 2026-09-13 — Sessrúmnir, the seat-hall

### Why
- **Sessrúmnir adopted:** the Apache-2.0 **pi-desktop** GUI
  (`FaqFirebase/pi-desktop`, v0.1.7-alpha) is vendored at `apps/sessrumnir/`
  and rebranded **Sessrúmnir** — the seat-hall where the Allfather converses
  with the machine. The external engine keeps its product name; the GUI the
  user sees is Sessrúmnir, themed with the way-of palette (sky `#38bdf8` on
  deep navy) as the new default built-in theme. Window titles, launcher,
  package identity, tray/autostart strings, data-dir name, and the Pi logo
  (now a Sowilo rune bolt) are rebranded; upstream `LICENSE` is preserved and
  `NOTICE` records the adoption.
- **Forge scripts:** `bin/sessrumnir-ensure.sh` (status/ensure/install — deps
  are never committed, installed on first run with the electron-binary heal
  `scripts/electron.sh` already uses) and `bin/sessrumnir.sh`
  (start/status/stop with a workspace argument).
- **Install wiring:** `bin/ymir-install.sh` gains a `sessrumnir` step (after
  `hermes`) and lists Sessrúmnir in `workspace/INSTALL.md`; the
  `installation.md` asset's step table, adopted-engines table, and Hermes-style
  section are updated in the same change.
- **Registry & audit:** the Hoard registry (`hodd/identity/projects.yaml`)
  gains the `sessrumnir` project (upstream remote); the adoption is inscribed
  in Runes.
- **Not yet installed:** `apps/sessrumnir/node_modules` is absent — run
  `bin/ses

### Files
- *(carried from the frozen CHANGELOG.md)*
