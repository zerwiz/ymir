# A report to the helm goes by the wake queue, never into its input box

**Component:** agents (plan 369, item 8)

## What was wrong

A worker reported to the helm by typing into the helm's herdr pane, through `eindri-send.sh` or
`answer.sh` on a `herdr:<pane>` return address. The helm's input box is often holding the operator's
own draft. Measured on 2026-11-24, the plan-369 worker's two reports sat behind unsent text and reached
nobody, while the worker believed they had landed.

## What changed

- `bin/agents/reply-to.sh` has a new kind, `arm:<machine>`, which means the arm holder's wake queue.
  When the dispatching session **holds the arm** (`ymir-state.sh lock owned`), its errands record
  `arm:<host>`, not its pane. An explicit `--reply-to` still wins, and a sender that does not hold the
  arm keeps its pane.
- `bin/agents/answer.sh` delivers an `arm:` address with `bin/voice/rodd-arm.sh tell`. That door puts the
  line in the queue the holder drains between turns (PR #926 shows the text to an agent-harness holder).
- The fixed core (`.agents/assets/agents/eindri-core.md`) and the seat law (`bin/seat/herdr-run.sh`) both
  say it: report to the helm with `rodd-arm.sh tell`. `eindri-send.sh` stays for briefs into worker panes.

## Proof

`tests/test_answer_door.sh` prints 26 ok and 0 FAIL, including five new checks:

- the holder resolves to `arm:<host>`;
- a holder in a pane is still answered by the queue;
- a non-holder keeps `herdr:<pane>`;
- an explicit address wins;
- `arm:` is accepted by `record`.

## Owed

The fleet overlay in the home (`config/eindri-core.md`) still tells workers to report into the helm's
pane. It is the operator's file, and it is corrected in the home in the same plan.

## CHANGE LOG

- 2026-11-24 — review-mend: added missing heading for #937
