## 2026-09-17 — the sweep, and the door that mends itself

- **A retired name is swept from the launcher.** `ymir-visualizer.desktop` and its
  icon pointed at a glyph nobody ships — a blank square for anyone who knew the old
  name. `design-icon.sh install` removes retired entries now (`ymir-visualizer`,
  and `ymir-hlidskjalf-mobile` where that app is not installed).
- **`ymir hlidskjalf` mends the Electron runtime itself.** npm gates install
  scripts by default, so a fresh install can build the web app perfectly and have
  no window. The door now runs the repair it used to *describe*
  (`npm install-scripts approve electron` + `npm rebuild electron`), and only then
  refuses — with both the manual command and the honest alternative
  (`ymir install --no-desktop`).
- **Two faults are provably in the app repos, not here** (recorded so nobody hunts
  them in Ymir again):
  - **the fourth hall** — the landing's list is a hardcoded SPA component
    (`HallsSwitcher`; the bundle says *"three halls of Ymir — one seat, three
    roofs"*), not data from the gate API. Óðrerir must be added in
    `zerwiz/hlidskjalf` and the SPA rebuilt.
  - **the ember glow** — the seat ships `emberBootTheme` in its built renderer but
    no themed cloth beside it; the house's framework-neutral
    `midgard/design-system/ember.js` exists precisely so every surface can share
    one fire, and the seat must be told to light it (`zerwiz/sessrumnir`).
