# `.pi/extensions/` — this tree is empty on purpose

**The extensions are not here.** They live in **`.pi/shared/extensions/`** and are
deployed by copy to **`~/.pi/agent/extensions/`** by `bin/valknut-load.sh --pi`.

This directory previously held **nine no-op factories** whose only job was to stop a
duplicate tool registration. **`bin/valknut-load.sh --check` now does that job
mechanically**, so they are gone.

---

## Why this directory must stay empty

**Pi loads two extension directories and does not de-duplicate them:**

- `~/.pi/agent/extensions/` — the deployed home
- `.pi/extensions/` — this directory, project-local

An extension present in **both** registers its tools twice, and pi exits with

```
Tool "<name>" conflicts with …
```

**and no agent can be seated.** The only symptom herdr can report is that the pane
will not sit at an interactive shell prompt — which is nowhere near the cause.

---

## The law: `RULES/13-pi-extensions.md`

| | |
|---|---|
| **one home per extension** | the source is `.pi/shared/extensions/`; the deployed copy is `~/.pi/agent/extensions/`. Never the same extension in both. |
| **a multi-file extension is a directory with an `index.ts`** | pi loads a direct `.ts`/`.js`, or a subdirectory **only when it holds `index.ts`**, and it does **not** recurse deeper. |
| **no thin loaders** | a file here that imports a shared factory and calls it with `pi` registers the same tools a second time. You cannot both deploy a copy and load the source. |
| **the gate** | `bin/valknut-load.sh --check` — fails when the deployed tree differs from source, when a test file is in the live tree, or when anything here registers a tool. |
| **the smoke test** | `.agents/tests/pi-extensions.test.sh` |

---

## What the extension set looks like

```
.pi/shared/extensions/
├── ro/index.ts                       ← Ró — calm presentation (+ Vörðr helper)
├── constellation/index.ts             ← the mesh
├── skuld-branch-supervision/index.ts  ← Skuld — the supervision branch
├── syn-turnend-guard.ts               ← Sýn — digest, compaction, turn-end guard
├── gna-pi-watch.ts                    ← Gná — watcher continuity
├── todo.ts · elder.ts · ymirhome.ts · ymir-well.ts · ymir-subagents.ts
├── opendesign.ts · odrerir.ts · herdr.ts · herdr-agent-state.ts · eindri.ts
├── managandr.ts · eir.ts · rules.ts · open-editor.ts
└── lib/                               ← shared modules ONLY, and no index.ts
    ├── ymir-home.ts                      the distro root, for a deployed copy
    ├── rodd-operational-input.ts         the Rödd wire
    ├── ro-visibility.ts                  read by ro, gna-pi-watch and skuld
    ├── skuld-branch-dispatch.ts          read by gna-pi-watch and skuld
    └── vordr-sessionstart-supervisor.mjs spawned by path, not imported
```

**A module with one importer has an owner** and belongs inside that extension's
folder, not in `lib/`. The smoke test says so on every run.
