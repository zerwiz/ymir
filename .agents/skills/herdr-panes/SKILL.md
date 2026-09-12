---
name: herdr
description: >-
  Herdr — the terminal multiplexer that hosts Ymir's agent panes. Load when
  inspecting or controlling panes, tabs, workspaces, or a running agent; when
  seating an Eindri visibly beside the work (pane/tree/tab/space); or when
  starting a coding agent in a pane. Requires HERDR_ENV=1 (you must be inside a
  herdr pane). Read this before using the herdr CLI.
allowed-tools: read,write,bash,glob,grep
---

# herdr-panes — terminal panes — seat/control panes, tabs, workspaces, agents (HERDR_ENV=1)

Herdr is a mouse-first, agent-aware terminal multiplexer: a background server
owns the terminals, clients attach, and it recognises coding agents in panes.
`herdr` is the upstream name (aka `hdr`); it is the backend behind Þjazi.

## First law

Control only works from **inside** a herdr pane:

```bash
test "${HERDR_ENV:-}" = 1      # else: say you are outside and stop
```

Inside, `herdr` talks to the current session. The binary is the authority —
`herdr --skill` prints this contract, `herdr agent|pane|tab|workspace` prints
each command group. Don't run bare `herdr` (it launches the TUI).

## The hierarchy

`Session > Workspace (w1) > Tab (w1:t1) > Pane (w1:p1)`. A **pane** is a real
terminal; an **agent** is a process herdr recognises inside one. `agent start`
needs an existing shell pane — it never creates layout.

## Seat an agent where you can see it

```
seat-roads[4]{mode,how,use}:
  "pane","herdr pane split --current --direction right","one agent beside the work"
  "tree","recursive splits (parent + children)","a coordinator with its workers, visible as a tree"
  "tab","herdr tab create --label ...","a workstream off to the side"
  "space","herdr workspace create","a disposable space for one errand"
```

Then:

```bash
herdr pane split --current --direction right --cwd "$PWD"   # -> .result.pane.pane_id
herdr agent start <name> --kind pi --pane <pane> -- --model <provider>/<id>
herdr agent prompt <name> "<task>"
herdr agent list            # states: working · blocked · done · idle · unknown
```

## In Ymir

- `bin/pi-seat.sh [--tab] [--task …]` — seat a pi agent (local model) visibly.
- `bin/eindri-start.sh "<task>" [--pane|--tab|--space]` — role → seat → task.
- `bin/pi-local.sh` — run a local model headless (print mode).
- One **local model at a time per machine** — see `bin/local-model-lock.sh` and
  `local_concurrency` in `config/agents.yaml`. Different machines, different
  models; local inference is serialized on a box.
