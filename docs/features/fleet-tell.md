# Talk to, and steer, any agent — `fleet-tell`

## What it is

One tool for every message between agents: from an Eindri to the helm, from the helm to a worker on another machine, from one arm holder to another. It also carries the steer verbs, so there is one road for talking to an agent and one for steering it.

Before it, the helm reached each machine by hand: the arm wire first, then ssh and a `herdr` pane by hand when the wire failed. `fleet-tell` does both and reports what happened to each target.

## What you need

- the machines named in the fleet registry (`hodd/data/fleet.json`), reachable over ssh with keys;
- a runtime on each machine that carries `bin/agents/tell.sh` (the older `arm-send.sh` is the fallback when it does not);
- `herdr` running on the target for the pane fallback.

## The commands

Reach an arm holder, or every one:

```bash
bin/fleet/fleet-tell.sh --to <machine> "<line>"
bin/fleet/fleet-tell.sh --all "<line>"
```

Reach an errand or a pane on any machine:

```bash
bin/fleet/fleet-tell.sh --to <errand> "<line>"
bin/fleet/fleet-tell.sh --to <machine>:<errand> "<line>"
bin/fleet/fleet-tell.sh --to <machine>:<pane> "<line>"
```

Steer, answer and stop. The targets are the same:

```bash
bin/fleet/fleet-tell.sh --steer --to <machine>:<errand> "<one steering line>"
bin/fleet/fleet-tell.sh --answer --to <errand> "<the answer>"
bin/fleet/fleet-tell.sh --answer --to <errand> --record-only "<answered another way>"
bin/fleet/fleet-tell.sh --stop --to <machine>:<errand> ["<why>"]
```

Useful flags: `--from <seat>` names the sender (default: this seat), `--pane-only` and `--arm-only` pick one road, and `--dry-run` resolves and reports without any ssh or send.

The same door is the Pi tool `gna_fleet_tell`, the Ymir MCP tool `gna_fleet_tell`, and the `steer` action of `ymir_errand` in every harness.

## What it prints

One row per target:

```
fleet-tell[1]{machine,target,verb,holder,arm,pane,typed,why}:
  "far","arm holder","tell","Ada,counsellor","refused","w1:p1","yes","the arm is not held; …"
```

`arm` is `handed`, `refused` or `no-answer`. `pane` is the pane id or `not-found`. `typed` says whether a line went into a pane. A tell is **handed, not done**, until the agent answers.

## How it chooses a road

1. On the target machine it runs that machine's own `bin/agents/tell.sh`, over ssh when the machine is not this one.
2. An arm holder is also typed into directly, because a wake in the queue is read at the holder's next turn and a typed line is read now.
3. When the wire refuses, the line is typed into the agent's herdr pane with `eindri-send.sh`, which refuses a pane that is not an agent pane. The pane of an arm holder is found by the machine itself (`bin/fleet/arm-holder-pane.sh`), never from a remembered id.
4. When the arm was refused and the pane was typed, a wake is raised on the sender's own queue: `<machine>'s arm is not held — re-arm needed`.

Every line is signed `<seat> (<machine>)`.

## Limits

- One line only. A long message goes in a letter file and the line names it.
- Every ssh and remote command has a time limit (25 seconds, `FLEET_TELL_TIMEOUT`); a machine that does not answer is reported as `no-answer`.
- `--answer` needs an errand with an open question on that machine.

## If it does not work

- `no-answer`: the machine is off or its ssh road is down. Check `bin/fleet/roads.sh`.
- `refused` and `pane not-found`: nobody holds the arm there and no agent pane could be proved. Re-arm the machine.
