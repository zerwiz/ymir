# A simple errand on Sonnet, and a free road for Pi and OpenCode

**Date:** 2026-11-12 · **Component:** model

## The fault

Two gaps, found the night Pi's paid tokens ran out with two hours to their refresh:

1. A Claude worker given no model ran on Claude's own default (Opus) for every chore. The Allfather: *"do simple
   tasks on Sonnet, add that to Claude's logic in starting sub-agents for ymir."*
2. A worker had no road when the paid tokens were spent. The Allfather: *"add free models for both Pi and OpenCode."*

## The change

- **Claude by weight** — `claude_model_for` in `src/ymir_runtime/harness.py`, and its twin in
  `bin/agents/einherjar-spawn.sh`: no `--model` and effort none/low/medium → `sonnet`; effort high/xhigh/max →
  `opus`. An explicit `--model` always wins; a `provider/model` token or `free` is refused for Claude.
- **`--model free`** — for pi and opencode, picked by **`bin/model/free-models.sh pick <pi|opencode>`** from the live
  catalog (`opencode models`, `bin/model/catalog.sh`): a model is free when its name ends `-free` or `:free`. The
  preference is `YMIR_FREE_MODELS_PI` / `YMIR_FREE_MODELS_OPENCODE`, else a shipped default; a missing preference is
  skipped, and with no `--harness` a free errand goes to opencode.
- **`bin/agents/eindri-start.sh --kind claude`** no longer asks the role resolver for a model: it handed the engine
  a `provider/model` token as an explicit `--model`, which the engine must refuse, so a Claude errand died before it
  was seated. The engine now picks by weight; `--effort` is carried through.
- The Claude hook's refusal (`.claude/hooks/eindri-only.sh`) names the weight rule and the free road, so a Claude seat
  learns them where it learns the Eindri road.

## Proof

Dry runs of `einherjar-spawn.sh`: plain Claude → `sonnet`; `--effort high` → `opus`; `--model free` →
`opencode/deepseek-v4.1-flash-free`; `--harness pi --model free` → `opencode-go/longcat-2.5-free`. Unit tests in
`test_harness.py` cover each case.

## CHANGE LOG

- **2026-11-12** — note written: Claude by weight (sonnet, opus for heavy effort), `--model free` for pi and opencode, and the Claude road in `eindri-start.sh` mended.
