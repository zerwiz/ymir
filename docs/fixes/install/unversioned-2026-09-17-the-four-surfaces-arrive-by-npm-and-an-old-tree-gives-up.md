## install · unversioned · 2026-09-17 — the four surfaces arrive by npm, and an old tree gives up what it holds

### Why
- **The app packages arrive with the distro.** `@zerwiz/ymir` now depends on the
  surfaces as their own packages — `@zerwiz/hlidskjalf`, `@zerwiz/odrerir`,
  `@zerwiz/sessrumnir` (live on the registry) and `@zerwiz/smiddja` (published at
  0.1.0 today). They are **optionalDependencies**, deliberately: a broken app
  package must never stop the core from installing, and a package not yet on the
  registry is skipped by npm and starts arriving the moment it is published.
  **Proven**: a global install from the packed tarball lands the core plus all
  three live apps, 330 packages, and the bin answers `0.1.6`. A local install
  hoists them to `node_modules/@zerwiz/<app>`; a global one nests them under the
  distro's own `node_modules` — the plan checks both shapes.
- **The plan tells the shapes apart.** "Declared as a dependency but not fetched"
  is a `DO`; "no package and no dependency" is a `BLOCKED`. All four surfaces read
  `DO` on a machine that has the distro but not yet the apps.
- **Migration 0005 — the operator's things leave the code tree.** It carries this
  machine's records, the runtime state (pids · logs · locks · the applied-marker),
  the operator's credentials, and the settings git does not track. Run on the
  Allfather's machine: **44 carried, 3 stale twins kept, 1 identical duplicate
  removed, 0 refused** — the tree left holding `.gitkeep` and the distro's ow

### Files
- *(carried from the frozen CHANGELOG.md)*
