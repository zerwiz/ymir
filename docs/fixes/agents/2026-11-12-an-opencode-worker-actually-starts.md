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

1. `bin/seat/opencode-launcher.sh` prints the one interactive shape:
   `env OPENCODE_CONFIG_CONTENT='{"model":"<m>","permission":{…}}' opencode --auto --prompt "$(cat <brief>)"`.
   The model rides in the inline config and the brief is the first turn. The permission block is the shipped
   `.agents/harnesses/opencode-worker.permission.json`, the twin of the Claude worker profile: the worker acts
   without a prompt, and a push to main, a merge, a force-push, `git add -A` and a discard of unrecorded work are
   denied. A missing profile is a refusal.
2. All four doors call it and none builds an opencode line of its own: `einherjar-spawn.sh` (and its dry run),
   `harness.py`, `herdr-run.sh` and the tmux fallback in `eindri-start.sh`.
3. `herdr-run.sh` runs the shape with `hdr pane run` (`hdr agent start` carries no environment) and counts the
   seat only after `seat-prove.sh` finds the agent. No agent is a refusal, not a seat.
4. An explicit `--kind` now wins over `agents.yaml` and over the resolved model's provider. `eindri-start.sh`
   passes it down. `--kind claude` with no `--model` defaults to the alias `sonnet` (`YMIR_CLAUDE_DEFAULT_MODEL`).
   A provider/model token the operator typed for Claude is still refused.
5. An exact `provider/model` token for an OpenCode seat is used verbatim when `opencode models` lists it, and
   refused when it does not. Measured: the friendly-name resolver answered `opencode-go/deepseek-v4.1-flash`
   for `opencode/deepseek-v4.1-flash-free`, which is a different and paid model, and pi's catalog does not list
   the `opencode/` provider at all. `opencode-launcher.sh has <token>` asks OpenCode itself.
6. The guards: `bin/gates/tests/test_opencode_launcher.sh` (the parity test over the doors, the version guard
   against stubs) is a CI gate, and Eir has a new `opencode` surface that reads `opencode-launcher.sh check`.
   A TUI that loses `--prompt` or `--auto` is a red surface, not a dead pane.

### Proof

`bin/agents/eindri-start.sh "write OK to a file named OK.txt in your working directory and stop" --role ocproof
--kind opencode --model opencode/deepseek-v4.1-flash-free` seated a worker in herdr (`herdr agent list` showed
agent `opencode`, pane `w12:p2`, name `ocproof`). It wrote `OK.txt` containing `OK` and its report file, then
stopped. Proved on nidavellir. Not yet proved on heimdall.

## CHANGE LOG

- **2026-11-12** — note written (plan 262): one OpenCode launcher and four callers, an explicit `--kind` that wins, a
  verbatim exact model token checked against `opencode models`, the parity test and Eir's `opencode` surface.
  Not yet settled: a free model is not guaranteed, because the project's default agent `brokk` overrides the inline
  config model; and the proof so far is nidavellir only.
