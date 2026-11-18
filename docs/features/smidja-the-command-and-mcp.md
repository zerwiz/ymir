# Smíðja — the `smidja` command and the Smíðja MCP

## What it is

`smidja` is the one command for the smithy. It starts a run, watches it, steers it, stops it, judges it and teaches Völundr from it. The Smíðja MCP gives the same verbs, as tools, to every harness you use: Claude Code, Codex, pi, Hermes and OpenCode.

Inside a run, only **pi** does the work. pi reaches every provider's models (Claude, OpenCode Go, OpenRouter and the local rail), so one worker covers them all. The other harnesses never run inside the smithy. They drive it from outside, through the command or the MCP.

The command can also act on another machine: add `--on <host>` and that machine answers, over ssh. Where you have a tailnet, ssh takes it.

## What you need

- `uv`, because the smithy's chains are uv scripts;
- `pi` on your PATH, because it is the smithy's only worker;
- a model pi can reach, given with `--model` or through `SMIDJA_LOCAL_MODEL`;
- for `--on <host>`: ssh to that host, with the smithy installed there.

`smidja doctor` checks every one of these and names whatever is missing.

## The commands

| Command | Does |
|---|---|
| `smidja up` | Clears the kill-switch, restores any missing prompt files from the factory's templates, and raises the viewer on `:8437` |
| `smidja doctor` | Shows what this machine has, and whether a run can start |
| `smidja chains` | Lists the chains, each with its `Phases:` line |
| `smidja run <chain> "<ask>" [--model M]` | Starts a run **detached** and prints its id at once. The ask must contain a `Done means:` line |
| `smidja sessions` · `phases <id>` · `tail <id>` · `procs <id>` · `record <id>` | Watch a run |
| `smidja gates <id>` · `envelopes <id>` | See why a phase failed, and what each agent returned |
| `smidja pause <id>` · `steer <id> "msg"` · `continue <id>` | Hold a run, give it guidance, and let it go on |
| `smidja stop <id>` | Stops a run, its agents first |
| `smidja resume <id>` | Restarts a dead run at its last green phase |
| `smidja decide <id> <phase> approve\|decline` | Settles an `approval` phase |
| `smidja emergency-stop` | Kills every smithy process and sets the kill-switch. `smidja up` clears it |
| `smidja audit <id>` · `diagnose <id>` | Shows the tool-call evidence, why the run failed, and the fix |
| `smidja learn <id>` · `memory <project>` · `teach <project>` | Völundr's memory |
| `smidja kaia "msg"` · `admit <id>` · `recover <id>` | Talk to Völundr |
| `smidja agent new <name> --from <role> --purpose "…"` | Scaffolds a new role |
| `smidja mission T1\|T2` | Benches a team on a fixed task |
| `smidja view` (with `--on <host>`) | Opens the viewer, through an ssh tunnel when it is on another machine |

Add `--json` to any command for a machine-clean answer.

From Ymir's root, `scripts/smidja` is the same command.

## The MCP

The server is `smidja-mcp`, with 18 tools: `smidja_run`, `smidja_record`, `smidja_events`, `smidja_control`, `smidja_judge` and the rest. Every tool takes `on` to name another machine.

Install and every update seat it. To seat it by hand, run `apps/smidja-factory/scripts/install-doors.py`. That links `smidja` and `smidja-mcp` into `~/.local/bin` and adds `smidja` to pi's MCP set. The house's seating door (`bin/bridge/mcp-config.sh seat` and `bin/seat/hermes-seat.sh`) then carries the set into Claude Code, Codex, OpenCode, Cursor and Hermes. `--check` reports what would change and changes nothing.

## Limits

- A run is always launched detached, so a harness's tool-call timeout can never kill it.
- Teams, modes and services come from the config's own `stacks:`, `modes:` and `services:` blocks. The command keeps no second table of them. A team is made by interviewing the operator (`skills/create-new-teams`), never generated.
- `smidja model set` prints the variable to export. It never rewrites the config.
- `--on` needs the smithy installed on the far machine. `smidja doctor --on <host>` says whether it is.

## If it does not work

- **"the ask has no 'Done means:' line"**: say what finished looks like, or pass `--no-done-check`.
- **"the emergency kill-switch is set"**: fix what ran away, then run `smidja up`.
- **A run ends `fail` at once**: read the run's `launch.log`, whose path `smidja run` prints, then run `smidja diagnose <id>`.
- **Prompts missing in `doctor`**: run `smidja up`. It restores them from the factory's templates and never overwrites a prompt you tuned.

## CHANGE LOG

- **2026-11-19** — written: the command, the MCP, `--on`, and the doors installer.
