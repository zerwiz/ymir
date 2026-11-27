# The two-machine done road is recorded

## What went wrong

The fix notes for the answer-back road said the done road across two machines was not proven. The run that fell back
to the arm holder was recorded only in a pull request comment.

## What changed

- `2026-11-27-a-worker-talks-back-to-its-sender.md` records the fallback run and the live run under Second machine,
  with the sender pane's read.
- `2026-11-27-a-done-with-no-line-still-reaches-the-sender.md` says what the two-machine runs showed.

No code changed.

## Proof

The live run, `proof-971-live`, at head `aafa9bf8a`: the done line landed in a live sender pane on the other machine.

## CHANGE LOG

- 2026-11-27 — the fallback run and the live run are recorded.
