## odrerir · unversioned · 2026-09-19 — the fourth rune raises the app, and the hall admits when it invents

### Why
- **ᛟ "To the Hall" opened a browser tab.** The three hall runes call `raise(id)` →
  `gateApi.desktop(id)`, which raises the Electron app; the fourth was an `<a
  href={HALL_URL} target="_blank">` pointing at `http://localhost:4322`. It is now a button
  on the same door: `raise` is exported from Halls, the union and the gate's `/api/desktop`
  accept `odrerir`, and `desktop()` on the client too. The build enforced every half of it.
- **Óðrerir's inline fallback told fiction as telemetry.** It renders an invented board
  ("The forge is lit · tended, never relit") when `/livehall.json` cannot be reached, with
  nothing marking it. It now states plainly: *"Not connected — this board is the saga's
  sample, not your fleet"*, and the marker is removed the moment a live feed arrives.

### Files
- `/livehall.json`
