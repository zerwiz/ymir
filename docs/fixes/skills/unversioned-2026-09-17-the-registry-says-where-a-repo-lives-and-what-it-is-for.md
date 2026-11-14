## skills · unversioned · 2026-09-17 — the registry says where a repo lives and what it is for

### Why
- **A project entry can now name its machine.** `machine:` records the host
  where a checkout lives; `data/machines.md` holds the fleet (omarchy-1,
  zerwiz, zerwizserver live on the tailnet). A repo is no longer assumed to be
  on the box you happen to be standing on.
- **A project entry can now say what it is for.** `about:` is one plain
  sentence per repo. `bin/agents/project-git.sh list --field about` prints the whole
  inventory without opening the YAML.
- **`project-git.sh` resolves more of the block.** `--field` now accepts
  `machine`, `company`, `workspace` and `about` alongside the git fields, and
  non-git keys read from the project block rather than the `git:` line.
- **One registry, not two.** The live registry is `hodd/identity/projects.yaml`
  (what the runtime reads). A stale duplicate at `Documents/Ymir/identity/` had
  been drifting apart from it — different GitHub owners, different project sets
  — and is retired, with a backup kept in `hodd/state/`.

### Files
- *(carried from the frozen CHANGELOG.md)*

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: the fleet's always-on heart. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #758
