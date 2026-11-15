# Runbook — setting up agents

An **Eindri** is a worker profile. Profiles live in one canonical place and are
symlinked into each harness.

## Where agents live

- **Canonical:** `.agents/agents/<name>-<craft>.md` (edit these only).
- **Bindings:** `.opencode/agents/*.md` and `.pi/agents/*.md` are symlinks.

Rebind after any change:

```bash
bin/seat/valknut-load.sh --all
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
3. `bin/seat/valknut-load.sh --all` to bind it into OpenCode + Pi.
4. Register it in `.agents/skills/galdr-ymirsystem/assets/registry.md` if it is durable.

## Run an agent

```bash
bin/agents/agent-run.sh hnoss "design a compact hero"   # harness+model from agents.yaml
```

Local models run through `pi`, hosted through `opencode` (see the **models**
runbook). `mode: all` lets an agent be dispatched *and* driven directly.

## Dispatch to a live pane (herdr)

```bash
bin/agents/eindri-start.sh "design a landing page"       # one command: role -> seat -> run
bin/agents/eindri-start.sh "…" --pane | --tab | --space  # seat a pane / tab / workspace
bin/agents/eindri-start.sh "…" --project <path|id|alias> # seat a worker for THAT project
bin/agents/eindri-start.sh "…" --project <project> --dry-run   # print the seat plan, seat nothing
```

## What every brief carries: the Bearings

A brief is not only the errand. `eindri-start.sh` prepends a generated **Bearings** section on
every road and for every harness, and the engine does the same for an errand seated through
`bin/agents/einherjar-spawn.sh`. It has three parts, in this order:

| Part | What it says | Where it comes from |
|---|---|---|
| (a) the fixed core | the two repositories and their two laws, the pin, panes and the stamped send door, the arm, the desk guard, the finding tools, and the laws to keep in view | the shipped, agnostic `.agents/assets/agents/eindri-core.md`, then the home's overlay `$YMIR_HOME/config/eindri-core.md` |
| (b) the project's records | decisions, handoff, schedule, plans, plan status, docs index, meetings, seat, boards, and who merges — each with the duty *read before you write, update before your report* | the row's `records:` block in `$YMIR_HOME/hodd/identity/projects.yaml` |
| (c) the home's document map | the layout shelves, the knowledge index, the atlas, the plan ledgers and the report shelf | `$YMIR_HOME/.ymir-layout.yaml`, `hodd/docs/INDEX.md`, `svartalfaheim/*/projects/*/plans/README.md` |

Read it back, or ask one part for one project:

```bash
bin/agents/eindri-bearings.sh --check                 # is every door this section reads answering?
bin/agents/eindri-bearings.sh <path|id|alias>         # the section, as the brief gets it
bin/agents/eindri-bearings.sh --marker                # the marker that stops a brief being doubled
```

**A project with no `records:` block is said plainly, never guessed at.** The section names the
registry row to add, and the keys it takes (`in_repo`, `in_home`, `boards`, `merges`). A worker
whose errand changed no record writes `none: <reason>`; the handoff packet refuses a packet without
the line.

## A worker for another project sits in THAT project's folder

An errand for a project that is not Ymir is seated in that project's **own repository**, in a
worktree made by that project's own convention — never in a worktree of Ymir's tree, so its commits
cannot land in the wrong repository.

```bash
bin/agents/project-target.sh resolve  <path|id|alias>        # this machine's clone, its id, its kind
bin/agents/project-target.sh records  <path|id|alias>        # the project's records, with the duty
bin/agents/project-target.sh worktree <path|id|alias> <id>   # make/reuse the worktree, print it
bin/agents/project-target.sh worktree <…> <id> --dry-run     # plan it, make nothing
```

The convention is declared in the registry row, never in the code:

```yaml
worktree:
  command: scripts/worktree.sh new {id}   # optional; run in the clone
  path: .yggdrasil/{id}
  branch: agent/{id}
```

With no block the default is `git worktree add -b eindri/<id> <clone>/.yggdrasil/<id>`. A row with
no clone on this machine is **refused**, with the row named — a worker is never seated somewhere
else and told it is home.

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
- **2026-11-14** — two sections added: *What every brief carries: the Bearings* (the generated section every errand gets — the shipped core and the home's overlay, the project's records, the home's map) and *A worker for another project sits in THAT project's folder* (the project resolved to this machine's clone, the worktree made in that repository by the project's own convention). Plan 291 parts 2 and 3; the doors are `bin/agents/eindri-bearings.sh` and `bin/agents/project-target.sh`.
