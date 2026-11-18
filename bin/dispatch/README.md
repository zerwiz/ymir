# The dispatcher — incoming work becomes a bounded errand or a line on his list

**Ask the door, do not remember the rules:** `bin/dispatch/dispatch.sh --help` prints the whole brief
below, and `bin/dispatch/dispatch.sh --check` answers whether this seat's dispatcher is healthy.

## What it is

Two queues fill every day and nobody reads them in order: the mail desk's **needs-you** column and the
**durable wake queue**, where a worker leaves the decision that stopped it. The dispatcher reads both,
decides which of them is *his* — not the arm's, not a notice — and writes one proposal line for each,
inside his to-do, where he already looks.

A proposal is a **line, never an act**. Nothing is sent, nothing is spawned, nothing is closed. The
line carries its own key so the same letter or the same question can never be proposed twice, and each
line names what it unblocks, because a list without consequence is a wish list.

## What it reads

```
source          the rows                                   what it keeps
mail            Gná's desk queue, needs_you and unsure     every row, per declared account
wake queue      <home>/state/.wake-queue                   only a `needs-decision`, only inside the
                                                           window, one per distinct question
```

The mail rows arrive by two roads: the desk over loopback, or — when the desk does not answer — the
store the desk reads, through Gná's own classifier. The run names the road that answered.

A **`lock-ask` is never proposed.** It is addressed to whoever holds the arm, and the arm drains it;
putting it on his list would duplicate a queue that already has an owner. Measured on the Allfather's
seat on 2026-11-16: the wake queue held 106 lock-asks in two days, and not one became a line.

## What it writes

Only two paths, and nothing else:

```
hodd/life/personal/me/todo.md            a proposal block between two markers, inside the
                                         house-kept half. His own half is never touched.
hodd/state/dispatch/runs.jsonl           append-only: one row per proposal, refusal or failure,
                                         and one row per run saying `work` or `no-op` and why.
```

The block looks like this:

```markdown
<!-- dispatch:inbox — proposals only (bin/dispatch, kept by the house). … -->
- [ ] 2026-11-16 · proposal · Answer a correspondent — Spec v2.5 and the prototype copy — mail:needs_you · reply_needed · unblocks: the reply he owes · their last word 2026-11-16T09:00:00+00:00 · dispatch-e6c80ebd
<!-- /dispatch:inbox -->
```

## The commands

```sh
bin/dispatch/dispatch.sh                  # the scheduled act: read, propose, record
bin/dispatch/dispatch.sh --dry-run        # read and report, write NOTHING
bin/dispatch/dispatch.sh --check          # health only: inputs readable, record intact, markers whole
bin/dispatch/dispatch.sh --json           # machine-readable answer instead of TOON
bin/dispatch/dispatch.sh --max 2 --hours 24   # this run's cap, and the window

bin/time/nornir-job-dispatch.sh           # what the timer runs (the same door, one record, one rune)
python3 bin/dispatch/tests/test_dispatch.py   # the 51 proofs
```

Exit codes, so a caller can tell the three states apart: `0` ran · `2` usage · `3` an input is
unreadable · `4` the record cannot be read or written.

## The three laws

**1 — Idempotent by key.** The key is `sha256(source|id)`: `mail:<account>` with the message id, or
`wake` with the question's identity (its words with the clock and the numbers folded, so a worker
asking the same thing twice is one item). A key already on his list, or already in the ledger, is a
no-op — and the to-do alone is enough to refuse a second proposal, so deleting the ledger cannot
resurrect a duplicate.

**2 — The attempt cap is three.** A key that failed three times is **terminal**: the fourth attempt is
refused, recorded once, and every run after that is a no-op naming the terminal state. It never
quietly retries for ever, and it never proposes a key that burned its attempts.

**3 — An unreadable input is an error, never an empty list.** A store that cannot be read, an
`accounts.yaml` that parses to nothing, a wake queue that cannot be opened: the run records `failed`,
says which file, and exits `3`. `0 items` is a claim about a file, and this door refuses to make it
about a file it did not read. A seat with no `accounts.yaml` is the one clean skip — mail is not
configured there — and the run says so by name.

## Where it runs

`config/units.yaml` registers the timer (`name: dispatch`, every 10 minutes), and
`bin/engine/units.sh` is the one writer that renders it. There is no hand-written unit file: a timer
typed by hand is a unit no register knows about.

The timer row is seated by install and by update like every other row. To render it on a machine that
already has the pin:

```sh
bin/engine/units.sh list --names          # the register, including dispatch
bin/engine/units.sh check                 # is every installed unit on the pin and in the register?
```

## Limits, plainly

- It proposes **at most `DISPATCH_MAX`** (default 5) lines per run; the rest are deferred with the
  reason `cap` and come back on the next run, so a backlog never floods his list in one pass.
- It reads the **last `DISPATCH_WAKE_TAIL`** (default 200) lines of the wake queue and only what is
  inside `DISPATCH_HOURS` (default 48). An older decision is archaeology, not incoming work.
- It does **not spawn errands**. A proposal names its shape — `errand` when the house can carry it,
  `line` when the judgement is his — and the arm spends it. Spawning needs the arm, not a timer.
- It never touches his half of the to-do, never sends mail, never takes the arm, never rewrites the
  ledger.

## If it does not work

| What you see | What it means |
|---|---|
| `3` and `"input"` | a queue or the mail store could not be read — the message names the file |
| `4` and `"state"` | the to-do or `runs.jsonl` is unreadable, or the markers are half-present |
| `verdict: no-op` every run | nothing new: every row is already on his list, deferred by the cap, or terminal |
| no block in the to-do | nothing is owed yet — the first proposal opens the block |
| `bin/engine/units.sh check` complains | the timer is in the register but not on this machine's pin yet: run the install, or `units.sh write dispatch` |

The record is `hodd/state/dispatch/runs.jsonl` — one line per event, one line per run. Read the last
run row first: it says the verdict, the counts and every reason, including `no-candidates`.

## CHANGE LOG

- 2026-11-18 — gathered into the one delivery batch; unchanged since it was written.
