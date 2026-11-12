## voice · unversioned · 2026-11-12 — the voice status row names Rödd's face in one word

### Why

`voice-ensure.sh status` printed its `rodd` row over two lines, `"missing` and then `missing"`. The face check
asked `apps/rodd/setup.sh --check`, which already prints `missing`, `stale:<why>` or `present`, and then
appended its own `missing` when that check failed. Eir's `voice` row read this door and showed no reason at all,
so a seat whose only voice fault was an unbuilt face saw an empty red row (plan 278, problem 10).

### What changed

`face_status` prints the first line of `setup.sh --check`, or `missing` when the check prints nothing. The row is
one line again, and Eir's `voice` row now reads it as its reason.

### Proof

On a seat with an unbuilt face, `voice-ensure.sh status` prints one `rodd` row with `missing`, and
`eir-doctor.sh check` shows `voice` broken with that reason instead of an empty detail.

### Files

- `bin/voice/voice-ensure.sh`

## CHANGE LOG

- **2026-11-12** — Opened.
