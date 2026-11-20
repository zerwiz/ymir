# The wake that woke itself — closing an errand rang the bell it clears

**2026-10-24.** Component: `bin/time/saga-wake-drain.sh`.

## What was happening

Four times tonight a wake arrived for an errand **already closed**:

```
WAKE eindri ledger-bookkeeping reported: report filed at state/eindri-reports/ledger-bookkeeping.md
```

The cause is circular and simple: closing an errand claims its report, and the claim writes a wake — so the closer
wakes himself. Two of the earlier cycles were the same shape (`mail-inbound` twice), and one was a genuine stale
signal from a run that had ended hours before.

## The fix, in the view

The drain now checks each `eindri <id> reported` wake against that errand's own status line. If the last line
starts `done:`, `failed:` or `stale:`, the wake is an echo: it is **not presented as news**, and the count is shown
so the silence is explained rather than mysterious.

```
wake_echo[1]{dropped,why}:
  1,"errands already closed — ack clears them, they are not presented as news"
```

`ack` still consumes them, so the queue empties as before; the change is that a closed errand's echo no longer
presents itself as an event that needs a decision.

## Owed, and it is the better fix

The wake should carry the **run id** that wrote it, and a close should remove its own errand's pending wakes at the
source. Then an echo is never written, not merely filtered. This note records the filter as the cheap half.

**Why it matters more than tidiness:** a bell that rings for things already done teaches the reader to ignore the
bell — and this bell is the one that carries a real worker going silent.
