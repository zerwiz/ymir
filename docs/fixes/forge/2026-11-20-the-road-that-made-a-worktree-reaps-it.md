# forge · 2026-11-20 — the road that made a worktree reaps it

## Files

- `bin/forge/worktree-reap.py` — new: the ledger (`record`), the dry run (`sweep`) and the reap (`sweep --apply`)
- `bin/forge/yggdrasil.sh` — `create` records the worktree it made (road and owner from the caller)
- `bin/forge/gather.sh` — the batch worktree is recorded under road `gather`, and the batch writes `done:` to its own status once its PR is open
- `bin/agents/einherjar-spawn.sh` — records the worktree it cuts
- `bin/agents/eindri-start.sh` — names itself as the road and the role as the owner for every worktree made below it
- `bin/agents/project-target.sh` — records a worktree it makes in another project's repository
- `bin/seat/herdr-run.sh` — records both its roads (a fresh `yggdrasil.sh create` and a re-attached branch)
- `src/ymir_runtime/seat.py` — the engine road records through the same door
- `bin/seat/seat-reap.sh` — `--sweep` reaps closed errands' worktrees after the seats close; `--list` shows the dry run
- `config/worktree-roots.yaml.example` — the shape of the exterior roots list kept in the home
- `tests/test_worktree_reap.py` — eleven fenced cases

## Why

On 2026-11-20 the root disk filled to 100 %. The largest single cost was 121 worker worktrees
in an exterior hands folder, 168 GiB, all made in four days and none removed (plan 336). Every
road that cut a worktree — the spawner, the seat road, the gather, the engine — made one and
walked away. Nothing recorded who made a tree or for which errand, so no sweep could say when it
was safe to go.

## Fix

One ledger and one reaper (plan 339.4):

- **Every road records.** A record holds the path, repository, branch, errand, owner and road,
  one JSON file per worktree under `$XDG_STATE_HOME/ymir/worktrees/`.
- **A closed errand loses its tree.** `done:` with the work merged into the default branch,
  parked on `refs/parked/<errand>`, or pushed to a remote branch: removed. `failed:`: held seven
  days from the moment it closed, then removed.
- **Branches are never deleted.** Only `git worktree remove`, never `--force`.
- **Never removed, only named:** a tree with uncommitted changes, a tree an agent stands in, the
  main checkout, a detached HEAD no ref holds, an errand still open or with no status at all.
  A bare shell standing in a reapable tree is closed first through `seat-reap.sh --shell`.
- **Exterior roads by configuration.** `$YMIR_HOME/config/worktree-roots.yaml` lists other
  folders of linked worktrees; the same reaper walks them, with rule `status` or `landed`.
- **Dry run first.** `sweep` alone removes nothing. `YMIR_WORKTREE_REAP=off` turns `--apply`
  into a dry run.

## Proof

`python3 tests/test_worktree_reap.py` — 11 tests, OK. Each one fences `HOME`, `YMIR_HOME`, the
ledger, the state shelf and the walked repository into a temporary directory.

The dry run on the dev machine, the day it was written: 27 trees walked, 1 would be reaped
(`home-triage`, closed done and merged), 8 named dirty and left alone, the rest open or held by
a live agent. Pointed at the exterior hands folder by a test config, it would reap the one
merged tree and named the dirty one. Nothing was removed by the proof.

The runtime suite (`python3 -m unittest discover -s src -t src`) shows the same 14 failures
before and after the change; none touches the seat road's new record.

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #840
