## runtime · unversioned · 2026-09-12 — Updater forged + credential moved to env

### Why
- **`bin/brokk-update.sh`** — the sanctioned, guarded updater the `ymir-update`
  skill calls: fast-forward only, refuses a dirty/diverged tree, `--yes` to
  stash+restore, `--check` to report. Never force-pushes.
- **Credential law:** the gate login (`HLIDSKJALF_AUTH`) no longer has an inline
  default; it is read from `.env.local` (Bun auto-loads it). Server falls back to
  an open gate only when unset (dev), with the key added to `.env.example`.

### Files
- *(carried from the frozen CHANGELOG.md)*
