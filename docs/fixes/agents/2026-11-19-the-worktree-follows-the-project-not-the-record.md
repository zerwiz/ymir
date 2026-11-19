# The worktree follows the project; the record stays in the home

**2026-11-19.** A dozen errands were spawned tonight with `BROKK_HOME=<the repo>` set by hand, because without
it the worktree landed inside the release pin. It fixed the worktree and **moved the record with it**: `state/`
resolves from `BROKK_HOME`, so an errand's `meta` and `status` were written to a shelf the home's own doors do
not read.

Measured after the fact: `ymir_errand read home-audit` answered *"NOTHING RECORDED — no state/home-audit.meta
and no .status"* while that errand's pane had reported `done:` an hour earlier; and `bin/seat/seat-reap.sh
--sweep` closed **0 of 10**, keeping each one as *"undecided — idle but the record is not terminal"*.

The cause was one line: `WT_ROOT="$BROKK_HOME/.yggdrasil"`. The worktree root was taken from the variable that
also names the record.

**The fix:** `WT_ROOT="$(project_wt_root "$PROJECT_DIR")"` — the function that was already defined three lines
above for exactly this — so the worktree follows the **project argument** while `BROKK_HOME` (and with it
`state/`) keeps pointing at the home. Nobody needs to set `BROKK_HOME` to get a sane worktree again, and an
errand's record lands where the reap, the notify and the arm can find it.

Proved by: a dry-run from the pin with no `BROKK_HOME` naming `<project>/.yggdrasil/<id>`, and an errand's
`state/<id>.meta` appearing in the home.
