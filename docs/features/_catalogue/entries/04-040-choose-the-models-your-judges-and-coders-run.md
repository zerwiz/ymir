---
section: fleet-models
---
| Models | **Choose the models your judges and coders run** (`bin/model/role-model.sh` · `roles:` in `config/agents.yaml`) | Each role (`judge`, `coder`, `scout`, `helm`) lists ordered `harness:model` choices in your home; the first one this machine can serve wins, a choice it cannot serve is skipped and named, never silently replaced, and `--harness/--model` still wins. One resolver serves the errand door, the spawner, the review spine, the review loop and the work loop; a per-machine file overrides one role. `yolo` (on for coders by house default) makes the worker run with no permission prompts while every deny rule still holds; each spawn prints the posture that took effect. Judges and coders are also handed the same kit: the figure's card, the books to read first for the paths in play, and the plans the PR claims | [Choose the models your judges and coders run](docs/features/choose-the-models-your-judges-and-coders-run.md) |

## CHANGE LOG

- 2026-11-21 — added with the role resolver (docs/reference/role-models.md has examples for local-only, hosted-only and mixed machines).
