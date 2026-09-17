## 2026-09-17 — the plan learns the smithy's package name, and the install forwards its flags

Two defects the first real end-to-end npm install surfaced — which is what an
end-to-end test is for.

- **A surface's name is not its package's name.** The plan looked for
  `apps/smidja` or `@zerwiz/smidja`, but npm serves the smithy as
  `@zerwiz/smidja-factory` — so the row read `BLOCKED` on a machine where the
  smithy was installed and standing. `app_dir`/`app_row` now take the surface
  name and the package name separately, and the row tells the truth: installed,
  with the visualizer's UI still to build (the tarball ships its source, never a
  stale build).
- **`ymir install --plan` forwarded only `--json`.** `--phase` and `--blocked`
  were dropped on the way through the installer's door, so `--blocked` answered
  *unknown flag*. Every plan flag is forwarded now.

**The install this came out of:** `npm install -g @zerwiz/ymir` from the registry
— `@zerwiz/ymir@0.1.7`, 331 packages, and all four surfaces
(`hlidskjalf` · `odrerir` · `sessrumnir` · `smidja-factory`) arrived inside the
distro. The tarball carries no memory store — the leak is closed in the artefact
as well as in the repo.
