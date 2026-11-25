# The ack consumes only what was shown

**Component:** time (plan 369 item 16)

## What was wrong

The wake sequence moved while the queue was empty, and finished reports were never seen. The drain had
three ways to eat a wake:

1. It recorded "what was shown" by copying the queue after printing. A wake that arrived while it printed
   was recorded as shown, and the next ack removed it.
2. A session that may not ack still wrote that record, replacing the arm holder's.
3. The ack rewrote the queue file while writers appended to it, so an append could be overwritten.

Seats raised by `herdr-run.sh` also left no pane on file, so a question could not be answered through
`eindri-answer.sh`.

## What changed

- The record is the lines about to be shown, written before they are printed.
- A session that may not ack writes no record.
- The queue is moved aside to remove lines, and what stays is appended back.
- `herdr-run.sh` writes `seat_pane=` into the seat's `.meta`.

## Proof

`bin/time/tests/test_wake_seq.sh` (gate `wake-seq`). The pane record has no live seating proof.

## CHANGE LOG

- 2026-11-25 — review-mend: added missing heading for #956
