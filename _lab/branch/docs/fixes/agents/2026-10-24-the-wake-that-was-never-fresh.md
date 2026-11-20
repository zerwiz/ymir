# The wake that was never fresh — freshness read as "a door is non-empty"

**Dated:** 2026-10-24 · **Component:** agents · **Branch:** `fix/arm-door-and-wake-cadence`
**Found on:** sleipnir (the hand — Termux/Android, Pi 1.4.0)

## The symptom

~20 identical watcher wakes queued into one session. The wake was judged *fresh*
every time, over an arm that was up.

## Two faults

**1. Freshness was the door's emptiness, not the door's change.** In
`.pi/extensions/gna-pi-watch.ts`, `queueHasFreshContent()` returned true whenever
**any** durable door held **any** content:

```ts
for (const p of [`${state}/.wake-queue`, `${fmHome}/.agents/state/.wake-queue`]) {
  if (readFileSync(p, "utf8").trim().length > 0) return true;
}
```

One line written on **2026-10-17** — a round-trip test message, and with **no
trailing newline** — sat in `~/ymir-home/state/.wake-queue`. Every watcher wake was
therefore "fresh" at every turn boundary, because the door was non-empty *and never
would be empty*: the drain counted the file with `wc -l` (newlines → **0**) while
the extension tested it with `-s` (bytes → **non-empty**). The drain presented
nothing, wrote no `.wake-drained` snapshot, and the ack consumed nothing.

**2. A dead plan door — `skuld_plan` threw `execFileSync is not defined`.**
`.pi/extensions/skuld-branch-supervision/index.ts` imported only `spawnSync` while
four sites (lines 8, 1615, 1622, 1648) call `execFileSync`. Both the plan board and
the ticket board sit behind that one import, and nothing asserted that either
answers.

## The fix

- `durableDoors()` fingerprints the **content** of both doors. A wake is delivered
  again only when that content **changed** since the last delivery, or when the floor
  (`WAKE_REPEAT_FLOOR_MS`, 10 minutes) has passed. A stale line can no longer make a
  repeated wake look new.
- `bin/time/saga-wake-drain.sh` counts with `awk 'END{print NR}'` so an unterminated
  final line is presented (the runtime note owns that half).
- `import { execFileSync, spawnSync } from "node:child_process";` — the plan board and
  the ticket board answer again.

## Verification

```
bin/time/saga-wake-drain.sh            → wake queue: 1 pending, WAKE from=brokk … 2026-10-17 …
bin/time/saga-wake-drain.sh ack        → wake queue: acknowledged (0 pending)
. wake-queue / .wake-drained / .wake-last-hash / .arm.event   → all absent (clear)
bin/pi/syn-watch.sh status --detail    → arm=up … pid=32606 heartbeat=1s
```

## Restart

A running `pi` keeps the extension it loaded. **Close every Pi session started
before this branch** (including the one that queued the 20 wakes) — the new dedupe
and the repaired Skuld tools take effect only at the next start.
