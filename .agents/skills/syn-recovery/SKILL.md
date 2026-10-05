---
name: syn-recovery
description: >-
  Agent-only playbook for stuck or missing ordinary Brokk direct reports.
  Use when the session-start digest reports an ordinary direct report's endpoint dead or its metadata has no window, or after a stale wake, looping pane, repeated confusion, an answered-by-brief question, an unresponsive Eindri, or a failed steer.
  Reconciles recorded work before escalating from targeted inspection through safe relaunch or failure.
user-invocable: false
metadata:
  internal: true
---

# syn-recovery — recovery — stuck-worker playbook

Use this playbook when the session-start digest reports an ordinary direct report's endpoint dead or its metadata has no window, or when a direct report is stale, looping, repeatedly confused, asking a question its brief already answers, unresponsive, or when a steer failed to land.

Interrupt and stop a worker through `bin/agents/eindri-control.sh <interrupt|exit|read> <agent-or-pane>`,
which verifies each action and never tears down or discards anything.

**There is no relaunch verb here (measured 2026-10-01).** This playbook used to name
`bin/brokk-control.sh <id> relaunch`; that script does not exist on this house, and the door that
does (`bin/agents/eindri-control.sh`) offers only `interrupt | exit | read`. The real relaunch road is
**`bin/agents/einherjar-spawn.sh <id> --relaunch`**, and it needs its brief in place first:

```sh
bash bin/agents/erindi-brief.sh <id> --relaunch      # scaffold data/<id>/brief.md
# …fill the brief's {TASK}…
bash bin/agents/einherjar-spawn.sh <id> --relaunch --harness <h> --model <m>
```

Two refusals that road will give, and both are correct: a `{TASK}` placeholder still in the brief,
and a seat record that already stands (stop it first, or the existing road runs and the stale
launch script is reused).
That plane covers workers running in this home; a remotely placed Eindri-home is refused by name and reconciled through `Eindri-home-provisioning` instead.
Load `harness-adapters` before a resume command or a harness-specific skill invocation, and whenever the adapter's own quirks matter.
The target window's harness is recorded as `harness=` in `state/<id>.meta`.

## Session-start reconciliation for a dead ordinary direct report

This procedure covers ordinary `kind=ship` and `kind=scout` direct reports.
Load `Eindri-home-provisioning` instead for `kind=Eindri-home` recovery.

For a REMOTE Eindri-home, `brokk-crew-state` and `brokk-peek` read the actual remote endpoint over `brokk-on.sh`, and `brokk-send` reports a delivered-with-pending-confirmation steer as delivered (their headers own the contracts); an `unknown-remote` read or unreachable-host failure means the remote state could not be read, never that the mate is dead or the send failed.
Recover a genuinely stuck remote mate only through `bin/agents/einherjar-spawn.sh <id> --Eindri-home`, never raw herdr pane close/kill surgery, which strands the endpoint binding.

Treat the digest's endpoint result as a presence signal, not proof that the task's work or validation run is gone.
Read the targeted current state with `bin/records/vor-crew-state.sh <id>` before deciding to relaunch.
A no-mistakes run matched to the crew's branch and current code remains authoritative when the endpoint is dead: handle a terminal or parked run through the normal lifecycle, and keep supervising an active run instead of creating a duplicate worker.

When no authoritative run accounts for the task, inspect only its recorded backend and worktree inventory.
Use `Yggdrasil status` for Yggdrasil-backed tmux, herdr, zellij, or cmux tasks, and use the recorded `orca_worktree_id=` and `terminal=` for Orca tasks.
Do not sweep another home's endpoints or infer ownership from a matching window label.

Before relaunch, prove that no live agent still owns the recorded task and that the existing worktree remains available.
Preserve its uncommitted changes and commits, keep the same task identity, and resume or relaunch the recorded harness in that existing worktree with the same brief plus a concise progress note.
Do not use a fresh generic spawn while the recorded worktree is unaccounted for, because allocating another worktree can split one task across two copies.
If the worktree or ownership cannot be reconciled safely, leave all state intact and report the task failed or blocked with the conflicting evidence.

## Live-endpoint escalation

Escalate in order:

1. Peek the pane, and check the task's steering inbox (`state/<id>.inbox/`) for unhandled `*.msg` records - a stale wake naming an unread Brokk instruction means the worker never acknowledged a durable steer, and the record itself shows exactly what was intended.
2. If the Eindri is waiting on a question its brief already answers, answer in one line via `BROKK_HOME=<this-Brokk-home> bin/agents/brokk-send.sh` from an active Brokk session unless `BROKK_HOME` is already set to the active Brokk home.
3. If the Eindri is confused or looping, interrupt with `bin/agents/eindri-control.sh <id> interrupt`, then redirect with one corrective line through `brokk-send` (note: `brokk-send` resolves a *registered* `eindri-homes.md` home; a local worktree errand has none, so use the errand's own wake queue).
4. If the Eindri is genuinely wedged after redirection, relaunch it with
   `bash bin/agents/erindi-brief.sh <id> --relaunch` (refill its brief with what it did and what is left),
   then `bash bin/agents/einherjar-spawn.sh <id> --relaunch --harness <h> --model <m>`.
   Pass the harness and model when the worker should come back on a different runtime.
   **Measure before you judge**: a worktree that reads `0` commits against `origin/main..HEAD` may
   have already landed its work on the **remote** branch — check `git log --oneline
   origin/<branch>` and `gh pr list` before filing a failure (Brokk filed two delivered errands as
   failed on 2026-10-01 by doing exactly that).
   Genuine wedging means looping, unresponsive, repeating the same obstacle, or truly dead.
   A low context reading is not wedging; modern harnesses auto-compact and keep going.
   The worktree and commits persist, so relaunch is cheap.
5. If a second relaunch fails too, write `failed` to the backlog and tell the Allfather the plain failure, preserved work, and consequence using `AGENTS.md` section 9; do not mention metadata, harness, window, or worktree unless the path itself is needed for action.
