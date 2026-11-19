# The session start drains what was owed

**Date:** 2026-11-19 · **Component:** time · **Doors:** `bin/time/saga-wake-drain.sh start`,
`bin/time/saga-session-start.sh` · **Test:** `.agents/tests/saga-wake-drain-start.test.sh`

## What was wrong

31 wakes sat in the durable queue from 2026-11-17 to 2026-11-19. The session start only counted them in the head
("wakes 3 · decisions 0 …"). Nothing drained them unless the arm fired a wake, so a helm that started cold carried a
queue nobody read.

## What was forged

- `saga-wake-drain.sh start` is the session start's drain. It presents every owed wake, writes each one to the
  append-only ledger `<state>/wake-ledger.log`, acknowledges exactly what it presented, and reports in one line. It
  shows the first eight wakes and points at the ledger for the rest.
- The ack keeps its own rules: it consumes only the lines the drain presented, so a wake that lands later survives;
  and when another live session holds the arm, the ack refuses and the start says "presented, NOT acknowledged".
- `saga-session-start.sh` (the full start) runs it after the head, for the helm only. A seat, or a session that does
  not hold the lock, is read-only for drain and prints how many wakes wait for the holder.
- Nothing is lost by the ack: the ledger keeps every presented line, and it is only ever appended to.

## Proof (measured)

A whole session start, run from a scratch copy of `bin/` with the hall-mutating doors stubbed, fenced state, and 31
queued wakes:

```
lock: held by this session (pid 3772731)
drain: 31 wake(s) were owed at session start — every one is in …/state/wake-ledger.log
WAKE 2026-11-19 03:50 CET — 1795000001	1	signal	probe-1	synthetic wake 1
… (seven more)
… and 23 more in the ledger
drain: wake queue: acknowledged (0 pending)
wake queue after the drain: 0 pending
queue file: empty
ledger wakes: 31
```

`bash .agents/tests/saga-wake-drain-start.test.sh`:

```
  ok   the drain line names what was owed
  ok   the queue is empty after the drain
  ok   every presented wake is in the ledger
  ok   a second start owes nothing
  ok   the ledger is never rewritten
  ok   a wake after the presentation survives the ack
saga-wake-drain-start: 10 passed, 0 failed
```

## CHANGE LOG

- **2026-11-19** — written with the change it describes.
