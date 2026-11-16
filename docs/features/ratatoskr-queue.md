# The queue — one shelf for every task in the house

## What it is

Every message one agent sends another goes through **one queue**: a task is a Markdown
file, and it moves along three shelves.

```
state/ratatoskr/inbox/     written by the sender
state/ratatoskr/claimed/   taken by the receiver — the claim is a rename
state/ratatoskr/done/      answered, with the reply in the same file
```

The claim is a **rename**, which is atomic, so exactly one receiver can take a task. The
reply is written into the same file that carried the question, so one file is the whole
account of the exchange.

Before this, four mailboxes in four formats meant a message could land somewhere nobody
looked. There is one format now.

## What you need

- `python3`.
- A home (`$YMIR_HOME`). The queue lives under its `state/`.

## Do it

Send a task:

```bash
bin/bridge/ratatoskr.sh send herdr:w1:p2 "the nonce is 7741 — reply with it"
```

It prints the task id. Until the receiver answers, the task is **handed**, not delivered.

See what is waiting for you:

```bash
bin/bridge/ratatoskr.sh inbox --for w1:p2
```

A target matches however it was written: `herdr:w1:p2`, `another-machine/w1:p2` and a bare
`w1:p2` all name one pane.

Take a task:

```bash
bin/bridge/ratatoskr.sh claim 1794842559-882xkz --by w1:p2
```

The file moves to `claimed/`. If somebody else got there first, the command exits 1 and
tells you which shelf the task is on — it never lets two receivers work the same task.

Answer it:

```bash
bin/bridge/ratatoskr.sh reply 1794842559-882xkz "the nonce is 7741"
```

The file moves to `done/` with your reply inside it. **A task is delivered only when it is
answered** — a file on a shelf is not a delivery.

Read one task whole:

```bash
bin/bridge/ratatoskr.sh show 1794842559-882xkz
```

Or count the shelves:

```bash
bin/bridge/ratatoskr.sh count
```

`--json` on `inbox` gives the same rows as objects, for a script.

## Limits

- The queue is this machine's. A task addressed to another machine's pane needs that
  machine's relay to pick it up; the queue itself does not move files across machines.
- It does not wake anybody. `send` lays the task down; the relay (a separate door) does
  the waking and the returning.
- Ids are time-stamped and random; a prefix is enough to name a task, and two sends never
  share one.
- An empty task and an empty reply are refused. Neither is a message.

## If it does not work

- `the home is unresolved` — set `YMIR_HOME`, or point `RATATOSKR_QUEUE` at a directory.
- `already on claimed` — somebody has the task. Read it with `show`; do not re-claim it.
- `no task … on any shelf` — the id is wrong, or that task was cleaned away. `inbox` lists
  what exists.

## CHANGE LOG

- **2026-11-16** — written with the change it describes (plan 303 §12.3 step 3).
