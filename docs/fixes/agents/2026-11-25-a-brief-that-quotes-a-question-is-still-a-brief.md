# A brief that quotes a question is still a brief

**Component:** agents (plan 369 item 15)

## What was wrong

`worth_a_smith` in `bin/seat/herdr-run.sh` called any text with a `?` anywhere a question. A long build
brief that quoted a question was refused. `eindri-start.sh` then printed "too brief — answer it in hand"
for every refusal, whatever the cause.

## What changed

- A text is a question only when it is under 25 words and either opens like one or ends in `?`.
- `herdr-run.sh` says why it refused: a question, too brief, short errand, or the local model is busy.
- `eindri-start.sh` prints that reason.

## Proof

`bin/seat/tests/test_worth_a_smith.sh` (gate `worth-a-smith`).
