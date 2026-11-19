# The worktree follows the project, not the pin

**Date:** 2026-11-19 · **Component:** agents · **Doors:** `bin/agents/einherjar-spawn.sh`,
`src/ymir_runtime/paths.py` (`project_wt_root`), `src/ymir_runtime/seat.py`

## What was wrong

`bin/agents/einherjar-spawn.sh <id> ~/ymir`, run from the release pin, cut its worktree at
`~/ymir-runtime/.yggdrasil/<id>` and then refused itself with "exists but is not the expected worktree
root". The worktree root was `$BROKK_HOME/.yggdrasil`, and `BROKK_HOME` defaults to the door's own root. When the
door runs from the pin, that root is the pin. The engine road did the same through `paths.brokk_home`.

## What was forged

- The worktree root follows the **project** argument: the project's main checkout plus `.yggdrasil`. A project
  given as a linked worktree resolves to its main checkout, so worktrees never nest.
- `BROKK_WT_ROOT` still overrides, and the shell road hands its resolved root to the engine, so both roads agree.
- The engine resolves the same way through `paths.project_wt_root`.
- The "expected worktree root" test compares physical paths, so a symlinked project path cannot refuse a real
  worktree.
- The pin stays the runtime. Nothing moved into or out of it.

## Proof (measured)

A dry run with the pin as `BROKK_HOME`, from the pin's own door and then from this branch's door:

```
--- door: ~/ymir-runtime
worktree=~/ymir-runtime/.yggdrasil/ymir-faults
--- door: ~/ymir/.yggdrasil/ymir-faults
worktree=~/ymir/.yggdrasil/ymir-faults
```

The engine, on a scratch project with a scratch pin as `BROKK_HOME`:

```
wt_root …/f2.9BTG/proj/.yggdrasil
created …/f2.9BTG/proj/.yggdrasil/probe-id
reused  …/f2.9BTG/proj/.yggdrasil/probe-id
a linked worktree resolves to its main checkout: …/f2.9BTG/proj/.yggdrasil
pin holds: []
```

`python3 -m unittest` over `test_paths`, `test_worktree`, `test_lifecycle` and `test_dispatch` ran 68 tests. The two
errors are in `test_dispatch` (`bin/model-resolve.sh` is absent, the door now lives at `bin/model/model-resolve.sh`);
they do not touch this change.

A live launch from the pin was not run: it would seat a second worker beside this batch. The first live spawn from the
pin after release is the remaining proof.

## CHANGE LOG

- **2026-11-19** — written with the change it describes.
