# Runbook — worktrees and isolation

Every Eindri works in an **isolated Yggdrasil worktree**, never the main tree
(law *ygg1*). This keeps parallel workers from colliding and keeps your checkout
clean. Working in main is possible only when you ask for it.

## The rule

```
isolation[3]{road,default,opt_out}:
  "bin/eindri-start.sh \"<task>\"","secure worktree .yggdrasil/<id>","--main"
  "bin/pi-seat.sh --task \"<task>\"","secure worktree","--main"
  "bin/einherjar-spawn.sh <id>","secure worktree","—"
```

- **Default = isolated.** The dispatcher creates (or reuses) `.yggdrasil/<id>`
  and seats the agent there. If it cannot make a worktree it **refuses** to seat
  in main (`exit 4`) — it never silently falls back to your checkout.
- **`--main` = work in the main tree**, only when you deliberately want the agent
  to help in main:
  ```bash
  bin/eindri-start.sh "fix the typo in README" --main
  ```

## Managing worktrees

```bash
bin/yggdrasil.sh create <id>      # create .yggdrasil/<id> on branch yggdrasil/<id>
bin/yggdrasil.sh list             # every worktree: id · branch · path · head
bin/yggdrasil.sh status <id>      # one worktree's state
bin/yggdrasil.sh merge  <id>      # merge yggdrasil/<id> into main  (human-gated)
bin/yggdrasil.sh cleanup <id>     # remove the worktree after merge
```
A worktree lives at `<repo>/.yggdrasil/<id>/` on its own branch `yggdrasil/<id>`.

## Seeing them in Hlidskjalf

Open the **Worktrees** gate (rail). It reads `GET /api/worktrees` (backed by
`git worktree list`) and shows every tree:

```
Worktrees
id      branch             agent   head      path
bragi   yggdrasil/bragi    bragi   f709bb1   /home/…/Ymir/.yggdrasil/bragi
(main)  main               -       3283188   /home/…/Ymir
```

So the **Fleet** gate shows the agents and **Worktrees** shows the trees they
work in — including the artifact each produced.

## Bringing work home

The work does **not** auto-return. When an Eindri finishes:

1. Inspect it in the Worktrees gate (or `bin/yggdrasil.sh status <id>`).
2. **Merge on approval** (law 4 — human-gated):
   ```bash
   bin/yggdrasil.sh merge <id>
   ```
3. `bin/yggdrasil.sh cleanup <id>` once merged.

## Troubleshooting

- **`could not create a Yggdrasil worktree; refusing to seat`** — the worktree
  couldn't be made (usually already exists under a different state, or the repo
  isn't a git worktree). Check `bin/yggdrasil.sh list`; the seat **reuses** an
  existing `.yggdrasil/<id>`.
- **An agent wrote to `~/Ymir/...` (main)** — that was pre-isolation, or `--main`
  was passed. Check the Worktrees gate: an isolated run's files live under
  `.yggdrasil/<id>/`, not the main tree.
- **`git worktree list` shows a missing path** — prune with
  `git worktree prune`, then re-list.
