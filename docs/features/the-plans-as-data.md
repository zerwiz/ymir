# The plans, as data — what is still open, and what proves it is done

**What it is.** The house writes every piece of work down as a plan: one file per plan, on a shelf,
in a numbered ledger. Until now nothing *read* them — the plans were prose for a person, so "what is
still open?" was answered from memory, and the answer went stale the same day it was typed. This door
reads every plan shelf the home's project registry names, decides per plan whether it is done, and
says **what proves it**.

**Who it is for.** You, first: so your own list stops being a hand-typed copy that rots. Then every
other surface — the morning brief, a desk in the hall, a Telegram nudge — is meant to render this one
read rather than invent a second record.

## The rule it is built on

**A state it cannot measure is `open`, never `done`.** Silence is not finished work. The same rule the
merge gate uses: a thing is not shipped because nobody said otherwise.

The reverse is also true: **done needs one witness**, and the witness is carried with the answer.
There are four of them.

| A plan is done when… | What the door says |
|---|---|
| its header declares it | `state: done` — or the older `Status: done` |
| the register says so | `register.md says done` |
| the shelf files it there | `the shelf files it under done/` |
| the PR it names merged | `PR #77 merged (GitHub)` — only with `--with-prs` |

A plan declaring nothing is listed as open, with the line `no state measured — open, because silence
is not finished work`. That is the honest answer, and it is the one thing that turns a plan into work
you can see.

## What you need

- The home at `$YMIR_HOME` (resolved from the environment, then `~/.config/ymir/home`).
- `hodd/identity/projects.yaml`, the project registry, with each project's plan shelf named under
  `records.in_home.plans` or `records.in_repo.plans_ledger`.
- PyYAML, and `gh` only if you ask for `--with-prs`.

## The commands

```bash
bin/records/plans-state.sh              # write hodd/registry/plans-state.yaml — the plans as data
bin/records/plans-state.sh --check      # a named shelf that is not there, or a number used twice
bin/records/plans-state.sh --self-test  # prove done-vs-open on a throwaway home
bin/day/day.sh plans                    # the open plans, per project, newest first
bin/day/day.sh plans --all              # every open plan, not just the newest per project
bin/day/day.sh plans --done 7d          # what closed in the last week — what to tick off
bin/day/day.sh plans --blocked          # what waits on your word, with the question it asks
bin/day/day.sh plans --json             # the same data for a surface in the house
bin/day/day.sh plans --carry            # counts and numbers only, never a title
```

## What it reads, and what it refuses to count

A shelf holds more than plans, and a door that counted everything would bury your real work in noise.
Three kinds of file are **not open work**, and the door says how many it left out instead of hiding
them.

| Not listed as work | Why |
|---|---|
| `old-plans/`, `archive/`, `retired/` | a retired plan is reference, not work you owe |
| `2026-11-15-report.md`, `20261105T0010Z-…` | a dated name is a report of what happened, not a plan |
| `_templates/`, `bug-0000-short-description.md` | a shape to copy is nobody's open task |

And a shelf the registry names that is **not there** is printed as `ABSENT` with its path. An empty
shelf and a missing shelf are different facts, and a zero for the second would be a lie.

## The generated registry

`hodd/registry/plans-state.yaml` is **written by the door, never by a person**, and the shelf is
git-ignored beside it: a generated file that can conflict is a file that will. Read it, or ask the
door — the registry and the plan files are the truth.

## Limits, honestly

- **`--check` reports colliding plan numbers, and there are real ones.** Plans 93, 94, 199, 200, 201,
  202, 204, 206, 210, 212, 219, 232, 255, 275, 286, 72 and 86 are each used by two files today. The
  door names them; it never renumbers anything (plan 298 §6 asks you whether it may).
- **`--with-prs` is the only network call**, and only when you ask for it.
- **A closure date is the file's last change**, not the day the work shipped, when the witness is a
  header or a register row. `--done 7d` therefore means "closed and last touched within a week".
- **The `plan-0001` / `bug-0012` ticket form is read too**, because another project's shelf numbers
  that way. The kind is part of the number, so `plan-0001` and `bug-0001` never collide.

## If it does not work

- `unable — YMIR_HOME is unresolved` — run the door through its wrapper, which asks the resolver.
- `unable — no project registry at hodd/identity/projects.yaml` — the registry is what names the
  shelves; without it the door refuses rather than guess a path.
- `ABSENT <project>` — the registry names a shelf this machine does not have, usually a repository
  that is not cloned here. The line names the path it looked for.
- `the plans door did not answer (…)` from `bin/day/day.sh plans` — the engine raised; run
  `bin/records/plans-state.sh --self-test` and it will say which case broke.

## CHANGE LOG

- **2026-11-15** — written with plan 298 phases 1–2: the door, the generated registry, the four
  witnesses (header · register · `done/` folder · merged PR), the `plans` read, and the rule that a
  state nothing measures is open.
