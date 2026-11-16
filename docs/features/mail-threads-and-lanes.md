# The lanes — did we answer this, and what is this thread waiting on?

Your mail is recorded in one file, both directions, with every message knowing its
conversation. What that file could not tell you is the two things you actually ask:
**did we answer this?** and **what is this thread waiting on?** This door joins the two
directions and puts one of four words on every conversation.

## What it gives you

One row per conversation, and nothing else:

- the conversation's key,
- which way the last message went — `in` or `out`,
- when it went,
- whether one of ours went out *after* their last one (`yes` / `no`),
- how many whole days an answer has been owed, and
- the lane.

The four lanes, and what each one means for you:

| Lane | What it means | What happens |
|---|---|---|
| **needs-you** | They wrote last and it wants an answer — not a notice, not a machine. | This is the only lane that is allowed to speak: it belongs on your list and in the brief. |
| **answered** | We wrote last, and recently. | Nothing. The silence is the reward — it is never listed at you. |
| **waiting-on-them** | We wrote last and it has been quiet for three days or more. | Where a nudge comes from, once. |
| **closed** | You marked it, or it owes nobody anything (a notice, an invoice, a calendar machine, a bulk sender), or we answered, they replied, and we answered again. | It leaves you alone. |

## What you need

Only the mail store the desk already keeps. No key, no network, no daemon: this door
reads the store and writes nothing at all.

## The commands

```sh
bash bin/mail/threads.sh                  # every conversation, one row each
bash bin/mail/threads.sh --lane needs-you  # the only lane that is owed an answer
bash bin/mail/threads.sh --json           # one JSON object on one line, for a program
```

`--lane` takes the plan's own words too (`needs you`, `waiting on them`), because a
name a person remembers should not have to be spelled the machine's way.

Two flags exist for proofs rather than for you: `--store PATH` reads another store, and
`--now ISO` judges the ages against a fixed instant. One is for you:
`--nudge-days N` moves the line between **answered** and **waiting-on-them** (three days
by default).

The rows come out worst-first: `needs-you`, then `waiting-on-them`, then `answered`, then
`closed`, and oldest first inside each — so the longest-owed conversation is the first
thing you read.

## Limits, said plainly

- **Read state is a snapshot.** `UNREAD` comes from Gmail at import time, so a mail you
  read at nine can still say unread at noon until the next sync lands (plan 305 phase 2).
- **Nothing is ever marked answered by this door.** `handled_at` is written by the door
  that acts on a message — a sent reply, your tick, the judge's "needs nothing" — never by
  a reader (phase 3). That is why `closed` today holds only the threads that owe nothing.
- **The thread key is derived**, not Gmail's own thread id, because the store predates
  that field (plan 305 §7.2, phase 7). A reply can therefore be joined to the wrong
  conversation in principle; the store's own `thread` verdicts cover six rows today.
- **Notices are counted, not listed.** Sixty-nine of the 226 messages are notices; they
  land in `closed` and the footer tells you how many were closed without a reply. Whether
  a notice should count at all is still your call (plan 305 §5.3).

## If it does not work

`no mail store at that path` means there is nothing to read there — the door will not
guess, and it will not answer "no threads" when the truth is "no store", because the two
look identical on a terminal. Point it at the store with `--store`, or set `YMIR_HOME`.

`warning: N unreadable row(s) in the store, first at line L` means the store itself has a
broken line. The rows that do parse are still answered; the count rides in the JSON as
`totals.unreadable_rows`. A broken row is a finding, never a silent skip.

## CHANGE LOG

- **2026-11-16** — Opened: the door that answers "did we answer this", and the four lanes.
