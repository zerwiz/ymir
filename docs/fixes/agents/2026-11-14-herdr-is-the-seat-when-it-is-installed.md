## agents · 2026-11-14 — herdr is the seat whenever herdr is installed

### Why

The operator: *"i dont see your eindris in herdr"* · *"herdr is primary always if it is installed. make sure that
always is that way."* Nine workers were seated in tmux in one night, silently.

### The cause (traced with `bash -x bin/seat/herdr-run.sh eindri …`)

1. `eindri-start.sh` passed the **role** (`sindri`) as the seat name, so every sindri errand asked for the one
   worktree `.yggdrasil/sindri`.
2. A branch `yggdrasil/sindri` left by an earlier errand (folder gone) made `yggdrasil.sh create` refuse; `herdr-run.sh`
   threw the error away and exited 4.
3. `eindri-start.sh` read any herdr failure as "herdr is absent" and seated tmux.

### What changed

| Place | Now |
|---|---|
| `bin/agents/eindri-start.sh` | the seat is named by the errand (`--id`, else the label); the role goes as `--role`; a herdr failure on a machine with herdr is an **error** that prints herdr-run's own lines, never a tmux seat; tmux only when herdr is not installed, and it says so; herdr is reached by its socket from a unit or cron; a child never inherits the launcher's `HERDR_PANE_ID`/`HERDR_TAB_ID` |
| `bin/seat/herdr-run.sh` | prunes stale worktrees, re-attaches an existing `yggdrasil/<name>` branch instead of refusing, shows `yggdrasil.sh`'s error, and reads the worktree path by its field |
| `docs/runbooks/send-an-eindri.md` | the road, the fixed core every brief carries, and the rules learned |

### Proof

On the operator's dev machine, from the checkout: six errands (`hall-follow`, `smidja-header-chat-2`, `fleet-truth-2`, `boot-stopwatch`,
`bridge-and-rail`, `digest-head`) were each seated in their own herdr pane (`w39:pY`, `pZ`, `p0`, `p11`, `p12`, `p13`)
in `.yggdrasil/<errand>`, all `rc=0`; before the change the same launch exited 4 and fell into tmux.
