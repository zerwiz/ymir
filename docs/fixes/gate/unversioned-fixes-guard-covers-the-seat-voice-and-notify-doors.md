## gate · unversioned · 2026-11-18 — fixes-guard covers the seat, voice and notify doors again

### Why
PR 814 added a row to `bin/gates/guards/fixes-guard.sh` so a fix note can cover `bin/seat/*`, `bin/voice/*`, the unit register and `bin/notify/*`. PR 818 gathered 814 and kept main's copy of that file where the two clashed, so the row was lost. Without it a correct push that touches `bin/seat/` is refused: the path maps to no component.

### Files
- `bin/gates/guards/fixes-guard.sh`
- `docs/fixes/gate/unversioned-fixes-guard-covers-the-seat-voice-and-notify-doors.md`

### What
Restored the one row (`bin/seat/*|bin/voice/*|bin/engine/units.sh|bin/engine/units.py|config/units.yaml` → `runtime`, and `bin/notify/*` → `notify`). Main's own `deploy/*` and `dispatch` rows are kept as they are; only the lost row came back.

### Verified
`bash -n` is clean and the diff is the added row only. The ward judges this very push, which touches `bin/seat/`.

## CHANGE LOG

- **2026-11-18** — opened.
