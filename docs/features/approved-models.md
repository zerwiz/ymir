# Approved models — which models an Eindri may run on

## What it is

Every Eindri runs on a model, and some models cost money per token. The **allow-list** is your
own list of the models a worker may use. A spawn that asks for any other model is refused
before anything is created, and the refusal names the model and tells you how to allow it.

The list is **your setting**, kept in your home, never in the code tree. Each user writes
their own. Ymir ships only a template.

> [!IMPORTANT]
> With no list written, nothing is policed. The doctor reports that as `unpoliced`, so
> write a list if any of your models cost money.

## What you need

- Your home (`$YMIR_HOME`, by default `~/Documents/ymirhome`).
- A file at `<home>/config/models-allowed.yaml`. Copy `config/models-allowed.yaml.example` to start.

## Do it

```bash
bin/model/model-allow.sh path                                   # where your list lives
bin/model/model-allow.sh list                                   # what it allows, its defaults, its grants
bin/model/model-allow.sh check opencode-go/deepseek-v4-pro      # may a worker use this? exit 3 = refused
bin/model/model-allow.sh check opus --harness claude            # a Claude alias resolves to the allowed id
bin/model/model-allow.sh default claude                         # the model a Claude worker gets by default
bin/model/model-allow.sh audit                                  # live seats and configured defaults off the list
```

A list that allows one paid cloud model, the free local rail and one Claude model looks like this:

```yaml
version: 1
allow:
  - opencode-go/deepseek-v4.1-flash
  - llama-swap/*
  - llamacpp-*/*
  - claude/claude-opus-5-5
defaults:
  claude: claude-opus-5-5
grants: []
```

## How models are named

| Harness | Form in the list | Example |
|---|---|---|
| pi, opencode | `provider/model`, as the catalogue lists it; globs allowed | `llama-swap/*` |
| claude | `claude/<model-id>` | `claude/claude-opus-5-5` |

For the Claude harness, the aliases `opus`, `sonnet`, `haiku` and `fable` resolve to the first
allowed Claude id of that family. An alias with no allowed id is refused. Claude never takes
another harness's model: `opencode-go/...` handed to Claude is refused.

## Special permission — a grant

To use a refused model once and on purpose, write a grant in the same file:

```yaml
grants:
  - model: opencode-go/deepseek-v4-pro
    reason: one migration that the flash model failed twice
    granted_by: Allfather <name>
    granted_at: 2026-11-12
    expires: 2026-11-13
    uses: 1          # optional: how many errands may launch on it
```

Every field except `uses` is required. A grant past its `expires` date, or with a field
missing, is ignored, and the refusal says why. Each errand launched on a grant is written to
`<state>/model-allow.log`, and one errand counts as one use however many doors ask.

No environment variable allows a model. The file is the only way.

## Where it is enforced

| Door | What happens |
|---|---|
| `bin/agents/einherjar-spawn.sh` | refuses before the worktree is made; a raw launch command's `--model` is checked too |
| the engine (`bin/engine/ymir-engine.sh seat`) | refuses before the worktree is made |
| `bin/agents/eindri-start.sh` and `bin/seat/herdr-run.sh` | refuse before a pane opens |
| `bin/agents/agent-run.sh` | refuses before the harness runs |
| `bin/model/model-resolve.sh` | answers `allow: refused` and exits 3 |
| `bin/model/agent-model.sh` | picks only from allowed models, for every tier, row and default |
| `bin/agents/eir-doctor.sh` | surface `models`: broken when a live seat or a configured default is off the list |

## If it does not work

- **`refused: model '…' is not on this fleet's allow-list`**: add the model to `allow:`, or write a grant.
- **`the claude harness names no model and the allow-list has no defaults.claude`**: set `defaults: {claude: <id>}`.
- **`the allow-list does not parse`**: the file is refused as a whole (it fails closed). Run `bin/model/model-allow.sh list` to see the error.
- **Eir says `unpoliced`**: no list is written yet. Copy the template.
