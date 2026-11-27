# The installer seats the reply hook

## What went wrong

The new Claude Code hook needed an entry in the user's settings, and the seat law did not say to answer the sender.

## What changed

`harness-extensions-install.sh` adds one `Stop` entry for `reply-back.sh`. `herdr-run.sh` says in the seat law that the final answer goes back.

## Proof

`bin/time/tests/test_saga_head.sh`.

## CHANGE LOG

- 2026-11-26 — review-mend: added missing heading for #966

- 2026-11-26 — part of plan 381, an answer goes back the way it came.
