## runtime · unversioned · 2026-09-27 — the ack eats only what it saw

### Why

The Allfather's rule, 2026-09-27: *wakes should fire ONLY when the workers are
done.* A ghost remained: the watcher sometimes signalled a wake queue that
drained empty. Root cause, measured: `bin/time/saga-wake-drain.sh ack` truncated the
**entire** queue (`: >"$QUEUE"`), so a wake delivered between a drain and its
ack was eaten — and the catch-up sweep's later re-presentation could ring with
nothing pending. The two back-to-back wakes seen the same evening were real
(two errands done); the empty-drain signal was this ack race.

### The fix

- `ack` now consumes **exactly what the last drain presented**: the drain
  snapshots the queue (and the FM door) to `$STATE/.wake-drained` /
  `.wake-fmq-drained`; the ack performs a multiset diff — handled lines leave,
  lines that arrived after the drain **stay** in the queue for the next signal.
- The flood-brake hash clears only when both doors are truly empty, so the next
  terminal wake signals cleanly and preserved newer wakes keep the brake set.
- Behavior test: 2 wakes → drain → a third arrives → ack leaves the third;
  a second ack without a presentation record consumes nothing.

One wake per terminal act, idempotent by marker, and the ack can no longer eat
an undrained harvest.

galdr-reread: none (the owning asset for the wake road is harness-integration;
the change is in the drain's own semantics).

### Files

- `bin/time/saga-wake-drain.sh`