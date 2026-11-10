# Plans for every owner — a project, a machine, a company, or you

*A plan belongs to whoever owns the work.*

## What it is

The plan ledger used to hold one kind of plan: a **project**'s. Now there are four shelves, and each numbers its own
plans from 001:

| Scope | Where it lives | Who files there |
|---|---|---|
| **project** (default) | `svartalfaheim/<realm>/projects/<project>/plans/` | a codebase or product |
| **realm** (a company) | `svartalfaheim/<realm>/plans/` | the house itself: strategy, money |
| **machine** | `hodd/machines/<host>/plans/` | a computer: its hardware, rail, repairs |
| **personal** | `hodd/plans/` | your own work and schedules |

## What you need

Nothing to install — the shelves arrive with the software. `bin/engine/ymir-install.sh` creates them on a fresh home,
and `bin/agents/groa-update.sh` adds them to an existing one through `bin/engine/ymir-migrate.sh apply`.

## The commands

```bash
# a machine's plan
bash bin/records/plan.sh new thermal-repair --title "Power, thermals and the fans" --scope machine --owner heimdall

# a company's plan
bash bin/records/plan.sh new pricing --title "Pricing for 2027" --scope realm --owner synteon

# your own
bash bin/records/plan.sh new moving-house --title "Moving in December" --scope personal

# a project's plan — exactly as before
bash bin/records/plan.sh new model-lanes --title "Model lanes" --project ymir

# read them
bash bin/records/plan.sh list --scope machine
bash bin/records/plan.sh list --all           # every shelf, labelled
bash bin/records/plan.sh next --scope machine # the number the next one would take
```

In a chat with the agent, the same thing: `ymir_plan` takes `scope` and `owner`.

## Limits

- **Numbering is per shelf.** Machine `001` and project `001` are different plans; a number is never reused *within*
  a shelf.
- **A project shelf is never created for you.** An unknown project name is a typo, and the tool refuses rather than
  filing work in a directory nobody reads. Machine, realm and personal shelves *are* created on first use.
- **The ledger must be fresh.** Every `new` still refuses to take a number when the home is behind origin — that is
  how two plans once shared the number 182.
- **Plans are never moved automatically.** A plan filed on the wrong shelf is moved by a hand, with a note.

## If it does not work

- `plan: no ledger for <realm>/<project>` — the project shelf does not exist; either the project name is wrong or the
  project has never been filed. Check the name; the tool will not create it.
- `plan: REFUSED — the ledger is N commit(s) behind origin` — pull the home (`git -C "$YMIR_HOME" pull --ff-only`)
  and ask again.
- `plan: unknown scope …` — the four scopes are `project`, `realm`, `machine`, `personal`.

*Feature page written 2026-11-10 with plan 240; the law behind it is `.agents/skills/elder-home/assets/ledger.md`.*
