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
- how many whole days an answer has been owed,
- what closed it, when a letter did not (`document:…`, `meeting:…`, `filing:…`,
  `answered-elsewhere:…`), and
- the lane.

The four lanes, and what each one means for you:

| Lane | What it means | What happens |
|---|---|---|
| **needs-you** | They wrote last and it wants an answer — not a notice, not a machine. | This is the only lane that is allowed to speak: it belongs on your list and in the brief. |
| **answered** | We wrote last, and recently. | Nothing. The silence is the reward — it is never listed at you. |
| **waiting-on-them** | We wrote last and it has been quiet for three days or more. | Where a nudge comes from, once. |
| **closed** | You marked it, or it owes nobody anything (a notice, an invoice, a calendar machine, a bulk sender), or evidence closed it, or we answered, they replied, and we answered again. | It leaves you alone. |

## When nobody wrote back: four kinds of evidence, and a fifth

Most finished work does not finish with a letter. The NDA was signed on 16 October and the
mail still read *open*, because the lane only knew how to see a reply. That is how a
finished job is counted as debt forever.

So a conversation also closes on evidence, read from the home's own file at
`hodd/memory/mail/evidence.yaml`. Each row names what closed it, so you can open the thing
and check it with your own eyes:

| Kind | What it is | What the row names |
|---|---|---|
| **document** | a signed or delivered artefact | the path in your home |
| **meeting** | a meeting that happened | the recap or the note |
| **filing** | a notice that needed nothing but reading | the register row, or the reason |
| **reply** | a letter answering the same thread | nothing — it is read from the mail itself |

The fifth is quieter, and it is **always marked**: `answered-elsewhere`. We wrote to that
same person within fourteen days but about something else, so the subject is still open in
substance. The row closes, it says exactly that, and it is **never counted as a reply**.

A row is only accepted when it is specific. It must name the evidence and it must narrow to
a subject, a thread or a message. **A row matching a sender's domain is refused** — that is
the mistake that put an unsigned development agreement behind a signed NDA — and every
refusal is printed, because a refused row and an absent row must never look the same.

## What you need

Only the mail store the desk already keeps, and — when you want closures that are not
letters — the evidence file at `hodd/memory/mail/evidence.yaml`. No key, no network, no
daemon: this door reads and writes nothing at all.

## The commands

```sh
bash bin/mail/threads.sh                  # every conversation, one row each
bash bin/mail/threads.sh --lane needs-you  # the only lane that is owed an answer
bash bin/mail/threads.sh --json           # one JSON object on one line, for a program
```

`--lane` takes the plan's own words too (`needs you`, `waiting on them`), because a
name a person remembers should not have to be spelled the machine's way.

Three flags exist for proofs rather than for you: `--store PATH` reads another store,
`--now ISO` judges the ages against a fixed instant, and `--evidence FILE` reads another
evidence file. Two are for you: `--nudge-days N` moves the line between **answered** and
**waiting-on-them** (three days by default), and `--window DAYS` says how long a letter to
the same person about something else still counts as a closure (fourteen days by default).

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
- **The count is only as honest as the evidence file.** A closure is only ever as good as
  the row that claims it: a path that has moved, a meeting that is named but cannot be
  found. The door checks the row's SHAPE — specific, cited, of a known kind — and it
  cannot check that the paper is still on the shelf. Open it once.
- **A row that names only a sender closes nothing.** If a conversation stays open although
  you know it is finished, the file needs a row about *that* subject; the door will not
  guess from an address.

## If it does not work

`no mail store at that path` means there is nothing to read there — the door will not
guess, and it will not answer "no threads" when the truth is "no store", because the two
look identical on a terminal. Point it at the store with `--store`, or set `YMIR_HOME`.

`warning: N unreadable row(s) in the store, first at line L` means the store itself has a
broken line. The rows that do parse are still answered; the count rides in the JSON as
`totals.unreadable_rows`. A broken row is a finding, never a silent skip.

`warning: evidence row '<id>' not applied — …` means the evidence file carried a row the
door refused, and the reason is on the same line: a domain instead of a subject, a sender
with nothing else, a kind that is computed, or no citation at all. The footer says
`evidence: N row(s) applied … M refused`, and `--json` lists every refusal under
`evidence.refused`.

`no evidence file at that path` means you named a file with `--evidence` and it is not
there — a typo must not read as "no evidence". With no flag, the home's own file is used
when it exists and the footer says `evidence: none` when it does not.

## CHANGE LOG

- **2026-11-16** — Opened: the door that answers "did we answer this", and the four lanes.
- **2026-11-17** — The four kinds of evidence and the marked fifth: a conversation also
  closes by a document, a meeting or a filing, and `answered-elsewhere` inside
  `--window DAYS` is marked and never counted as a reply. `--evidence FILE` added.
