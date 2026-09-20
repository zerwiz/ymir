## runtime · unversioned · 2026-09-12 — Fleet preferences

### Why
- `data/fleet.md` (gitignored) holds fleet-wide per-user settings (`ro: on|off`).
- `bin/fleet-apply.sh` applies them to this home + every registered Eindri-home
  (into each home's gitignored `state/`; remote routes reported).
- `bin/brokk-update.sh` re-applies fleet preferences on every sweep — one setting
  reaches the whole fleet, no tracked tree dirtied.

### Files
- *(carried from the frozen CHANGELOG.md)*
