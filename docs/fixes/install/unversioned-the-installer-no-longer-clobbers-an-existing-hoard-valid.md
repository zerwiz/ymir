## install · unversioned · 2026-10-17 — the installer no longer clobbers an existing hoard; validate respects the role

### Why
On a fresh clone migration 0003 re-ran and overwrote the hoard's .gitignore (dropping hodd/secrets/ and .env*) and .ymir-layout.yaml; validate FAILed a hand on services it does not own.

### Files
- `bin/engine/ymir-install.sh`
- `bin/engine/ymir-validate.sh`
- `.agents/migrations/0003-private-data-separation.sh`