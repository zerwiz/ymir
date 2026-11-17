## fleet · 2026-11-17 — a tell carries a deadline

### What was wrong

A tell crossed to another machine, landed in the arm holder's queue, and then waited for ever. Nothing recorded that it had been asked, nothing recorded that it had not been answered, and an arm that never answered looked exactly like an arm that answered late.

### What the door does now

`bin/fleet/arm-send.sh` stamps every tell with the instant it expires, and the stamp travels **inside the line the holder reads** — not in a ledger on the sending side that the far machine never opens:

```
tell t1794918317-f06e, DEADLINE 2026-11-17 13:55 CET (unacked tells escalate to the Allfather: bin/fleet/arm-send.sh --ack t1794918317-f06e answers it)
```

Every tell is written to the door's own ledger, `<state>/arm-tells.tsv` (`id · sent · to · from · deadline · acked · text`), and the door can then answer three questions:

- `--pending` — what still stands inside its deadline;
- `--expired [--notify]` — what went past it unacked. The report **is** the escalation, and the door exits non-zero so a cron row can act on it; `--notify` also raises it on the desk the Allfather reads;
- `--ack <tell>` — the receiver marks it answered, and an acked tell never escalates.

A refused tell (nobody holds the arm on that machine) writes **no** deadline: nothing was handed over, so nothing is owed.

The window is one constant: `YMIR_TELL_DEADLINE`, default 1800 seconds.

### Files

- `bin/fleet/arm-send.sh`
- `bin/fleet/tests/test_arm_send.sh` (new)

## CHANGE LOG

- **2026-11-17** — Opened: a tell carries its deadline, the ledger remembers it, and an unacked tell escalates instead of waiting for ever.
