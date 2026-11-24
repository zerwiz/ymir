# 2026-11-24 — the npm package carries what its symlinks point at, and builds only its own apps

Two defects found in the npm packaging audit.

## Symlinks were dropped

`npm pack` drops symlinks, and the tree has about 125 (`config -> .agents/config`, the harness agent
links). An installed package therefore had no `config/`, and `bin/apps/apps.sh list` failed on a missing
`config/app-repos.yaml`. About twenty scripts read `$ROOT/config/`, so the fix is made at pack time,
not in each reader.

- New `bin/forge/npm/pack-links.sh`: `stage` replaces each in-tree symlink with a real copy of its
  target, `restore` puts the links back from a manifest.
- `package.json`: `prepack` runs `app-build.sh` and then `stage`; new `postpack` runs `restore`, so a
  working tree is never left changed.
- `.gitignore` names the manifest, which exists only while `npm pack` runs.

## The app list was stale

`bin/desktop/app-build.sh` (the `prepack` build) still listed `odrerir`, `sessrumnir` and
`smidja-factory/apps/visualizer`. Those apps moved to their own repos; only `apps/hlidskjalf` stays in
this tree. The default list and its comments now say so.

## CHANGE LOG

- 2026-11-24 — review-mend: added missing heading for #923
