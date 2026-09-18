## runtime · unversioned · 2026-09-17 — main is repaired, and the report wears the cloth

### Why
- **Main was broken and nobody had noticed.** A merge resolved by hand
  (`4dd7273`, from a parallel branch) kept *both* sides of a conflict in
  `bin/ymir-install.sh` and `scripts/start.sh`: a stray `<`, a duplicated step
  line, orphaned comments, an `if` with no `fi`. The installer could not parse at
  all — `bash -n` failed on main — and PR #53's merge carried the breakage
  forward. Both files are restored from the last revision that parses (`5b7fc66`),
  with the two fixes that revision predated re-applied: the `--phase` value is
  consumed, and `--yes | --non-interactive | --accept-all-defaults` are one thing.
  Every runtime script parses again; the installer's plan runs.
- **The lesson worth keeping:** a merge is not a place to guess. When both sides
  of a conflict are real, the resolution is a decision — and `bash -n` on every
  runtime script is cheap enough to be part of it.
- **The validate report wears the cloth** — the same rows rendered for the eye on
  stderr (marks, colour, and a verdict with the next step) while the TOON stays
  the data on stdout. It found real drift while it was being written: the SPA down
  on `:3888`, Nornir cron stopped, `sessrumnir`, `mcp` and `hoard` broken.
- **Eir watches the shells.** A new surface reports the desktop shells' runtime
  through `bin/electron-lib.sh` — a *partial* Electron runtime is exactly the
  quiet failure Eir e

### Files
- *(carried from the frozen CHANGELOG.md)*
