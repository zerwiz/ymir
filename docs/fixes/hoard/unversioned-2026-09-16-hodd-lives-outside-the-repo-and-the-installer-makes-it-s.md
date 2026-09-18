## hoard · unversioned · 2026-09-16 — Hodd lives outside the repo, and the installer makes it so

### Why
- **One resolver.** `bin/hoard-lib.sh` (`hoard_root`) is now the single answer to
  *where private data lives*: `$YMIR_HOARD`, else `$YMIR_HOME`, else
  `$HOME/Documents/Ymir` — never the checkout. Rule 07's one documented default,
  in one place.
- **The inward default is gone.** `bin/mimir-ingest.sh`, `bin/project-git.sh` and
  `bin/workspace-provision.sh` each fell back to `$ROOT/hodd`, so on a machine
  with neither `YMIR_HOARD` nor `YMIR_HOME` exported, memory ingest, the project
  registry and workspace provisioning wrote private data **inside the repo**.
  All three (plus `bin/hodd.sh` and the installer) now resolve through the lib.
- **The misplaced document is out.** `0003-private-data-separation.md`, which had
  come to rest in the repo at `hodd/docs/plans/`, now lives in the hoard at
  `$YMIR_HOME/docs/plans/`. The repo's `hodd/` holds exactly the guard, the
  README and `AGENTS.example.md` — Rule 04's scaffold set, and nothing else.
- **Installed, not assumed.** `bin/ymir-install.sh` step `tree` now raises the
  hoard layout *outside* the repo (`bin/hodd.sh init`) and seeds an empty
  `secrets/platform.env` (mode 0600), so `bin/hodd.sh emit secrets/platform.env`
  resolves on a fresh machine instead of failing with "not readable".
  `assets/installation.md` and `assets/memory-well.md` updated in the same change.

### Files
- *(carried from the frozen CHANGELOG.md)*
