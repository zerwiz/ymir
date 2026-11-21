# Run the smithy from anywhere — the agent tool and the phone

You can start a smithy run, follow it, and stop it from any agent tool or from your phone. The smithy runs on the machine you choose. You choose, per run, whether its agents work headless or in panes you can watch.

## What it is

The smithy is its own program, installed on each machine. `bin/forge/team-run.sh` is the one door that starts it on a machine and answers with a short record: run id, machine, runtime, state and link. Three faces call that door and give the same answer:

- the Pi tool `ymir_team_run`;
- the MCP tool `ymir_team_run`, for every other agent tool;
- the shell command, for you.

Use it for bigger tasks. A small edit is faster done in the session itself.

## What you need

- The smithy installed on the machine that will run it: `bin/apps/apps.sh install smidja`.
- A smithy new enough to know `smidja run --task` and `smidja status`. Machines on an older install answer "unknown verb"; update them with `bin/apps/apps.sh update smidja`.
- Optional, per machine: `$YMIR_HOME/config/machines/<host>/smidja.yaml`. The shape is in `config/smidja-machine.yaml.example`. It sets the default runtime, the ssh name, the project, and the published link.

## The runtime choice

| Runtime | What happens | When to pick it |
|---|---|---|
| `internal` | The smithy's own engine runs every agent headless, inside its process. | The default. Nothing to watch, nothing to clean up. |
| `herdr` | Each agent turn is seated in a pane of a herdr workspace named `smidja <run id>` on that machine. | You want to watch the agents work, or step in. |

The default comes from the machine's `smidja.yaml`, then falls back to `internal`. `--runtime` overrides it for one run. Every answer names the runtime that is running. If you ask for `herdr` and herdr is not running on that machine, the run is refused. It never quietly becomes `internal`.

## The commands

```bash
bin/forge/team-run.sh run --task "add a /health endpoint" --on auto --project ~/work/example
bin/forge/team-run.sh run --task "tidy the docs" --on host-a --runtime herdr --project ~/work/example
bin/forge/team-run.sh status <id>
bin/forge/team-run.sh tail <id>
bin/forge/team-run.sh stop <id>
bin/forge/team-run.sh where
```

`--on auto` picks, among this machine and every machine with a `smidja.yaml`, the one with the lowest load per core. `where` lists them with their load and default runtime. Add `--phone` for the short answer or `--json` for a machine-readable one.

## From your phone

Ask the agent that holds the arm. It calls `ymir_team_run` with `phone` on, and the answer is at most six lines:

```text
Smithy run 3f2a91c0 started on host-a.
Runtime: herdr (agents seated in visible herdr panes).
Team: (default) · chain: plan-build-test
State: running
Machine chosen by lowest load per core (0.31).
Follow: https://smithy-host-a.example.org/#/sessions/3f2a91c0
```

Then say "status", "tail" or "stop" for that run. The door remembers which machine each run went to, so you do not repeat it.

## The link

The link is the machine's own published smithy address from its `smidja.yaml`, with the run's path added. When no address is published, the link is the machine's loopback address and the answer says it is local to that machine. Publishing it behind a sign-in is a separate piece of work and is not done here.

## Limits

- A run needs a project path on the chosen machine, from `--project` or the machine's `smidja.yaml`.
- Starting a run is not asking for a merge. The smithy's agents change files in that project; review them as you would any change.
- `stop` under the `herdr` runtime is tracked as an open issue on the smithy's repository. Close the pane too if an agent keeps going.

## If it does not work

| You see | Do this |
|---|---|
| `the smithy is not installed on <host>` | Run `bin/apps/apps.sh install smidja` on that machine. |
| `unknown verb 'status'` | That machine has an older smithy. Run `bin/apps/apps.sh update smidja` there. |
| `ssh to <host> failed` | Check the ssh name. Set `ssh:` in that machine's `smidja.yaml`. |
| `the herdr runtime was asked for and cannot be had` | Start herdr on that machine, or run with `--runtime internal`. |
| `no project for <host>` | Pass `--project`, or set `project:` in `smidja.yaml`. |
