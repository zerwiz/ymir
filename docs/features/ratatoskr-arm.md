# The arm door — a task for a machine goes to its one holder

## What it is

Some tasks are not for a particular pane. They are for **a machine**, and what answers for a
machine is its one live **arm holder** — the session that holds the lock and can act with the
operator's authority.

`bin/bridge/ratatoskr-arm.sh` is the one door to a holder: here, through the holder's own
pane; across the fleet, over that machine's own road. It exists so a task addressed to a
machine is either handed to the agent that answers for it, or refused **by name** — never
left on a shelf looking delivered.

## What you need

- The fleet registry (`hodd/data/fleet.json`) for a machine's road.
- An arm holder on the machine you are writing to. A machine with nobody holding the arm will
  say so, and nothing is handed.

## Do it

Hand one line to a machine's holder:

```bash
bin/bridge/ratatoskr-arm.sh heimdall "summarise what changed on the tree today"
```

The answer is either `handed` or a refusal that names the machine:

```
ratatoskr-arm	this machine	handed	(handed; delivered only when the holder answers)
ratatoskr-arm: refused — a-machine-not-in-the-registry is not in the fleet registry; nothing was handed
ratatoskr-arm	REFUSED	nobody holds the arm on a-third-machine — nothing was handed
```

See who holds the arm anywhere:

```bash
bin/bridge/ratatoskr-arm.sh --who
```

```
heimdall	held	  "Hœnir","claude"
a-second-machine	held	  "a worker","counsellor"
a-third-machine	no answer	ssh: connect to host … port 22: Connection timed out
```

Send a queued task to a machine instead of a pane, and the relay uses this door for you:

```bash
bin/bridge/ratatoskr.sh send heimdall "what is the state of the queue?"
```

### Handed is not delivered

A line that lands says **handed**. It becomes **delivered** only when the holder drains it
and the queue carries an answer (RULES/49, 56). A relay that reported "delivered" on a
handed line would be the false green this house has paid for before.

## Limits

- One holder per machine. This door reads the lock; it never mints a lease, and a worker
  never becomes the holder by using it.
- A machine with no live holder is refused, not queued. Clear that, then send.
- A machine that does not answer its road says `no answer` — which is not the same claim as
  `nobody holds the arm`, and the two are never mixed.
- Across owners (another person's fleet) this door does not reach: that is the hub's road,
  not this one.

## If it does not work

- `is not in the fleet registry` — the name is not a machine this fleet knows. `--who` lists
  the ones it does.
- `nobody holds the arm on <machine>` — that machine has no live holder. Somebody must take
  the arm there; the line was not handed.
- `no answer` from `--who` — the road failed. `bin/fleet/roads.sh check` says which machines
  answer.

## CHANGE LOG

- **2026-11-16** — written with the change it describes (plan 303 §12.3 step 5).
