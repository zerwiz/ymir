# One road to talk to and steer any agent

**Component:** fleet (`bin/fleet/fleet-tell.sh`, `bin/fleet/arm-holder-pane.sh`) · **Date:** 2026-11-21

## What was wrong

Reaching the agents of the fleet was done by hand. The helm sent a line over the arm wire, saw it refused or unanswered, then used ssh and `herdr` to type the same line into each arm holder's pane. Steering an errand went through `eindri-send.sh` alone, and failed with "agent not found" while the pane was alive. There were several roads and no single report of what each target received.

## What changed

- `bin/fleet/fleet-tell.sh` is the one door. Its targets are a machine, an errand, `machine:errand`, a pane or `machine:pane`, or `--all`. It reuses each machine's own `bin/agents/tell.sh` over ssh and falls back to typing into the agent's herdr pane.
- Its verbs are tell, `--steer`, `--answer` (speak and record, or `--record-only`) and `--stop`.
- `bin/fleet/arm-holder-pane.sh` lets a machine name its own arm holder's pane, and proves it is an agent pane before returning it.
- The Pi tool and the MCP tool `gna_fleet_tell` call the same door. The `steer` action of `ymir_errand` (Pi, opencode, MCP) now calls it, so steering has one road.
- The Eindri brief and the contract tell every agent to use it for any message to another agent.

## Proof

`bin/fleet/tests/test_fleet_tell.sh` uses a fake ssh and a fake herdr: arm handed with pane typed, arm refused with pane typed and a wake raised, a machine with no answer, `--dry-run`, the steer, answer and stop verbs, and a resolver that never returns a pane that is not an agent pane.
