# The kit speaks plain, has profiles, and leaves no leftovers (1.7.0 → 2.0.0)

**2026-11-20 · component: collab**

## What was wrong

Measured on heimdall on 2026-11-20, after its disk filled and every worker stopped (plan 267, appended section):

| Fact | Number | What the kit did not catch |
|---|---|---|
| `/home` used | 927 G of 952 G | no disk floor before a worktree or a build |
| worktrees of one product repository | 117, 168 GB | no cap, no cleanup after merge, a full `bun install` per worktree |
| of those, merged and clean | 109 | `RULES/17` said *should be removed*; no tool removed one |
| with work nobody had pushed | 6 | no salvage: a dead worker's files were one `rm` from lost |
| `standardise.sh --apply` on that repository | moved the shared `core.hooksPath` | the repository's own hooks silently stopped running |
| the kit's own words | 31 files naming this house's figures and vocabulary | a client repository received our naming |
| container images | build storage full of old release builds | no rule for who builds, which tags stay, when a cache goes |

The operator's words: *"the ymir kit must be agnostic and professional"* · *"it should be an option of cores and more
languages"* · *"old yggdrasils and others must be pruned. all things that have been used must go away. we cannot fill
the computers with leftovers."*

## What was forged

Kit **2.0.0** (major: folder names and file names change for a plain repository):

- **One config, `project.yaml`**, rendered by `standardise.sh --apply` from a stack profile (`bin/collab/profiles/`:
  node, python, elixir, elixir-umbrella, monorepo, monorepo-bun-uv-mix) and never replaced once present. It declares
  the register, names, stack (links and never-shared outputs per part), languages, limits, container rules and the
  leftover classes. Read by `scripts/kit.py` — standard library only, with a small YAML-subset reader.
- **Plain register by default** (K-1/K-2): every installed file was rewritten in plain professional English; the kit
  installs `.worktrees/<id>` on `work/<id>`; `--register house` renders the same documents through
  `bin/collab/registers/house.tsv` and writes the house names into `project.yaml`. Renamed pieces:
  `the-workbench` skill, `scripts/notify.sh` (one declared notice command replaces the arm chain), the
  `docs/templates/project/` set. `KIT_SKIP_*` replaces the old guard override names.
- **The worktree lifecycle** (K-5…K-8, `RULES/17` rewritten): `new` refuses below the disk floor, over the leftover
  budget and past the cap (naming the oldest merged one), closes merged worktrees first, links dependency folders from
  the main tree and writes an owner/purpose/expiry record in the worktree's git folder. `done`, `gc` and `salvage`
  close what is safe and commit + push a dead worker's work as `WIP (worker gone): saved as found, not reviewed`
  before removal. Nothing with a process inside or work existing nowhere else is removed.
- **Leave no leftovers** (`RULES/24`): `prune.sh` judges nine declared classes — worktrees, merged branches, stale
  remote refs, caches in idle worktrees, scratch, test databases, the project's dangling images and old tags,
  dangling volumes, stopped containers — as a report, then `--apply`. `kit.sh doctor` refuses new work over a budget;
  the `post-merge` hook and `kit.sh merge <pr>` close merged worktrees; `kit.sh timer` prints or installs the daily
  prune; `kit.sh summary` reads the ledger (`.git/kit-ledger.jsonl`).
- **Hooks chain, never steal** (K-9): the installer records an existing `core.hooksPath` or real `.git/hooks` in
  `collab.hooks.previous`; every kit hook (plus pass-through hooks for `prepare-commit-msg`, `post-checkout`,
  `post-commit`, `post-rewrite`, `pre-rebase`) runs it afterwards through `scripts/hooks-chain.sh`, as it does the
  tracked folders in `project.yaml` `hooks.chain`. `--uninstall` restores the setting. A hook that calls back into
  the kit does not run it twice.
- **Languages** (K-4, `RULES/22`): the project tongue for commits (refused otherwise) and client tongues only in
  `client_paths` (reported or refused at the commit).
- **Containers** (K-10/K-11, `RULES/23`): `containers.sh` builds with labels under a one-build lock and the disk floor,
  keeps current + previous tags, and refuses any change on a product host unless the operator's deploy door sent it.
- **`check-host.sh`** (K-12): a read-only report of disk, worktrees per repository, containers, images; `--strict`.
- **Two roads** (K-13): `kit.py road` lets a push of documents and handoffs reach the default branch; code is refused
  there and named. An unknown file is code.
- **Upgrades without loss**: `kit-history.tsv` (every blob the kit has shipped) lets `standardise.sh` upgrade a file
  an older kit installed and the repository never changed, and report every changed file as local.

- **Start, stop, sweep, the stack switch and deploy** (added the same day at the operator's word): `work.sh start`
  refuses under the floor or over the budget and turns the app's dev stack on; `work.sh stop` runs the checks,
  commits, pushes, opens the pull request, stops the processes, ports and test databases the record tracks, and
  removes everything once merged (else "waiting for merge" with an expiry); `work.sh sweep` is the daily cleanup.
  `stack.sh` reads one per-machine manifest (`~/.config/collab-kit/stacks.yaml`) and never stops a `prod` piece.
  `deploy.sh` picks the storage driver from the filesystem (btrfs on btrfs — podman on one machine had lost its
  storage and fell back to overlay), takes the lock, builds labelled images, ships, runs the project's hook, keeps
  two tags and prints the rollback on any failure. `docs/how-we-work.md` is the one page.

## What was run

```
python3 bin/collab/tests/test_kit.py            → Ran 40 tests … OK (K-1…K-13, every leftover class, upgrade)
python3 bin/collab/tests/test_work.py           → Ran 12 tests … OK (start at low disk, stop after merge, deploy
                                                  keeps exactly two tags, btrfs driver, off refuses prod, off/on)
bash bin/collab/tests/test_collab.sh            → 28 passed, 0 failed
bash bin/gates/tests/test_areas_and_injection.sh → 19 passed · 0 failed
bash bin/gates/tests/test_maker_names.sh        → one failure, present on origin/main before this change
                                                  (the kit copy of maker-allow.txt lags the house copy)
```

The install into two product repositories, with their hooks and gates, is recorded in plan 267's Built section.
