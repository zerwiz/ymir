## harness · 2026-11-11 — Claude becomes an Eindri: verified, launched by the one generator, with a worker profile (plan 239 P5)

### What
- **`src/ymir_runtime/harness.py`** — `claude` joins `VERIFIED`; `build_launch_command` gains the Claude shape
  `claude --permission-mode acceptEdits --settings <profile> [--model m] "$(cat <brief>)"` (interactive, so the seat
  stays steerable in herdr and the brief is its first turn); `resolve()` keeps pi/opencode models off a Claude seat —
  a machine-wide `provider/model` token is dropped, an explicit one is refused, an Anthropic alias is kept.
- **`.agents/harnesses/claude-worker.settings.json`** — the worker permission profile: edits and commands without a
  prompt (the latitude opencode workers already get), deny on a push to main/master, force-push, `gh pr merge`,
  `git merge`, `git add -A`/`.`, `commit -a`, `reset --hard`, `clean -f`, `checkout --`, `stash`, `rm -rf`, `sudo`,
  and the Agent/Task tools. A missing profile is a refusal, never a bare `claude`.
- **`bin/agents/einherjar-spawn.sh`** — `claude` in `VERIFIED_HARNESSES` and the same Claude shape in its generator;
  a launch line that cannot be built now refuses the spawn instead of writing `exec ` with no command.
- **`bin/agents/eindri-start.sh`** — when the engine declines an errand (exit 4) and the caller asked for a harness
  the ordinary road cannot seat (claude, or a raw launch), it refuses instead of seating a different harness.

### Why
His word, 2026-11-11: *"we need to be able to spin up claude agents on the eindri door"*. The live attempt that night
measured every gap: two verified lists, neither with `claude`; the escape hatch seated Claude but its worker stopped
at the first permission prompt (pane w4M:p1); a declined errand came up as an idle **pi** named mimir (the harness
silently swapped); the machine's opencode model was handed to Claude, which refused its first turn.

### Verified
- `python3 -m unittest ymir_runtime.tests.test_harness ymir_runtime.tests.test_seat` → 43 tests OK (7 new: claude in
  VERIFIED, the Claude shape, the profile's deny rows, a missing profile refused, the exec-prefix contract for claude,
  a machine model dropped, an explicit provider token refused, an alias kept).
- Full `ymir_runtime` suite: the same 11 pre-existing failures as `main` (diffed), none added.
- **Live:** `eindri-start.sh … --id foreman-process-3 --kind claude` → seat `harness=claude`, herdr pane w4P:p1, accept
  edits on, brief as the first turn; after the model law it works the Example5 errand with no prompt.

### Not done
- **P5d** (a stalled worker raised to the arm), **P5f** (the `eindri-only` hook per project), **P5g** (the brief's
  register follows the project) — plan 239.
- The worktree for a foreign project still lands under the dispatching tree's `.yggdrasil/` (P5e's placement half).
- Found: `/model <alias>` typed into a seat also saves it as the operator's default for new sessions; seats must take
  `--model` on the launch line, never a `/model` steer.
