# Skírnir becomes a system

**Date:** 2026-10-31 · **Component:** assistant · **Status:** moved; shims retired by a dated note

## Why

The Allfather: *"build the assistant skirnir as a system"*. Measured before the move: `bin/assistant/`
held 37 files and 3,220 shell lines — voice, knowledge, gate and rooms in one folder — with 17 of them
touching state, and **no figure in `.agents/agents/` owning it**. Twenty-three figures existed and the
assistant the Allfather talks to every day was owned by nobody, so "who may change this?" had no answer
in the folder itself (the same fault plan 129 named for Snotra).

## What moved

`bin/assistant/<door>` → `systems/skirnir/services/<door>`, whole, with `git mv` so the history follows.
A **retired shim** stands at every old path: it says the door moved, names the new one, and execs it —
so a caller nobody has repointed yet still works.

Added with the move: `systems/skirnir/domain.yaml` (folder · keeper · board · memory · doors ·
called_by · never), `systems/skirnir/README.md`, and the keeper's own file in `.agents/agents/`.

## What is deliberately unchanged

The **outbound gate** stays the only road out (`asks.sh` · `ask.sh` · `approve-fact.sh` · `escalate.sh`),
the **voice path** keeps its doors, the **knowledge base** stays his, and the **rooms** keep their walls
tests. Nothing about behaviour changes in this phase — only ownership, and the address a caller uses.

## Owed (plan 150)

- the keeper's board (`skirnir/assistant`) and his well namespace `domain:skirnir` — a domain that
  cannot see its queue or remember its last run is not owned;
- retirement of the shims once every caller is repointed, by a dated note;
- the `thattr.yaml` declaration, last, when plan 149's shape lands.
