## sessrumnir · unversioned · 2026-09-19 — one repo, step 2: the package ships what it builds

### Why
- `files[]` gains `apps/`; `@zerwiz/hlidskjalf`, `@zerwiz/odrerir` and `@zerwiz/sessrumnir`
  retire as dependencies (npm workspaces link them instead). The smithy stays a package:
  `apps/smidja` is Python and carries no manifest.
- `bin/app-build.sh` builds every in-tree app (wired as `prepack`), so a publish cannot
  carry an unbuilt surface — the fault class of 2026-09-18, an artefact published without
  the file it needed.
- Pack hygiene, measured on the real tarball: **154 MB → 31 MB**, `node_modules` 113 → 0,
  the fork's `fork/` directory gone. The first pack leaked the workspace's own
  `node_modules/electron/dist/` (154 MB) because a root `files[]` negation does not reach a
  nested workspace — hence explicit `!apps/*/node_modules/**`.
- Proven by unpacking: 856 files under `apps/`, the seat's built `out/`, hlidskjalf's and
  odrerir's `dist/`, `install.sh` and `bin/app-build.sh` all present.

### Files
- `bin/app-build.sh`
- `install.sh`
