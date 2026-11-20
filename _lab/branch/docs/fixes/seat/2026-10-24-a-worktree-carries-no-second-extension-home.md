## seat · unversioned · 2026-10-24 — a worktree carries no second extension home

### Files
- `bin/forge/yggdrasil.sh` (`create` — sparse exclusion of `.pi/extensions/`, verified before it reports success)
- `bin/seat/valknut-load.sh` (the worktree case in `--check`; new `--ext-home`)
- `.agents/tests/pi-extensions.test.sh` (section 8 — the hermetic proof and the guard)
- `bin/gates/fixes.sh` (`seat` joined the component list; the directory existed and the name did not)
- `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md` (the owning asset, appended)
- `RULES/13-pi-extensions.md` (appended — §10, the worktree clause)
- `docs/features/yggdrasil-and-utgard-isolation.md`, `FEATURES.md` (the how-to and its row)

### Why

A Yggdrasil worktree checks `.pi/extensions/` out like any other file, so a pi seat
inside it had **two trees carrying the same eighteen extensions**: the worktree's own
and the settings-named seat tree. pi's discovery is `<cwd>/.pi/extensions` then
`~/.pi/agent/extensions` then the settings `extensions[]`, and it de-duplicates on the
resolved path — two different absolute paths for the same code is two registrations.
Every tool name collided, pi refused **all** extensions and exited, and the dispatcher
typed the brief into the bare shell left behind. Four errands died that way
(`docs/fixes/agents/2026-10-24-the-errand-that-looked-alive.md`).

The spawn road was patched twice and backed out both times, because the fault was never
in the road: it was in the **checkout**. So the durable fix is at the place the tree is
made, and the gate that should have caught it learns the one case it could not name.

### The fault, reproduced (measured this seat, 2026-10-24)

`~/.pi/agent/settings.json` named the seat tree (`/home/heimdall/ymir/.pi/extensions`)
until 11:26 today; that is the state the fault needs. With it in place, a fresh worktree
of the old road carries its own copy:

```bash
cd .yggdrasil/<old-worktree>
ls .pi/extensions | wc -l        # 18 — the second home
pi --list-models                 # eighteen "Tool … conflicts with …" lines, then exit
```

`valknut-load.sh --check` run in that worktree said nothing about it: it asked "does the
project home hold extensions" — which was true twice over — and then compared settings
against the worktree's own path. Two homes read as one passing home.

### The fix

`bin/forge/yggdrasil.sh create` excludes the path by git's own mechanism, a
**per-worktree sparse-checkout with a non-cone pattern**:

```bash
git -C <worktree> sparse-checkout set --no-cone '/*' '!/.pi/extensions/'
```

git writes the pattern file and `core.sparseCheckout` into that worktree's own gitdir
(`.git/worktrees/<id>/config.worktree`, enabled by `extensions.worktreeConfig = true`
in the shared config — one additive line git itself sets, and the primary checkout and
every existing worktree are left exactly as they were). The files stay **tracked**; they
are simply not checked out, so the worktree is clean and nothing is deleted. That is why
a symlink was refused: a symlink shows as deleted tracked files and must not ship.

`create` verifies the outcome before it reports success — the path must be gone, and it
may not be a symlink — and returns a second TOON block naming the exclusion. An existing
worktree is never rewritten: a non-sparse one keeps working, reports `shared-copy` to the
gate, and the one-line repair is printed beside the verdict.

### The guard

`bin/seat/valknut-load.sh --check` now resolves **which tree serves this session**
(`pi_ext_resolve`, shared by `--check`, `--ext-home`, and the test):

```
own          this tree carries the extension home (the normal case)
absent       this tree carries none, and is NOT a worktree of the seated tree — FAIL
shared       a worktree of the seated repository with no copy of its own — ONE home
shared-link  that worktree points at the seat tree by symlink (works; sparse is shipped)
shared-copy  that worktree carries its OWN .pi/extensions — the fault, named with the repair
```

"Same repository" is asked of git (`rev-parse --git-common-dir` on both trees, both
canonical), never inferred from a path: a tree of a **different** repository is its own
home and must pass on its own terms.

`--ext-home` prints the answer so a human and a test ask the same door:

```
ext-home[1]{tree,state,seat_root,serving}:
  "…/.yggdrasil/sparse-proof/.pi/extensions","shared","/home/heimdall/ymir","/home/heimdall/ymir/.pi/extensions"
```

`.agents/tests/pi-extensions.test.sh` section 8 proves it hermetically — a scratch
repository of its own, the loader's documented `PI_EXT_HOME`/`PI_SETTINGS` overrides, no
touching of the seat the test runs from: the road produces a worktree with no copy, the
exclusion is sparse (status clean, pattern present, the seat's own tree untouched), the
worktree still resolves as its own tree, `--check` **passes** there, a real copy inside it
turns the state to `shared-copy` and `--check` **fails**, and removing the copy restores
one home.

### Proof, end to end (one uninterrupted run, from the errand's own worktree)

```bash
bin/forge/yggdrasil.sh create sparse-proof --base eindri/yggdrasil-seat
[ -e .yggdrasil/sparse-proof/.pi/extensions ] || echo ABSENT        # ABSENT
git -C .yggdrasil/sparse-proof status --porcelain                   # empty — sparse, nothing deleted
git -C .yggdrasil/sparse-proof sparse-checkout list                 # /*   !/.pi/extensions/
( cd .yggdrasil/sparse-proof && ./bin/seat/valknut-load.sh --ext-home )   # state: shared
( cd .yggdrasil/sparse-proof && ./bin/seat/valknut-load.sh --check )      # one home, no second tree
( cd .yggdrasil/sparse-proof && pi --list-models )                  # exit 0, 496 models, 0 bytes stderr
```

With the machine's settings drift set aside through the loader's own override
(`PI_SETTINGS=/tmp/settings-proof.json`, naming the seat tree) `--check` is a full
**PASS, exit 0** inside that worktree; with a genuine second copy dropped into it, the
same call **fails** and names the exact `sparse-checkout` repair. The throwaway worktree
was retired with `yggdrasil.sh cleanup`.

### Two things this does not claim

- **The settings drift is real and older than this note.** On this box
  `~/.pi/agent/settings.json` carries `extensions: ["-builtin:mcp"]` and no extension
  root (rewritten 11:26 today), so `--check` reports one FAIL in the **seat root too** —
  measured with `main`'s own unmodified loader, before this change. Minting that entry is
  `bin/seat/valknut-load.sh --pi`, a change to the running seat's global config and not an
  errand's to make. It is the reason the double-load fault is currently **latent** rather
  than absent, and it is what the gate is still reporting honestly.
- **~60 existing worktrees still carry their own copy.** They are not rewritten
  (`RULES` and the errand's own instruction: nothing a human is using). Every worktree made
  by `create` from now on is clean, `--check` names any that are not, and the repair is one
  line: `git -C <worktree> sparse-checkout set --no-cone '/*' '!/.pi/extensions/'`.

One more limit, named because it was found while proving this: `valknut-load.sh` finds the
tree root by walking up for `.pi` **and** `RULES`, so a tree whose `.pi/` held *only*
extensions would, once sparse-checked-out, no longer recognise its own worktree and would
resolve to the seat root instead. The real tree keeps `.pi/agents`, `.pi/shared` and
`.pi/mcp-adapter.json` there, so the walk is sound here; the test's fixture mirrors that
shape deliberately, and the walk is not changed by this fix.
