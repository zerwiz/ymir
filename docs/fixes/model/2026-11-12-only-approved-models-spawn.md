# Only approved models spawn, and Claude gets its own model

**2026-11-12 · component: model · `bin/model/model-allow.sh`, `src/ymir_runtime/allow.py`, `bin/agents/einherjar-spawn.sh`**

## What was wrong

The OpenCode Go monthly credit was spent in one night. Four errands ran on
`opencode-go/deepseek-v4-pro` on 2026-11-11, between 21:04Z and 23:06Z. Each was launched
with an explicit `--model`, and no door asked whether that model was approved. Nothing in the
house could refuse a model. A door could only ask whether the machine was able to serve it.

`bin/model/agent-model.sh` made it worse: its `strong` tier reached for `opencode-go/.*pro` first.

A second defect sat beside it. `einherjar-spawn.sh --harness claude` handed Claude pi's
model. It took the machine default (`opencode-go/deepseek-v4.1-flash`) from `agents.yaml`,
and `--model opus` was sent to `bin/model/model-resolve.sh`, which knows only the pi
catalogue and refused it. Eight Claude seats since 2026-11-11 carry pi's model in their record.

The Allfather's word on 2026-11-12: only `opencode-go/deepseek-v4.1-flash`, the local rail, and
Claude Opus 5.5 may run as Eindri, and any other model needs special permission.

## What it does now

- **One list, in the operator's home.** `<home>/config/models-allowed.yaml` holds `allow:`
  globs, `defaults:` per harness and dated `grants:`. The repo ships only
  `config/models-allowed.yaml.example`. The rule is in `src/ymir_runtime/allow.py`, and the
  shell door is `bin/model/model-allow.sh` (`check`, `default`, `list`, `audit`, `filter`, `path`).
- **A grant is on the record.** A grant needs a model, reason, granted-by, granted-at and an
  expiry date. It may also cap `uses`. Every errand launched on a grant is written to
  `<state>/model-allow.log`, once per errand. No environment variable allows a model.
- **Every door asks.** These are the spawner (before the worktree is made, and for a raw
  launch command's `--model` too), the engine's `seat`, `herdr-run.sh`, `agent-run.sh`,
  `model-resolve.sh` (exit 3 with `allow: refused`), and `agent-model.sh`, whose catalogue is
  filtered through the list so no tier can pick a refused model.
- **Claude gets its own model.** With `--harness claude` the spawner never takes another
  harness's model. With no `--model` the list's `defaults.claude` is used. `opus` resolves to
  the allowed Opus id. `sonnet`, `haiku`, `fable` and any `provider/model` are refused.
- **Eir reports it.** The `models` surface is broken when a live seat, a row in
  `agents.yaml` or pi's default model is off the list.

A list that exists but does not parse is a refusal: it fails closed. No list at all is
`unpoliced`, which is allowed, said out loud, and reported by Eir. That keeps a fresh
install working until its operator writes a list.

## Proved

- `bash tests/test_model_allow.sh` → `17 ok · 0 failed · 0 skipped`. That run covers pro
  refused by the spawner with the reason, pro allowed on a dated grant and logged, a one-use
  grant spent by one errand, flash unchanged, `--harness claude` given `claude-opus-5-5` with no
  `--model`, `--model opus` resolving to `claude-opus-5-5`, and sonnet, haiku, fable and
  `opencode-go/…` refused for Claude.
- `python3 -m unittest ymir_runtime.tests.test_allow` → 14 tests OK, and
  `test_seat`, `test_harness` and `test_cli` still pass (48 tests).
- `bin/agents/eir-doctor.sh check` against the live state, with the operator's list: the
  `models` surface is broken and names the Claude seats recorded on pi's model.

## Not done

- A seat that a pi or opencode session launches by hand, outside every Ymir door, is not
  gated. Its spend is the harness's own setting.
- `herdr-run.sh` with no model named runs pi's own default. Eir's audit checks that default
  against the list, but the launch itself is not refused.
