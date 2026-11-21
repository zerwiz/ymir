# bridge · 2.1.1 · 2026-11-21 — the chain's probe waits for a slow gateway, and the last ditch asks again

A repair to the chain (`2026-11-21-one-door-carries-the-fallback.md`), after the review measured it.

## What was wrong

The health probe was capped at 3 s. The hosted gateways answer their model list in 6 to 8 s (measured
5.96 s and 7.58 s), so a healthy gateway was marked down and skipped. With every earlier step down, the door
then answered 503 although the last step would have answered.

## What changed

- Each step may name `probe_timeout`; the default is **10 s**.
- **A last-ditch pass.** When the health check skips every step, each one (except a step with a config
  problem) is asked once more before the door answers 503. The log names it `(last ditch)`.
- The local-models asset and the models runbook stop teaching the retired desktop server and the model
  daemon as local roads; what is kept on purpose is listed in the first note.

## Proof

`bin/bridge/tests/test_bifrost_chain.sh` gains case 9 (every probe fails, the last ditch answers): 16 passed.
On the real steps the fourth step (the second hosted gateway) answered with the first three forced down.
