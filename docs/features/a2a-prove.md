# The proof — one nonce through every door, and back

## What it is

`bin/bridge/a2a-talk.sh prove` is the house's own proof that agents can find and answer each
other. It sends a **nonce** through the three doors of the loop — the queue, the relay, the arm
— and, with `--live`, through two real agents and back, unchanged.

It exists because a card that answers is not a node that answers. A claim of "the channel
works" has to survive a nonce.

## What you need

- The queue, the relay and the arm door (they ship with Ymir).
- For `--live`: two agents standing in panes, and the relay running.

## Do it

The plumbing proof — every door, no agent needed, seconds:

```bash
bin/bridge/a2a-talk.sh prove
```

It prints the nonce it used and one row per door:

```
proof[3]{door,ok,evidence}:
  "queue","proved","task 1794… moved inbox → claimed → done, nonce intact"
  "relay","proved","the relay answers status with its counts"
  "arm","proved","a machine the registry does not know is refused by name"
```

Your own nonce, when you want to be sure it is yours:

```bash
bin/bridge/a2a-talk.sh prove --nonce deadbeef
```

The full round trip through two live agents:

```bash
bin/bridge/a2a-talk.sh prove --live w1:p2 w1:p3 --nonce cafebabe --wait 300
```

Every hop is waited for. A hop that does not arrive is printed as

```
  "live","FAILED","UNPROVED — the round trip through w1:p2 and w1:p3 did not arrive in 300s; the task is still on 1794…"
```

## Limits

- The plumbing proof is deterministic and needs no agent; the `--live` round trip needs two
  agents that will act on a wake, and takes as long as their turns take.
- Exit 1 means a door did not answer **and is named**. There is no partial green: a proof that
  hid a failed door would be the thing this door exists to prevent.
- It uses the real queue (or `RATATOSKR_QUEUE`), so a proof leaves its tasks in `done/` as
  evidence. That is deliberate: the record of a proof is the task it proved.

## If it does not work

- `not proved: queue` — the queue is not writable. Check `RATATOSKR_QUEUE` and the home.
- `not proved: relay` — the relay cannot answer `status`. Run
  `bin/bridge/ratatoskr-relay.sh status` yourself; it says why.
- `UNPROVED` on `--live` — an agent did not act. Read its pane; the wake is in its scrollback,
  and the task id it names is still on the shelf.

## CHANGE LOG

- **2026-11-16** — written with the change it describes (plan 303 §12.3 step 7).
