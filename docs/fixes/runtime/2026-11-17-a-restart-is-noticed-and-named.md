# A restart is noticed, and its hands are either raised or named

**2026-11-17 · component: runtime · plan 001 §4 F2 (the dead desk)**

## What happened

After the desk was restarted at 07:21, `herdr agent list` reported 27 agents — 25 idle, 2 unknown — and
`ps -eo pid,args | grep -E '[p]i-coding-agent'` found **zero** `pi` processes. A pane is a shell and the
agent is the desk's child: when the desk was killed, every child went with the cgroup, and the panes came
back saying *idle*. Nothing noticed, so nothing repaired it, and the operator discovered it by asking.

## What was forged

`bin/seat/desk-inventory.sh` — the record of who stands where, written **before** the desk can lose them:
`save` snapshots every pane the desk claims, with its session file and cwd, atomically, to
`<state>/desk-inventory.json`. `check` then asks the MACHINE, not the desk, whether a process actually
stands in each pane — `live` or `shell` — by matching `/proc/<pid>/cwd` and each agent's session path
against an agent harness, using the harness list the engine owns (`src/ymir_runtime/state/lock.py`,
imported, never copied). `lost` names the rows that no longer stand.

`save --claimed` exists for a desk that has *already* lost its hands: herdr still remembers each pane's
session path across a restart, so those panes can be named today and raised one at a time.

`bin/seat/desk-watch.sh` — the repair and the alarm: `check` prints one line that names **every** lost
pane (count, pane ids, sessions, and what still stands), `raise --limit N` resumes them through
`bin/seat/herdr-run.sh` (scoped, so a re-raised hand is in its own cgroup), and `watch` does both, bounded.

The raise is bounded on purpose. Twenty-seven hands raised at once would swap the machine to death — the
very fault the door repairs. One per tick, and the rest named.

`config/units.yaml` gained the `desk-failsafe` timer: one pass a minute that snapshots, names, speaks and
frees, through `bin/engine/units.sh` so it runs from the **pinned runtime** and never from a worktree. It
does **not** raise: whether a pane comes back as an agent is plan 001 §6 — the Allfather's decision — and
an unattended loop must not take it for him.

## What it proved, on the heart

```
./bin/seat/desk-inventory.sh check
  desk-verdict[1]{claimed,live,shells}:  "27","0","27"
./bin/seat/desk-inventory.sh save --claimed
  "/home/example-heart/Documents/ymirhome/state/desk-inventory.json","27","25","claim"
./bin/seat/desk-watch.sh check
  "lost","25","the desk lost 25 hand(s) to a restart — panes wV:p1 w18:p1 … w21:p1 w22:p1
              hold shells, not agents; 0 agent(s) still stand"
./bin/seat/desk-watch.sh raise --limit 1 --dry-run
  would raise: wV:p1 — cd …/.yggdrasil/queue-warden — agent-scope.sh -- pi --session …01a1c751….jsonl
```

The heart is *in* the 07:21 state as this was written (the restarted desk's panes never got their agents
back), so this is the real event, not a re-enactment: 27 claimed, 27 shells, and one message that names
them. No pane was killed or restarted to produce it.

## What is not closed

Two of the 27 rows carry no resumable session (`forseti`, a name with no `agent_session`, and an
`opencode` row whose session is an id, not a path); they are named and cannot be auto-raised. And the
timer is registered but **not enabled** on the heart: its first tick would speak yesterday's death again,
which is the operator's call, not a worker's.

## Where the proof lives

`bin/seat/tests/test_desk_failsafes.sh` builds a claim with one live agent process and one empty pane, and
asserts `live` / `shell` / `lost` / the single operator line.

## CHANGE LOG

- 2026-11-18 — review-mend: added missing heading for #818
