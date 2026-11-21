# forge · 2026-11-21 — the smithy can be run from the agent tool and the phone

## What changed

The Allfather asked to run the smithy simply when out and about, for bigger tasks, and to choose whether its agents work in visible herdr panes or headless inside the engine. The smithy lives in its own repository, so the change is in two places.

| Where | Change |
|---|---|
| `bin/forge/team-run.sh`, `team-run.py` | New door. Runs the smithy on a named machine or the least loaded (`--on auto`) over ssh through that machine's own install. Verbs `run`, `status`, `tail`, `stop`, `where`. Answers with run id, machine, runtime, state and link; `--phone` gives at most six lines |
| `.pi/extensions/team-run.ts` | The Pi tool `ymir_team_run`, a thin call to the door |
| `bin/mcp/ymir-mcp.py` | The MCP tool `ymir_team_run`, the same call |
| `config/smidja-machine.yaml.example` | The shape of a machine's `smidja.yaml` in the home: default runtime, ssh name, project, published link |
| `docs/features/run-the-smithy-from-anywhere.md` and the catalogue entry `02-133` | The feature page and its row (Rule 14) |
| smithy repo, PR 9 | `smidja run --task`, `smidja status`, the `--runtime internal|herdr` choice, an optional herdr seat road, and two fixes found by the run audit |

## Why

The smithy had a command with `run`, `tail` and `stop`, but no short form for a phone message, no `status`, and no way to pick where its agents work. The door needed to reach a chosen machine without opening any port, so it uses ssh and each machine's own install.

## Law kept

- The public repository names no host and no person. Machines, ssh names, projects and links are read from the home.
- A herdr request that cannot be served is a refusal, never a silent fallback to the other runtime.
- Starting a run is not a merge. Delivery still goes by pull request (RULES/08).

## Proof

`python3 bin/forge/tests/test_team_run.py` runs 14 checks against a stand-in smithy and a stand-in ssh: the runtime comes from the machine's config and a flag overrides it, a remote run goes through the machine's ssh name, `auto` takes the least loaded, the link is published or says it is local, the phone answer is six lines or fewer and names the runtime, and a later status finds the machine.

A live run on this machine started through the door with each runtime, and both finished. The herdr run seated its agent in a real workspace. During the later runs the first model's key limit was reached and the house's model fallback answered, so those two summaries differ; the first herdr run, made before that, gave the same answer as the internal one. The ssh road to a second machine was proved by reaching its smithy; that machine still has the older smithy, so a full run there waits for the smithy PR to merge and `bin/apps/apps.sh update smidja` to run.
