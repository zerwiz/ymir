# The registers, one folder at a time

**What it is.** Ymir keeps two big generated registers: `bin/README.md` (every file in `bin/`, what it does, whether
anything uses it) and `.agents/assets/agents/capabilities.md` (what Ymir can do, and the door for each job). Both used
to be **one file**, rewritten whole every time anything anywhere in `bin/` changed. Every branch then rewrote the same
lines in the same order, so every pull request collided with every other one.

They are now a **tree**: each folder of `bin/` keeps its own index, and the two front doors are short pages of folders.

**What you need.** Nothing. Both are generated; you read them, you do not edit them.

## The layout

```
bin/
├── README.md                 the front door: one row per folder, with its count and its index
├── INDEX.md                  the root-level doors
├── agents/INDEX.md           that folder's doors, one row each
├── gates/INDEX.md            …
└── …/INDEX.md                one per folder

.agents/assets/agents/
├── capabilities.md           the front door: the law, the totals, one row per folder
└── capabilities/
    ├── agents.md             that folder's capability rows
    └── …                     one per folder
```

## Do it

```bash
bin/gates/inventory.sh        # write bin/README.md and every bin/<folder>/INDEX.md
bin/gates/capabilities.sh     # write capabilities.md and every capabilities/<folder>.md
bin/gates/guards.sh           # the wards: every fragment current, or the push is refused
```

Both generators write the **whole tree** in one run; a change in `bin/collab/` rewrites `bin/collab/INDEX.md` and
nothing else, which is the whole point.

## Why the collisions stop

A register is only useful if it is current, and it is only current if it is regenerated in every change. A single file
makes that self-defeating: two hands in two different folders regenerate the same file, and git has to reconcile two
whole rewrites of a 786-line document. Per folder, the two hands touch two files nobody else is touching.

## The merge driver

`.gitattributes` marks the front doors `merge=regenerate`, and `bin/records/regenerate-on-merge.sh` is the driver: on a
conflict it reweaves the document from the tree instead of asking a person to resolve lines by hand.

```bash
bin/gates/seat-woven-driver.sh --check   # is it seated, and where does it point?
bin/gates/seat-woven-driver.sh --prove   # seat it, then prove it on a scratch conflict
```

Measured 2026-11-06: the driver was declared and pointed at a worktree that no longer existed, so no reweave ever ran.
The install step `gates` now seats it, and Eir reports `woven-driver`.

## Limits

- A folder's purpose comes from `bin/gates/registers/folders.tsv` — one line each. A folder missing there renders
  `(no purpose recorded)`; the fix is a line in that file, never in generated text.
- A conflict **inside** one folder is a real meeting, not a collision: the fragments deliberately take an ordinary text
  merge.
- The front door's counts move only when a folder appears, disappears or is renamed.

## If it does not work

| What you see | What to do |
|---|---|
| `inventory --check: … is STALE` | `bin/gates/inventory.sh`, then commit what it wrote |
| `capabilities --check: … is STALE` | `bin/gates/capabilities.sh`, then commit what it wrote |
| A pull request conflicts on `bin/README.md` | the driver is not seated: `bin/gates/seat-woven-driver.sh --prove` |
| A folder shows `(no purpose recorded)` | add its line to `bin/gates/registers/folders.tsv` |

## CHANGE LOG

- **2026-11-06** — Written with the split (plan 211). `bin/README.md` went from 786 lines to a folder front door and
  34 per-folder indexes; `capabilities.md` from 732 lines to 137 plus 31 fragments; the merge driver was found pointing
  into a deleted worktree and is now seated by install.
