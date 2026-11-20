## gate · unversioned · 2026-10-13 — Rule 21: the home has a layout, and nothing is created outside it

### What

The Allfather: *"we clearly need to tighten the way Ymir is allowed to find and create documents
inside the Ymir home"*, and then: *"why do we have a work folder in life?"*

Rule 21 makes the home's layout **law**: one resolver finds every shelf, each shelf has one
purpose, **state lives in `$YMIR_HOME/state` and nowhere else**, a company document lives in a
company or project shelf, **discovery is by registry and never by walking the tree**, creation
outside a shelf is refused by script, template and ward — and **one name may not mean two
things**.

It records the faults measured the same day:

- **state outside the home** — `~/Documents/Ymir/state` (a case-variant directory holding
  `sessrumnir.pid`, `.log` and `version`), and state *inside the public repo* at
  `ymir/.agents/state` and `ymir/bin/state`;
- **a stray hoard** — `~/hodd/`, created by one line of instructions;
- **company and project material in the operator's own shelf** — `hodd/life/work/` holds seven
  **project** notes, and `hodd/life/marketing/` and `hodd/life/meetings/` hold company material;
- **two things named `work`** — the realm `svartalfaheim/work/` and the shelf `hodd/life/work/`.

### Verified

- Registered in `RULES/README.md` with a table row.
- The `hodd/life` description was **corrected while writing it**: the first draft said
  "*personal life only*", which the Allfather's question exposed as wrong — `hodd/life` is the
  **operator's own** (personal, meetings, marketing, his working notes), and it came from the
  migration that renamed `hodd/workspaces/` to `hodd/life/`. The rule now says so, and carries
  the collision that made the question necessary.

### Files

- `RULES/21-home-layout.md`
- `RULES/README.md`
