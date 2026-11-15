# Runbook — sending an Eindri

An **Eindri** is a worker: one errand, its own worktree, its own pane, a branch nobody else touches.
This page is how the house sends one — what the seat needs, what the brief carries, where the worker
sits, and what it owes back.

> [!IMPORTANT]
> A worker never merges. It commits on its own branch and **does not push**; the helm gathers the
> branches into one pull request, and a reviewer seals it. See
> [the wards and the gate](gates-and-wards.md).

## Before you send one

| You need | Why |
|---|---|
| the errand, written as a brief | the brief is the contract: task, delivery mode, definition of done |
| the **project** the work belongs to | it decides the clone, the worktree, the records and the branch |
| a **helm** alive on this machine | an errand with nobody to report to is refused (`no helm, no errand`) |

The project is named by a path, a project id or an alias, and is resolved through the registry
(`$YMIR_HOME/hodd/identity/projects.yaml`) to **this machine's** clone:

```bash
bin/agents/project-target.sh resolve <path|id|alias>     # path, id, kind, how it was found
```

## Send one

```bash
bin/agents/eindri-start.sh "<the errand>" --project <path|id|alias> --id <errand>
bin/agents/eindri-start.sh "<the errand>" --project <path|id|alias> --id <errand> --dry-run
```

`--dry-run` prints the seat plan — the project, its clone, the worktree, the branch, the folder the
pane opens in, the harness, the model, and whether the brief carries its bearings — and seats nothing.
Read it before you send anything expensive.

The other roads (a full brief with `# Task` and `# Delivery contract` sections, or the engine directly)
are in [agents.md](agents.md); every one of them ends in the same three things: a worktree, a pane, a
record.

## A worker for another project

A worker for a project that is **not Ymir** is seated in **that project's repository**, in a worktree
made by that project's own convention. It never gets a worktree of Ymir's tree, so its commits cannot
land in the wrong repository, and its branch and PR belong to the project it was sent to.

```bash
bin/agents/project-target.sh worktree <path|id|alias> <errand>            # make or reuse it
bin/agents/project-target.sh worktree <path|id|alias> <errand> --dry-run  # plan it
```

The convention is declared on the project's registry row, never in the code:

```yaml
worktree:
  command: scripts/worktree.sh new {id}   # optional: the project's own maker, run in the clone
  path: .yggdrasil/{id}                   # where it lands, relative to the clone
  branch: agent/{id}                      # the branch it stands on
```

With no block the default is `git worktree add -b eindri/<id> <clone>/.yggdrasil/<id>`.

A project whose registry row has **no clone on this machine** is refused, and the row is named — a
worker is never seated somewhere else and told it is home. The project's own `AGENTS.md` and rules
govern it once it is there.

## Bearings — what every brief carries

Every errand's brief opens with a generated **Bearings** section (`bin/agents/eindri-bearings.sh`),
prepended by `eindri-start.sh` on every road and by the engine for an errand seated through
`bin/agents/einherjar-spawn.sh`. It has three parts:

| Part | What the worker gets |
|---|---|
| the fixed core | the two repositories and their two laws, the pin, panes and the stamped send door, the arm, the desk guard, the finding tools, and the laws to keep in view — the shipped `.agents/assets/agents/eindri-core.md`, then this fleet's own overlay `$YMIR_HOME/config/eindri-core.md` |
| the project's records | decisions, handoff, schedule, plans, plan status, docs index, meetings, seat, boards, and who merges — from the row's `records:` block, each with the duty *read before you write, update before your report* |
| the home's document map | the layout shelves, `hodd/docs/INDEX.md`, the atlas, the plan-ledger READMEs, and the report shelf |

A project with no `records:` block is said plainly — the section names the registry row to add and
never invents a path.

```bash
bin/agents/eindri-bearings.sh --check              # is every door the section reads answering?
bin/agents/eindri-bearings.sh <path|id|alias>      # the section, exactly as the brief gets it
```

## What the worker owes back

- A **report** at `$YMIR_HOME/state/eindri-reports/<errand>.md`, written by its terminal act.
- A **records updated** line — each of its project's records the work changed, or
  `none: <why no record changed>`.
- A **handoff packet** (`bin/forge/handoff-packet.sh write <errand> …`) whose `records[]` block
  carries the same paths. `check` refuses a packet without it, and refuses an empty block or a
  `none` with no weighable reason.
- One line to the helm: `bin/agents/eindri-send.sh --from "agent <errand>" <pane> "<result>"`.

## If something goes wrong

| Symptom | Do this |
|---|---|
| the seat printed `interactive_ready: false` | the harness had not drawn its input box; the launcher waits, then retries the prompt once — if it is still false, read the pane (`herdr agent read <pane>`) |
| the worker sits idle with no work | the prompt was swallowed before the harness was ready; send it once more through `bin/agents/eindri-send.sh` |
| `no clone on <host>` | add `clones.<host>` to that project's registry row, or pass the clone's path |
| `the engine declined` | the brief has no `# Task` section; write the errand into the brief, then retry |
| the worktree was made in the wrong repository | the project resolved as `kind=ymir` or not at all — check `bin/agents/project-target.sh resolve <token>` |

## CHANGE LOG

- **2026-11-14** — written (plan 291 rows 5 and 25): the seat road, *a worker for another project*,
  *bearings — what every brief carries*, what the worker owes back, and the symptoms seen that day.
