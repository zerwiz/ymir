## 2026-09-17 — the four surfaces arrive by npm, and an old tree gives up what it holds

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
  removed, 0 refused** — the tree left holding `.gitkeep` and the distro's own
  tracked defaults.
- **A collision is decided by evidence, never assumption.** Two files, one name:
  identical content means the tree's copy goes (the content is provably at home);
  different content means both are real, so the home's keeps the name and the
  tree's is carried beside it as `<name>.stale-<UTC>`. Never merged, never
  discarded. A template is not only `*.example` — `agents.machine.example.yaml`
  matched none of the old guards and was carried off as if it were the operator's;
  it is back, and the pattern now covers `*.example.*`.
- **The plan's `purity` row applies the same law.** A settings file git *tracks* is
  the distro's shipped default, not the operator's — and the check asks git about
  the real path, because the tree's `config` is a symlink into `.agents/config`
  and the index holds the real name. Asking about the link reported "untracked" and
  flagged the distro's own `cron.yaml`. It now reads: *nothing of the operator's is
  written into the code tree*.
- **`bin/npm-publish.sh --all` learns the smithy** — the registry maps `smidja` to
  `apps/smidja-factory`, so it is a publish target like any other app.
- **The smithy gets a front page.** `zerwiz/smidja`'s README was a three-line stub;
  it now says what Smíðja is, how to install it, how to run the visualizer on
  `:8437`, what the tree holds, and the shape of a run. The tarball also carries
  `LICENSE` and `NOTICE` — npm attaches the licence and the readme on its own, but
  **not the notice**.
