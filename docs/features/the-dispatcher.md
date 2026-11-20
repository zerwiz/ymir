# The dispatcher — the queues become one list

**What it is.** Two things fill up every day and neither arrives in an order a person can read: the
mail desk's *needs-you* column, and the wake queue where a worker leaves the decision that stopped it.
The dispatcher reads both, keeps only what is genuinely yours — not the arm's, not a notice — and
writes one proposal line for each into your own to-do, inside a marked block, so the list you already
look at is the list of what is waiting.

A proposal is a line, never an act. Nothing is sent, nothing is started, nothing is closed. Every line
ends with its key, and each names what it unblocks.

**What you need.** Nothing to set up. The dispatcher reads the home it runs from: the mail desk's store
(if that seat has mail) and `state/.wake-queue`. It writes its ledger to `state/dispatch/`.

**The commands**

```sh
bin/dispatch/dispatch.sh --dry-run    # what it would propose right now, writing nothing
bin/dispatch/dispatch.sh              # one run: read, propose, record
bin/dispatch/dispatch.sh --check      # is every input readable and the record intact?
bin/dispatch/dispatch.sh --json       # the same answer for a program
```

The timer runs it every ten minutes. To read what it decided, look at the last row of
`state/dispatch/runs.jsonl`: it names the verdict — `work` or `no-op` — the counts, and the reason.

**What you will see in your to-do.** A block between two markers, at the end of the house-kept half:

```markdown
- [ ] 2026-11-16 · proposal · Answer a correspondent — Spec v2.5 — mail:needs_you · unblocks: the reply he owes · dispatch-e6c80ebd
```

Approve by doing the thing and ticking the line; the house never ticks it for you and never edits your
own half of the file.

**Limits worth knowing.** It proposes at most five lines per run, so a backlog never floods your day.
It reads only the last 48 hours, so a resolved question is never dredged back up. It never proposes a
lock-ask — those belong to whoever holds the arm — and it never proposes the same letter twice, even if
its ledger is deleted, because your to-do itself remembers the key.

**If it does not work.** `bin/dispatch/dispatch.sh --check` names the surface that is unhappy. A run
that exits 3 could not read an input and says which file — it will not pretend an unreadable queue is
an empty one. A run that exits 4 says the to-do or the ledger cannot be read. If the timer is missing
from a machine, the register still has it: `bin/engine/units.sh list --names` shows it, and
`bin/engine/units.sh write dispatch` seats it.

## CHANGE LOG

- 2026-11-18 — gathered into the one delivery batch; unchanged since it was written.
