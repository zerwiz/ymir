## gate · unversioned · 2026-09-30 — one machine's paths shipped to every clone

### Why
Two hardcoded path defects reached `main`, and the ward that exists for exactly
this never saw either:

1. **`state` was a tracked symlink** to `$HOME_SEAT/Documents/ymirhome/state`
   (blob `e93a784`, mode `120000`). Every clone on every other machine inherited a
   dead link. It was invisible in review because a symlink's content is its target
   in the index, and `bin/defaults-guard.sh` read file *content* — it was
   structurally blind to the class. It also violated the tree's own stated law:
   `scripts/electron.sh` says *"Never mkdir `$ROOT/state` — that is the drift the
   plan's purity row names"*, and `bin/ymir-plan.sh:165` counts a non-empty
   `$ROOT/state` as that drift. A dangling link cannot even be counted.
2. **`tools/mill/worker.sh` carried three absolute paths** (`$HOME_SEAT/mill/vector-index.jsonl`,
   `$HOME_SEAT/ymir` twice) plus `~/ymir/bin/hodd.sh` and `~/Documents/ymirhome`.
   The ward's scope was `bin/` and `.agents/` only, so `tools/` was never scanned:
   guarding the doors and not the yard.

The escape hatch was already in `.gitignore` — and useless. The rule read
`state/*`, and `state/*` **cannot match a symlink named `state`**. The ignore was
right in intent and blind in fact, which is why the link could be added at all.

The cost was concrete: `.agents/tests/smoke.test.sh` pointed
`BROKK_STATE_OVERRIDE` at `$ROOT/state` and did `touch "$STATE/smoke.signal"` with
**no `mkdir`** — so the smoke test only ever passed on the seat whose home the link
named. Everywhere else the touch failed into a green run.

### What
- **`.gitignore`** — `/state`, replacing `state/*` + `!state/.gitkeep`. The rule now
  covers the path *itself*, which is the only shape that stops a link named `state`.
- **the tracked symlink is untracked and removed.** A clone starts with no `state/`,
  and every writer creates its own — `bin/journal-append.sh:93` and the rest already
  `mkdir -p` the resolved dir.
- **`tools/mill/worker.sh`** resolves `MILL_HOME`, `WELL_VENV`, `YMIR_ROOT` (from
  `${BASH_SOURCE}`, not a remembered clone), `VECTOR_INDEX` and `PIPER_MODEL` from
  env with one documented default each, and takes the vector index into python as an
  **argument** instead of a literal. Fixing that also caught a latent bug: the
  replacement landed on `sys.argv[1]` (the query vector) rather than `argv[2]`.
- **`bin/defaults-guard.sh` 1.0.0 → 1.1.0**, now three classes:
  - a guessed default — the pattern is **general** (`/home/<seat>/`, `/Users/<seat>/`),
    not only a known subdirectory, and deliberately still ignores system prefixes
    (`/opt/homebrew`, `/usr/local/cuda`) — Rule 05 owns those;
  - a file that uses the home without resolving it (unchanged);
  - **a tracked symlink whose target is absolute** — the new pass, reading the index.
- **scope widened** to `bin/ .agents/ tools/ scripts/ src/`, with test fixtures
  exempt (a test *must* name a synthetic home).
- **the home default is defined once.** `lock.py` and `rail.py` each restated
  `DEFAULT_HOME = "~/Documents/ymirhome"` with no import, and `runes.py` inlined a
  third copy — all three now read `ymir_runtime/paths.py`, which joins
  `bin/hoard-lib.sh` in the allowlist as the Python twin of the one definition.
- **a ward defect found by widening**: the ward skipped `#` comments but not `//`,
  so a JavaScript comment quoting a path read as a finding.
- **`.agents/tests/smoke.test.sh`** owns its state in a `mktemp` dir instead of
  pointing at the tree.

### The proofs (run, not asserted)
- `bash bin/defaults-guard.sh check` — **exit 0**, all three sections `"none"`, over
  the widened scope.
- **Planted violations, caught:** a forced absolute symlink
  (`git add -f state`) → `"absolute symlink ships a machine path","state","$HOME_SEAT/Documents/ymirhome/state"`,
  exit 1; a guessed seat path in `tools/` → `"a home guessed"`, exit 1; a relative
  in-tree link → allowed; a path quoted in a comment → not a finding.
- **Both defences proven in order**: a plain `git add state` is now refused by
  `.gitignore` ("paths are ignored … use -f"), and the ward catches the forced /
  merged / legacy path behind it.
- `.agents/tests/defaults-guard-seat-paths.test.sh` — **11 assertions, 0 failures**,
  planting its violations in a scratch repo so it never mutates the real index.
- `PYTHONPATH=src python3 -m unittest discover -s src/ymir_runtime/tests` —
  **297 tests, OK**.
- `bash .agents/tests/smoke.test.sh` — **8/8 OK**, including galdr compliance.
- `bash .agents/skills/galdr-ymirsystem/scripts/compliance-check.sh` — **16 checks,
  15 PASS**, the one `NOTE` being `state` (a worktree; the main tree's link is a
  pre-install note the install seats).
- `bash -n` clean on every changed shell file; the recall-rag cosine proved live
  against a scratch index (`sys.argv[1]` vector, `sys.argv[2]` index).

### Not claimed / next
- **The install still does not seat the link.** `compliance-check.sh` says "the
  install seats the Phase-0 link", but no `ln -s … state` exists anywhere in the
  repo. That claim is stale. Nothing breaks — `bin/hoard-lib.sh:87` resolves the
  state to `${YMIR_STATE_DIR:-$home/state}` and no caller *requires* `$ROOT/state`
  (the two `$ROOT/state` fallbacks in `eindri-review-spawn.sh` and `autoboot-lib.sh`
  are guarded existence probes that fall through to the canonical dir). Seating a
  per-machine link at install time is the honest fix for the stale claim and is a
  separate errand on `bin/ymir-install.sh`.
- **`lock.py` still duplicates four resolver functions** (`config_dir`,
  `recorded_home`, `ymir_home`, `repo_root`) that `paths.py` already owns. This
  change removed the duplicated *literal* — the hardcoded-path defect — and left the
  structural duplication alone; collapsing it is its own errand with its own parity
  proof.
- The other 50 tracked files that quote a machine path are `docs/fixes/` history
  (quotations the ward's comment rule already exempts), test fixtures, and
  `assets/reference/` — prose, not code.

### Files
- `.gitignore` · `state` (untracked, removed)
- `bin/defaults-guard.sh` (1.0.0 → 1.1.0)
- `tools/mill/worker.sh`
- `src/ymir_runtime/paths.py` (allowlisted definition site) ·
  `src/ymir_runtime/state/lock.py` · `src/ymir_runtime/state/runes.py` ·
  `src/ymir_runtime/fleet/rail.py`
- `.agents/tests/defaults-guard-seat-paths.test.sh` (new) ·
  `.agents/tests/smoke.test.sh`
- `.agents/skills/galdr-ymirsystem/assets/installation.md`