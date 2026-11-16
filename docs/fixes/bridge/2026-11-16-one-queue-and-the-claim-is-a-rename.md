---
component: bridge
date: 2026-11-16
plan: 303
step: 3
---

# One queue, and the claim is a rename

Plan 303 §5 and §12.3 step 3.

## Why

The house had **four** mailboxes in four formats — Sága's wake queue, the hall's `todo`,
the a2abridge inbox, and Ratatoskr's tasks — so no agent knew where to look. A message
that landed in the wrong one was a message nobody read, and an agent that saw a task in
its own inbox had no way to say it had taken it, so two receivers could both work it.

There is one format now, and it is the hall's own: **one Markdown file per task**, three
shelves, and **the claim is a rename**.

## What changed

`bin/bridge/ratatoskr.sh send|inbox|claim|reply|show|count` over
`bin/bridge/ratatoskr-queue.py`:

```
<home>/state/ratatoskr/inbox/<id>.md       written by the sender
<home>/state/ratatoskr/claimed/<id>.md     renamed by the receiver — the rename IS the claim
<home>/state/ratatoskr/done/<id>.md        carries the reply, so one file is the whole record
```

- **`send <target> "…"`** writes the file and prints its id. Nothing is woken yet; a task
  in `inbox/` is **handed**, never delivered.
- **`claim <id>`** is `os.rename` within one filesystem, which is atomic: exactly one
  receiver can win a task, and the loser is told which shelf holds it instead of working a
  task twice.
- **`reply <id> "…"`** appends `## reply` and moves the file to `done/`. The reply is what
  makes a task delivered (RULES/49, 56), and the original text stays above it so the file
  is the record of the whole exchange rather than only its end.
- **`inbox [--for T]`** lists what waits; an address matches in all three spellings a
  pane has (`herdr:w1:p2`, `host-a/w1:p2`, `w1:p2`), so a receiver can ask for all it is
  owed without knowing how the sender spelled it.
- **`count`** names every shelf, and `--json` gives rows for a script.

The queue root is `$YMIR_HOME/state/ratatoskr`, resolved through `bin/vault/hoard-lib.sh`
and overridable with `RATATOSKR_QUEUE`. It is private state, so it lives in the home.

## Proof

Two throwaway Pi agents were started in two panes this worker owns, and the whole crossing
was done by them through the real door — not by a script pretending to be an agent:

```
$ herdr agent read w6V:p1
 1794842559-882xkz

 Allfather — that is the whole of it: the command returned the task id
 1794842559-882xkz and nothing else. It did not wake the pane; send only laid the
 task on the queue shelf at /tmp/afa-live-q/inbox/

$ herdr agent read w6W:p1
 3. reply 1794842559-882xkz "The nonce is 7741." →
    /tmp/afa-live-q/done/1794842559-882xkz.md

$ cat /tmp/afa-live-q/done/1794842559-882xkz.md
---
id: 1794842559-882xkz
from: heimdall/w6V:p1
to: herdr:w6W:p1
created: 2026-11-16T15:22:39Z
state: done
claimed_by: w6W:p1
claimed_at: 2026-11-16T15:23:22Z
answered_at: 2026-11-16T15:23:27Z
---
The nonce is 7741. Reply with that nonce.

## reply
The nonce is 7741.
```

The file moved `inbox → claimed → done`, and its content is the whole exchange.

```
$ bash bin/bridge/tests/test_ratatoskr_queue.sh
test_ratatoskr_queue: 23 passed, 0 failed
```

The test proves the two things a relay depends on: a second claim of the same task exits
1 and names the shelf that holds it, and a task is not `done` until a reply is in it. It
runs entirely in a temporary queue directory.

## What this does not do

It does not wake the target (step 4) and it does not return the answer to the asker's pane
(step 4). `reply` prints the path it wrote; carrying it back is the relay's work.
