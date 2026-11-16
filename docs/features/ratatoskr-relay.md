# The relay — a task gets woken, and the answer comes back

## What it is

`bin/bridge/ratatoskr-relay.sh` is the loop that turns the queue into a conversation.

When a task sits in the inbox, the relay wakes the agent it is addressed to, checks that the
agent actually started working, and — when the answer is written — carries it back into the
**asker's** own pane under a header. No agent ever has to poll for work.

It never types into an agent that cannot take a turn: a pane standing on a dialog, an agent
mid-turn, a pane holding a bare shell — each is either left alone or recorded as a miss that
names why.

## What you need

- herdr running, with at least one agent in a pane.
- An arm holder on the machine: the relay refuses to serve a machine nobody supervises.
- `python3`.

## Do it

One pass, by hand:

```bash
bin/bridge/ratatoskr-relay.sh --once
```

The loop, which is what the user unit runs:

```bash
bin/bridge/ratatoskr-relay.sh run --interval 5
```

What it last did:

```bash
bin/bridge/ratatoskr-relay.sh status
```

That prints four counts — woken, returned, missed, and owed to another machine — and the
last few misses, with the task id, the pane and the reason.

Send a task and watch it happen:

```bash
bin/bridge/ratatoskr.sh send herdr:w1:p2 "summarise the open PRs"
```

The relay wakes `w1:p2`, the agent answers with
`bin/bridge/ratatoskr.sh answer <id> "…"`, and the reply arrives in your own pane as:

```
[ratatoskr · from w1:p2 · re 1794842559-882xkz] the answer
```

### What a miss looks like

```
miss: 1794842941-acl3vo w1:p2 blocked: trust prompt
miss: 1794842937-0uhh16 w1:p9 no agent in the pane (no agent in w1:p9)
miss: 1794842955-k2m4xq w1:p3 the agent did not move after the wake (state ready)
```

Each line names the task, the pane and the reason. A wake that changed nothing is never
reported as a delivery.

## Limits

- It wakes agents **on this machine**. A task addressed to another machine is left for that
  machine's relay; a cross-machine answer is recorded as `owed` and carried by the edge.
- It does not type into a pane whose agent is not `ready`. If a target is blocked, the miss
  is the record — clear the dialog and the next pass wakes it.
- Each wake is retried once. After that it is a miss, not an infinite loop.
- The unit waits for a live arm holder before serving. That is deliberate (no agent runs
  unowned); on a machine with no arm, the relay will sit waiting and say so in its log.

## If it does not work

- `relay: no live arm holder on this machine — waiting` — the journal says it plainly. Take
  the arm, or ask the holder to. Nothing is lost; the tasks stay on the shelf.
- A task stays in the inbox with `the agent did not move` — the target was woken twice and
  the pane never entered a turn. Read the pane; the wake text is in its scrollback.
- `the first line submitted, the rest swallowed` — that was a real fault of multi-line
  wakes. The wake is one line now; if you see it again, it is a regression.
- Nothing returns to the asker — check the task's `from` address. A bare machine name has
  no pane to return to, and the relay records it as `owed`.

## CHANGE LOG

- **2026-11-16** — written with the change it describes (plan 303 §12.3 step 4).
