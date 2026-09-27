## sessrumnir · unversioned · 2026-09-26 — the seat-hall is detached from the parent repo, 100%

### Why
Sessrúmnir is a vendored fork of `FaqFirebase/pi-desktop`, but every **actionable
thread** still pointed at the parent: the update check fetched the parent's
GitHub releases (so the app advertised v0.1.9-alpha, a parent build, over our
own 0.1.8-alpha); `install.sh` installed from the parent's repo; `package.json`
homepage/repository, `docs/index.html`, the README/CONTRIBUTING release and
clone roads, and the in-app theme gallery all drank from the parent. A fork
that advertises the upstream's builds is a door pointing the wrong way.

### What
- **`update-handlers.ts`** — the update check now drinks from **our own npm
  shelf**: `@zerwiz/sessrumnir`, following the `next` tag for prerelease builds
  and `latest` for stable, opening `npmjs.com/package/@zerwiz/sessrumnir` on
  Download. No GitHub, no parent. (Measured: our `next` = 0.1.8-alpha, so the
  app is current and the false banner dies; the parent's releases no longer
  speak for us.)
- **`install.sh`** — `REPO="zerwiz/ymir"`, binary `sessrumnir`, clone road into
  `apps/sessrumnir`.
- **`package.json`** — `homepage`/`repository` → `zerwiz/ymir`.
- **`.github/` templates** (bug_report, config, PR template, SUPPORT) and
  **CONTRIBUTING.md** — all roads → `zerwiz/ymir`.
- **`README.md` / `docs/index.html` / `bin/sessrumnir.js`** — releases, issues,
  clone and install roads → our repo; the clone blocks use the monorepo's
  sparse-checkout into `apps/sessrumnir`.
- **The theme gallery** — moved to **our own first-party gallery**:
  `GALLERY_RAW_BASE` → `raw.githubusercontent.com/zerwiz/ymir/main/apps/sessrumnir/themes`,
  with a scaffold (`themes/index.json` empty array + `themes/README.md`
  documenting the contract) so the in-app browse drinks from the fold.
- **Tests** — `theme-store.test.ts` gallery fixtures and the `git-conveyor`
  parser fixtures repointed to `zerwiz/ymir`; 63 tests pass, typecheck clean.

### Kept (the law)
`LICENSE`, `NOTICE`, the AGENTS.md adoption note, and README line 6's upstream
provenance stay — the fork record and the Apache-2.0 attribution are history,
not tracking.

### Files
- `apps/sessrumnir/src/main/ipc/update-handlers.ts`
- `apps/sessrumnir/src/main/theme-store.ts` · `theme-store.test.ts`
- `apps/sessrumnir/src/main/git-conveyor.test.ts`
- `apps/sessrumnir/install.sh` · `package.json` · `bin/sessrumnir.js`
- `apps/sessrumnir/README.md` · `CONTRIBUTING.md` · `docs/index.html`
- `apps/sessrumnir/.github/ISSUE_TEMPLATE/bug_report.yml` · `config.yml`
- `apps/sessrumnir/.github/PULL_REQUEST_TEMPLATE.md` · `SUPPORT.md`
- `apps/sessrumnir/themes/index.json` (new) · `apps/sessrumnir/themes/README.md` (new)