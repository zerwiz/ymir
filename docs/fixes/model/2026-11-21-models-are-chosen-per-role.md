# Models are chosen per role, from an ordered list in the home

**Date:** 2026-11-21 · **Component:** model · **Doors:** `bin/model/role-model.sh` (new), `src/ymir_runtime/role_config.py` (new),
`bin/agents/einherjar-spawn.sh`, `bin/agents/eindri-review-spawn.sh`, `bin/mcp/ymir-mcp.py`, `config/agents.yaml.example`,
`config/agents.schema.json` · **Tests:** `src/ymir_runtime/tests/test_role_config.py`, `bin/agents/tests/test_judge_coder_kit.sh`

## What was wrong

A user could name one model per figure. There was no way to say "the judge runs Claude, and if this machine cannot serve
it, a hosted model, then a local one", and the errand door defaulted every worker to one harness.

## What changed

- **`roles:` in `config/agents.yaml`** lists, per role (`judge`, `coder`, `scout`, `helm`), ordered `harness:model` choices.
  The first this seat can serve wins (Claude's allow-list, the pi catalogue, the opencode allow-list). A skipped choice is
  named; a list with none servable is refused. A per-machine file replaces a role.
- **One resolver**, `bin/model/role-model.sh`, is asked by the spawner, the errand door (`ymir_errand start` no longer
  forces `pi`), the review spine, and through the spawner by the review loop and the work loop. An explicit `--harness`
  or `--model` still wins. A home with no `roles:` entry keeps the older chain.
- Template and schema carry the block, with examples for local-only, hosted-only and mixed machines
  (`docs/reference/role-models.md`); the feature page is `docs/features/choose-the-models-your-judges-and-coders-run.md`.

## Proof

`test_role_config.py` (14 tests) and `test_judge_coder_kit.sh` (30 checks): first servable wins, skips named, refusal,
explicit wins, overlay replaces one role, a spawn on a planted home picks the second choice and prints it.
