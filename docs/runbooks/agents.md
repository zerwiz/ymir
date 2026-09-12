# Runbook — setting up agents

An **Eindri** is a worker profile. Profiles live in one canonical place and are
symlinked into each harness.

## Where agents live

- **Canonical:** `.agents/agents/<name>-<craft>.md` (edit these only).
- **Bindings:** `.opencode/agent/*.md` and `.pi/agents/*.md` are symlinks.

Rebind after any change:

```bash
bin/valknut-load.sh --all
```

## A profile's frontmatter

```yaml
---
mode: all            # primary | subagent | all  (all = runnable AND dispatchable)
model: llama.cpp/frontend-design-expert-8b
domain: utgard       # one of the eight Greinar (see RULES/01-domains.md)
name: hnoss
description: "..."
permission:          # read/write/edit/glob/grep/bash/skill: allow|deny
  read: allow
  edit: allow
ymir_tools:          # Ymir capabilities (NOT opencode built-ins; never `tools:`)
  - opendesign
---
```

OpenCode rejects `tools:` as a list — Ymir capabilities go under **`ymir_tools:`**.

## Add an agent

1. Write `.agents/agents/<name>-<craft>.md` (copy a neighbour).
2. Give it a `model` (or leave it to inherit `default_model`) and a `domain`.
3. `bin/valknut-load.sh --all` to bind it into OpenCode + Pi.
4. Register it in `.agents/skills/galdr-cli-cli/assets/registry.md` if it is durable.

## Run an agent

```bash
bin/agent-run.sh hnoss "design a compact hero"   # harness+model from agents.yaml
```

Local models run through `pi`, hosted through `opencode` (see the **models**
runbook). `mode: all` lets an agent be dispatched *and* driven directly.

## Dispatch to a live pane (herdr)

```bash
bin/eindri-start.sh "design a landing page"       # one command: role -> seat -> run
bin/eindri-start.sh "…" --pane | --tab | --space  # seat a pane / tab / workspace
```
