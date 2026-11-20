## agents · unversioned · 2026-11-10 — the arm closes finished seats

### Why

The Allfather's law, in his own words: *"this is figured out AUTOMATICALLY when the
seat takes the arm."* Measured the same evening — nine `eindri-*` herdr workspaces
stood in the hall, one of them the worker writing this note:

- `einherjar-spawn.sh launch_herdr` raises a herdr workspace `eindri-<id>` per errand
  and never records its id, so nothing could address it later;
- `eindri-dispatch.sh close` moves the backlog to review and `cmd_review` writes the
  verdict — neither closes the workspace;
- `eindri-control.sh close` closes a pane and nothing calls it on completion;
- a worker exits into a bare shell, herdr restores that shell after a restart, and the
  shell's cwd keeps its worktree `keep:in-use` in `bin/forge/housekeeping.sh` — so 80
  worktrees under `.yggdrasil/` could never be reclaimed.

The same session's own words are the standard this fix is held to: masterplan row 127
ends *"it now reclaims by itself"* — the housekeeping door was already supposed to work
this way, and an idle shell pretending to be a live agent undid it.

Two more faults were found in the same pass, both of which reach every user who
installs or updates Ymir:

- **`rm -rf .pi/extensions` + `--assume-unchanged` does not work.** assume-unchanged is a
  per-FILE bit and does nothing for a directory, so `git status` in every Eindri worktree
  reported all 45 extension files as DELETED, and one `git add -A` inside a worker would
  have deleted every pi extension from the repository. `bin/forge/yggdrasil.sh` already
  had the right shape — a per-worktree non-cone sparse-checkout exclusion.
- **`valknut-load.sh` recorded a `.yggdrasil/` worktree as a root.** A root is a home; a
  worktree is an errand and dies with it. The transient path was found and removed by
  hand on this seat, and would have been recorded again on the next `--pi` from a
  worktree.

At the Allfather's word this is not a tidying habit but a property of the system —
*"all updates on all machines must solve this better for all kind of users"* — so the
mend arrives through the doors every seat already runs: `bin/engine/ymir-install.sh`,
`bin/agents/groa-update.sh`, `bin/agents/eir-doctor.sh` and a migration for homes
installed earlier.

### What it does

- **`bin/seat/seat-reap.sh`** — the one hand that closes a finished seat.
  `<id>` closes that errand's workspace by the id recorded in `state/<id>.meta` (by label
  when an older record carries none); `--sweep` closes every agentless `eindri-*`
  workspace whose errand is closed or has no live record; `--list` names what a sweep
  would close and closes nothing; `--shell <path>` closes the bare shell standing in a
  worktree; `--install` / `--check` seat and verify the sweep per harness; `--verify`
  reports the two structural faults without mending them.
  Liveness is asked of `bin/seat/herdr-agents.py` (the ONE reader of `herdr agent list`)
  and the close reuses `bin/seat/seats.sh close` and `herdr workspace close`, so it
  cannot become a second, looser closer. A live agent is refused, twice: once on the
  list and again immediately before the irreversible step.
- **`einherjar-spawn.sh`** records the workspace id in the meta (`workspace=`) and
  replaces `rm -rf` / assume-unchanged with the sparse-checkout exclusion, proving the
  worktree clean.
- **`eindri-dispatch.sh`** closes the seat on `close` and on a terminal review verdict;
  a `return` keeps it (the work went back to the worker).
- **`eindri-arm.sh`** closes the seat at the close hook and at retirement, and never
  treats a tidy seat as a handoff ack.
- **`saga-session-start.sh`** gains a `SEATS` section: taking the arm sweeps the hall
  and prints one TOON row of what closed. `bin/pi/syn-watch-arm.sh` sweeps on the arm
  road too.
- **`housekeeping.sh`** asks whether an AGENT stands in a tree, not whether a process
  does: an idle shell with no agent is no longer `keep:in-use`, the tree goes on to be
  judged by whether any of its work is missing from the remote, and a bare shell is
  closed (through `seat-reap.sh --shell`, which refuses a live agent) before any
  reclaim. Dirty and unpushed trees are untouched, as before.
- **`valknut-load.sh`** never records a linked worktree as a root, and prunes any that
  an older seat recorded (`git rev-parse --git-common-dir` differs from `--git-dir`).
- **`.agents/migrations/0018-a-worktree-is-not-a-root.sh`** heals homes installed
  earlier: it prunes linked-worktree paths from `~/.pi/agent/extensions/.ymir-root`
  (keeping `<pointer>.pre-0018` as a backup) and switches every affected worktree to the
  sparse-checkout exclusion.
- **`ymir-install.sh`** adds a `seats` step that seats the sweep per harness (pi,
  opencode, claude) and, in `--check`, NAMES the faults instead of mending them.
  **`groa-update.sh`** re-seats the sweep after every update and reports it in `--check`.
  **`eir-doctor.sh`** gains a `seats` surface whose fix mode calls the migration and the
  installer's own hook.

### Files

- `bin/seat/seat-reap.sh`
- `bin/seat/tests/test_seat_reap.sh`
- `bin/agents/einherjar-spawn.sh`
- `bin/agents/eindri-dispatch.sh`
- `bin/agents/eindri-arm.sh`
- `bin/agents/eir-doctor.sh`
- `bin/agents/groa-update.sh`
- `bin/seat/valknut-load.sh`
- `bin/forge/housekeeping.sh`
- `bin/pi/syn-watch-arm.sh`
- `bin/time/saga-session-start.sh`
- `bin/engine/ymir-install.sh`
- `.agents/migrations/0018-a-worktree-is-not-a-root.sh`

### Verified

- `bin/seat/tests/test_seat_reap.sh` — 34 cases, all green, against a STUBBED `herdr`
  on `PATH` and a throwaway `HOME`: the sweep closes a closed errand and a recordless
  one, never a live agent, never a fresh record, never the main hall; `--list` closes
  nothing; a closed seat is recorded once and a second sweep closes nothing; a single
  close refuses a live agent by name; a bare shell is closed and a live agent's pane is
  refused; housekeeping reports a bare-shell worktree `reclaimable:merged` (not
  `keep:in-use`), keeps a live agent's `keep:in-use`, keeps `keep:unpushed` and
  `keep:dirty`; the migration prunes the worktree root with a backup, is idempotent, and
  turns a worktree that reported its extensions deleted into a clean `git status`.
- `ymir-install.sh --check` under a throwaway `HOME` seeded with a `.yggdrasil/` path in
  `.ymir-root` printed `"seats","WARN","5 fault(s) — … a real install/update heals it"`.
- `groa-update.sh --check` under the same `HOME` printed `seat-reap: PENDING — a real
  update mends it`, and mended nothing.
- `bin/seat/seat-reap.sh --verify` on this worktree before and after the mend: 5 faults,
  then clean, and `git status` now shows only the files this errand touched.

### Not done here, and why

The four other affected worktrees on this seat belong to errands that were LIVE while
this was written; running the migration against them would have raced their git
operations. The next `bin/engine/ymir-migrate.sh apply` — which `ymir-install.sh` and
`bin/agents/groa-update.sh` run — heals them, and `seat-reap.sh --verify` names them
until it does.

### Appended — the seat proof, a late boot, and the arm's ear (same day, later)

Three faults found while proving the above, each measured on this seat:

- **The seat proof gave up before pi booted.** `seat-prove` waited 25 s; a pi boot on a
  loaded rail takes longer. The door said "no agent", the record said `seat=no` and
  `failed:`, the arm was never armed and the brief was never delivered — while the agent
  came up a minute later in the pane the record named.
- **A failed seat roused nobody who was holding the helm.** The shell road called
  `bin/notify/send.sh`, which is a desktop note; the engine called nothing at all. The ARM
  — the session draining `state/.wake-queue` — never heard.
- **`eindri-start.sh` without `--model` resolved no model for the role**, so an errand ran
  on whatever the launcher defaulted to (brokk's row), and a machine overlay could pin a
  local model for a worker without a word said.

What changed:

- `bin/seat/seat-prove.sh` — the shipped wait is **60 seconds** (`YMIR_SEAT_SETTLE`, the
  Allfather's correction the same evening), it is the ONE default, and both callers pass
  `--settle` only when the operator set the variable. A worker queued on the local-model
  lock is counted ALIVE: while such a waiter stands in the worktree the clock resets, so
  the wait is bounded by progress rather than by the wall.
- `bin/seat/seat-wake.sh` — one helper writes the seat's word into the arm's queue
  (`state/.wake-queue`), for both roads, exactly once per (errand, kind), on the same
  ledger `bin/agents/eindri-wake-lib.sh` uses. Both the shell spawner and
  `src/ymir_runtime/seat.py` call it on an unproven seat.
- `bin/seat/seat-adopt.sh` — a LATE BOOT IS STILL A SEAT: it re-asks the agent reader for
  a record whose seat was never proven, and when an agent now stands there it corrects the
  meta (`seat=yes`, the pane the agent actually uses), arms the silence watch, and writes
  the `adopted` wake. `--all` runs in the digest's `SEATS` section; `--list` changes
  nothing.
- `bin/agents/eindri-start.sh` — without `--model` it asks `bin/model/agent-model.sh` for
  the ROLE's model (not brokk's), and prints `model[1]{agent,model,decided_by}` on every
  start, naming the file that decided and saying plainly when a machine overlay pinned a
  LOCAL model for the errand.

Verified in the same ward (`bin/seat/tests/test_seat_reap.sh`, 53 cases): the wake is
written once and a second call is a no-op; an adopted record is corrected, its status says
`working: adopted`, and the arm is woken exactly once; the settle is one number, in
`seat-prove.sh`, and the runtime asset names it.
