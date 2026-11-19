# hoard · unversioned · 2026-11-19 — the home shape every install gets: four shelves, a migration, a doctor, a master register, a gate

Plan 331, built end to end. The evidence is the 2026-11-19 home audit in the operator's home (`hodd/docs/audits/`).

## Why

On 2026-11-19 the operator corrected his own home by hand three times: the old `hodd/state` folder to `state/`,
the old `hodd/life` folder to `life/`, and the work topic of the old `hodd/workspaces` folder to `life/work/`.
None of that reached any other machine:

- the **template** (`hodd/.ymir-layout.yaml.example`, `hodd/AGENTS.example.md`, `bin/engine/home-seed.sh`,
  `bin/engine/ymir-install.sh`) still created the old shape, so every fresh install was born with the tangle;
- **no migration** moved an existing home;
- the **doctor** could not name the drift, because nothing said where `life/` belonged.

The audit measured one more fault. Within three minutes of the hand move, four supervisors (calendar,
context-left, garmr, notify) had recreated `hodd/state`. More than twenty scripts still write there. They were not
rewritten one by one; a one-cycle link carries them to the right shelf (plan 331.7).

## What

- **Migration `0026-life-and-state-out-of-hodd`** (new). It moves `hodd/life/*` to `life/`, `hodd/state/*` to
  `state/`, and `hodd/workspaces/<topic>/*` to `life/<topic>/` for the five topics. Tracked files move with
  `git mv` and untracked ones with `mv`.
  - It writes the record under `hodd/reference/moves/` **before** the first move.
  - It never overwrites: a clash is kept beside the original as `<name>.from-hodd`.
  - It prints one line per move and refuses to continue (exit 1) if the file count before and after differ.
  - It then links `hodd/life -> ../life` and `hodd/state -> ../state`, and git-ignores both links (per machine,
    never committed). It retries the link while a writer is still recreating the folder, and defers (exit 3)
    instead of failing.
  - Non-topic folders under `hodd/workspaces` are left for a person and named.
  - `--dry-run` names every move and touches nothing.
- **Migration `0008-home-layout` step 4 retired.** It sent `hodd/life/{work,marketing,meetings}` to
  `svartalfaheim/.inbox`, the opposite of plan 331. Through the new link it would also have emptied `life/work`.
  It is kept as a commented no-op.
- **The template.** `hodd/.ymir-layout.yaml.example` is version 2, with the four shelves and what each must never
  hold. It no longer has a `workspaces` key, and it no longer names the real private home repository (that was a
  private value in a public file; it is now taught as form only). `hodd/AGENTS.example.md` points at the YAML
  instead of drawing a tree. `home-seed.sh` creates `life/<topic>` and the two links, never `hodd/state` or
  `hodd/workspaces`. `ymir-install.sh` builds the operator's tree under `life/`, not a root `workspaces/`.
  `bin/bridge/ymir-plan.sh` and `bin/agents/research-round.sh` no longer recreate the root `workspaces/` that the
  operator deleted.
- **Eir's `hoard` surface** gained `hoard_refusals`, three refusals, each printed as `<path> · <rule>`:
  1. a runtime artefact in the record: a real `hodd/state`, or a `.pid`, `.sock`, `.lock`, `.lease`, `.woke` or
     `.launch.sh` file;
  2. the operator's material in the record: a real `hodd/life`, or a topic under `hodd/workspaces`;
  3. a layout key naming a path that does not exist. This now covers every key, not a fixed list of eight.

  The well's database files are not flagged. The older `hodd/life/work` check now runs only on a real folder, so
  the link never trips it.
- **The master register** `hodd/identity/home.yaml.example` (new; seeded through `.agents/home-contract.yaml`). It
  names every register, the shelf it governs, the layout version, the links and the retired paths.
- **Documents point at the YAML.** `AGENTS.md` gained a dated section correcting its Directory rules table. There
  is a new page, `docs/features/the-four-shelves.md`, with its catalogue row.
- **The gate** `bin/gates/guards/retired-path-guard.sh` (new). It refuses a NEW file naming `hodd/life/`,
  `hodd/state/` or `hodd/workspaces/`, by file and line.
  - It is seated in `.githooks/pre-commit` and in `hoard-guard.sh` for the home.
  - Exempt: migrations, fix notes, move records and `RULES/`. A single line may carry `retired-path-ok:`.

## Proof

- `bin/gates/tests/test_retired_path_guard.sh`: PASS. It covers new-file refusal by file:line, every retired
  shelf, an edited old file spared, waiver and exempt shelves, and range mode.
- Migration on a scratch old-shape home: 11 files before and 11 after, 6 moved, 3 clashes kept as `.from-hodd`, and
  one non-topic folder left and named. The second run said `nothing to do`.
- `hoard_refusals` on a scratch home: clean with the links and a well WAL file. Each deliberate stray (a `.pid`
  file, a topic under workspaces, a real `hodd/life`, a real `hodd/state`, a stale layout key) is named by path
  and rule.
- `home-contract-guard.sh`: none. `features-guard.sh`: none.
- **A fresh home** seeded into an empty folder has `life/<five topics>`, the two links (git-ignored), and no real
  `hodd/state` or `hodd/workspaces`. `hoard_refusals` returns none and `home-seed.sh --check` says complete. The
  first try found that the seed never made `smidja/` or `svartalfaheim/`, which its own layout map names, so
  refusal 3 fired on every fresh install. Both are now in the skeleton.
- **The live home (heimdall, 2026-11-20).** Run 1 counted 17,204 files before and after, merged 7 runtime files
  into `state/` (7 clashes kept as `.from-hodd`), and made both links. Run 2 found nothing to do. Within minutes
  garmr wrote `state/garmr/offset` through the link. Eir now names one real fault there, `hodd/saves/.sync.lock`.
- `test_eir_register` 19/19, `test_eir_mends` 5/5 and `test_eindri_bearings` 17/17 pass.

## Not done here

- Plan 331.5 (Gróa runs pending migrations after a fast-forward) was already true: `groa-update.sh` and
  `ymir-install.sh` call `ymir-migrate.sh apply`.
- Plan 331.6/331.8: the resolvers and the pass-by-pass rewrite of the ~36k old references. The link carries them
  for one cycle; the gate stops new ones.
- Retiring the links after one release cycle.
