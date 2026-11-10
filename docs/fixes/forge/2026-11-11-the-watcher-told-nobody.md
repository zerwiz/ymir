# forge · 2026-11-11 · The watcher told nobody

## What

We had a watcher: `review-watch`, every ten minutes. It raised an **ask** into the arm's queue — and an ask is
not a notification. It waits for a drain, the drain happens when the arm wakes for some other reason, and so a
pull request could sit for eight hours while every machine believed it had been announced.

The Allfather, at one in the morning: *"WHY DONT WE GET TO KNOW FROM THE GITHUB THAT PRS ARE THERE?? DONT WE
HAVE ANY FUNCING WATCHERS?"* He was right on both counts: the watcher existed, and it had never told him anything.

## Why

Two faults, one shape — the same one this house keeps paying for:

1. **The message went to a queue, not to a person.** An ask is a question for a lock holder; a new PR is news
   for the operator. Different audiences, different roads.
2. **Nothing ran the door on a clock he could trust.** A timer existed for the ask, but the ask only reached
   the arm, and the arm reads its queue when it wakes.

## The fix

`bin/forge/pr-watch.sh` — a watcher that speaks on the channel he reads:

- a **new PR** → one line: number · author · title · CI state · age;
- a PR **still open past an hour** → one line per hour, not per minute;
- a PR that **left the queue** → one line, then forgotten;
- **nothing changed** → silence, because a chatty watcher is ignored and that is worse than none.

State lives in `$YMIR_HOME/state/pr-watch.json`, so a restart does not re-announce the world.
`--install-timer` seats a user timer every 5 minutes — a watcher nobody starts is a watcher that never speaks.

## Proof

```
$ bin/forge/pr-watch.sh --status --dry-run
pr-watch[1]{repo,open,would_say}:
  "zerwiz/ymir","1","1"
new PR #640 by zerwiz: the well door for every harness, the Eindri ward, and a helm that admits only it — CI dirty, open 1h
```

Then `--install-timer` and one real run: the line arrived in Telegram.

## Change log

- **2026-11-11** — written with the door, after a night of PRs that nobody was told about.
