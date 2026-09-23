## agents · unversioned · 2026-09-23 — a seat loads its own figure, and never takes the helm

### Why
- **Every seated figure believed it was Brokk.** `bin/herdr-run.sh` and
  `bin/pi-seat.sh` started pi with `--model` only. Pi's loaded context is
  `~/.pi/agent/AGENTS.md`, `~/AGENTS.md`, `AGENTS.md` — the always-loaded
  contract, which describes **Brokk** as the primary. The figure's own file
  (`.agents/agents/<role>.md`) was never injected. Proven live: a seat named
  `identity-test`, told nothing, asked "what is your name and role?", answered
  *"I am Brokk, the Allfather's counsellor — the bellows that plans, steers,
  reviews, and sends the Eindri out to forge."* Kvasir had only behaved like a
  scout because the task text said "You are Kvasir" — the identity was
  simulated by the prompt, never loaded from the role file.
- **Every seat contended for the primary's helm, and the watcher died.** There
  is one lock per machine —
  `${XDG_STATE_HOME:-$HOME/.local/state}/ymir/brokk.lock`
  (`bin/gleipnir-lock-lib.sh`). A seat started in the main home inherited that
  home's state and fought the primary for the same lock; the last to start won.
  The evicted primary's extension then returned `read-only` and surfaced
  `watcher: FAILED - Pi extension cannot restore continuity because this session
  no longer owns the lock` (`.pi/shared/extensions/gna-pi-watch.ts:533,547`).
  Measured twice on 2026-09-23: three hand-seated pi sessions (pids `468301`,
  `1173111`, `1612013`) evicted the primary `2796305`; later a second Brokk in
  the herdr pane `π - heimdall` (pid `2612975`) took the helm and the primary's
  heartbeat went 453s stale.
- **`bin/pi-seat.sh` referenced an undefined `SCRIPT_DIR`.** Its Yggdrasil
  isolation block tested `[ -x "$SCRIPT_DIR/yggdrasil.sh" ]` against
  `/yggdrasil.sh`, so the check always failed and **no seat was ever isolated
  into a worktree** — a silent no-op.

### Fix
- **`bin/herdr-run.sh`** — injects the figure's file when the harness is pi:
  `--append-system-prompt "$ROLE_FILE"` (the flag already existed in pi and was
  unused). If the role file is absent it says so and never silently seats as
  Brokk.
- **`role_file_for()`** — the chooser (`bin/eindri-role.sh`) and
  `config/agents.yaml` speak **short** roles (`kvasir`, `sindri`, `bragi`) while
  the roster files carry the craft in the name (`kvasir-scout.md`,
  `sindri-developer.md`, `bragi-marketer.md`). A naive `$ROLE.md` resolves
  nothing, so the helper tries the exact path first, then the short-role
  prefix. Verified for every role in the roster.
- **`bin/herdr-run.sh` + `bin/pi-seat.sh`** — every seat now gets a private
  machine-state dir, so a worker resolves its own `brokk.lock`:
  `seat_state_env()` emits `BROKK_MACHINE_STATE_DIR=…/ymir/seats/<name>`, passed
  as `--env` on `herdr tab create` / `herdr pane split` / `herdr workspace
  create`. **Verified constraint:** `herdr agent start` has no `--env`, so the
  variable must be set at pane/tab creation.
- **`bin/herdr-run.sh`** — `seat_guard()` refuses a seat that would resolve the
  primary's lock, so a future regression fails loudly instead of killing
  supervision.
- **`bin/pi-seat.sh`** — defines `SCRIPT_DIR`, so the Yggdrasil isolation block
  actually runs, and passes the role file plus the per-seat state dir.

### Files
- `bin/herdr-run.sh`
- `bin/pi-seat.sh`
- `.agents/skills/herdr-panes/SKILL.md` (the seat contract, updated in the same change)
