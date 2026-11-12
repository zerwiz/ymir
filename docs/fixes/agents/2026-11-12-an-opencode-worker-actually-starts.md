## agents · unversioned · 2026-11-12 — an OpenCode worker actually starts: one launcher, four callers (plan 262)

### Why

On 2026-11-12 an audit errand seated on OpenCode and its pane printed
`Unrecognized flag: --model in command opencode`. The worker died before it read its brief, and the
dispatcher still reported a seat (Rule 37: a surface may not show what it did not receive).

OpenCode v2.2.7 split its entry points. The interactive TUI (`opencode [dir]`) takes `--prompt` and `--auto`
but not `--model`. Only `opencode run` takes `-m`. Ymir started OpenCode from four doors and each built its own
shape. The 2026-11-06 mend fixed one of them, and the other three drifted:

| Door | Shape before | State |
|---|---|---|
| `einherjar-spawn.sh` | `opencode run --model … --auto` | ran, but one shot nobody could steer |
| `src/ymir_runtime/harness.py` | `opencode --model … --prompt` | broken |
| `bin/seat/herdr-run.sh` | `hdr agent start --kind opencode -- --model …` | broken |
| `eindri-start.sh` tmux fallback | `exec opencode` | started empty: no model, no brief |

Two more faults turned up the same night. `eindri-start.sh` never passed `--kind` to `herdr-run.sh`, so
`agents.yaml`'s harness won over an explicit `--kind pi`. And `--kind claude` without `--model` was refused,
because the model the fleet resolves for a role is a `provider/model` token and Claude takes an Anthropic alias.

### The fix

Main's #679 landed the one launch door while this was in flight: `bin/seat/opencode-launcher.sh` prints
`env OPENCODE_CONFIG_CONTENT=… opencode run [--model M] --auto "<brief>"`, with a `--model free` road. This note
keeps that door and adds only what main still lacked:

1. `bin/seat/herdr-run.sh` no longer runs `hdr agent start --kind opencode -- --model …`, which carries no
   environment and passes the flag OpenCode refuses. It runs the launcher's line with `hdr pane run`, then counts the
   seat only after `seat-prove.sh` finds the agent. No agent is a refusal, not a seat.
2. An explicit `--kind` wins over `agents.yaml` and over the resolved model's provider. `eindri-start.sh` passes it
   down to `herdr-run.sh`.
3. The tmux fallback in `eindri-start.sh` no longer runs a bare `exec opencode`, which started empty with no model
   and no brief. It runs the launcher's line.
4. An exact `provider/model` token for an OpenCode seat is used verbatim when `opencode models` lists it, and refused
   when it does not. The friendly-name resolver answered `opencode-go/deepseek-v4.1-flash` for
   `opencode/deepseek-v4.1-flash-free`, a different and paid model, and pi's catalog does not list the `opencode/`
   provider at all. `opencode-launcher.sh has <token>` asks OpenCode itself.
5. `bin/gates/tests/test_opencode_launcher.sh` is a CI gate: every door that seats OpenCode prints the launcher's
   line, and the version guard bites against stubs. Eir has a new `opencode` surface that reads
   `opencode-launcher.sh check`, so a drifted OpenCode is a red surface, not a dead pane.

`opencode run` is one shot: the worker cannot be steered, and a quick errand's agent may be gone before the proof
looks. A steerable interactive shape (the model in config, `--auto --prompt`) was built and proved first, but it was
dropped in favour of main's door. It is a choice for the Allfather, not settled here.

### Proof

`bin/agents/eindri-start.sh "write OK to a file named OK.txt in your working directory and stop" --role ocproof
--kind opencode --model opencode/deepseek-v4.1-flash-free` seated a worker in herdr (`herdr agent list` showed
agent `opencode`, pane `w12:p2`, name `ocproof`). It wrote `OK.txt` containing `OK` and its report file, then
stopped. Proved on nidavellir. Not yet proved on heimdall.

## CHANGE LOG

- **2026-11-12** — note written (plan 262), then reduced after rebasing onto main's #679: the herdr door runs the
  launcher's line and proves the agent, an explicit `--kind` wins, the tmux fallback runs the launcher's line, exact
  models are checked with `opencode models`, and the parity test and Eir's `opencode` surface guard it. Not settled:
  one-shot versus steerable workers, and the proof is nidavellir only.
