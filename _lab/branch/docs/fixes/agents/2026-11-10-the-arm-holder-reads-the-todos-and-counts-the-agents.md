## agents · 2026-11-10 — the arm holder reads the Allfather's todos and counts every agent on the machine

### What
- `bin/voice/todos.sh` — read-only door onto Rödd's ledger (`hodd/state/voice/todos.jsonl`), importing the one fold
  (`voice_tools._todo_state`); `--digest` lists open items, personal first.
- `bin/agents/agent-census.sh` — every harness process (from /proc), every herdr pane and agent, every errand pane
  whose work already reported done/failed (`STALE_PANE`), harness sessions outside herdr (`OUTSIDE_HERDR`), and the
  repo's worktrees (`git worktree list`). Reads only; closes nothing.
- `bin/time/saga-session-start.sh` gains two sections: THE ALLFATHER'S TODOS and AGENTS ON THIS MACHINE.
- `bin/gates/seat-woven-driver.sh` seats the regenerate driver by a RELATIVE path (`.git/config` is shared by all
  worktrees; the absolute path pointed into a nested errand worktree).

### Why
His words, 2026-11-10: *"forge so the personal todos for the Allfather get read"* and *"the arm holder should know
exactly how many agents are running on the computer … the arm holder is the Allfather's right hand on his machines."*
Measured on heimdall: 9 open todos read by nobody but the voice; 5 harness processes (3 Pi sessions outside herdr);
20 panes in 18 workspaces, 5 of them errand panes whose work had ended; 97 worktrees.

### Verified
`todos.sh --digest` → `open: 9 (1 personal · 8 heimdall)`. `agent-census.sh --digest` → the counts above. A reused
pane id is not judged stale unless the pane still stands in the errand's worktree. A relative merge driver proven to
run from the worktree top even when the merge is started in a subdirectory.
