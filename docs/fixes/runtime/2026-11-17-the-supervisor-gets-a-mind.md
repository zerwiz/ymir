# The supervisor gets a mind

**Component:** runtime (`src/ymir_runtime/supervisor.py`, `bin/pi/syn-supervisor.sh`,
`bin/agents/syn-judge.sh`)

**Date:** 2026-11-17

## The fault this answers

The heart had eight observers and no supervisor. An observer tests one thing and reports
it; it can say a port is closed and cannot decide what to do about it. The Allfather's
correction on 2026-11-17: *"the supervisor must work for the intended outcome … and an
agent must be involved in the loop."*

## What changed

The loop now exists as one behaviour in the engine, with two thin doors over it:

- `src/ymir_runtime/supervisor.py` — measure · judge · act · prove · record, and the
  refusals that keep each step inside the house's law.
- `bin/pi/syn-supervisor.sh` — the door (`exec bin/engine/ymir-engine.sh supervise …`),
  beside `bin/pi/syn-watch.sh`, which is the arm.
- `bin/agents/syn-judge.sh` — the judgement's road. The prompt arrives on stdin; the model
  is resolved by `bin/model/agent-model.sh`, allowed by `bin/model/model-allow.sh`, and
  served read-only (`-nt --no-mcp --no-extensions --no-session`). No prompt and no
  threshold live in the door.
- `bin/records/registry-audit.sh` — gains `--registry PATH`, so the supervisor asks the
  audit the same question about the same registry it measures. One truth, two callers.
- `src/ymir_runtime/tests/test_supervisor.py` — 26 cases: the whole loop, a failed proof,
  a `criticality: always` surface escalated and not acted on, no arm meaning no act, a verb
  outside the vocabulary refused, a `*-unit` verb on a container refused, and the helm-state
  rule below.

## What the proof measured, and what it taught

A container was started by this errand (`syn-mind-probe`, a `debian:bookworm-slim` sleeping
container), named in a probe registry under `state/` with `criticality: wanted`, and then
stopped to make the deliberate fault. The loop ran with no person in the middle:

```
measure: syn-mind-probe — container — down — criticality: wanted (service syn-probe)
judge:   start-container syn-mind-probe — …criticality is 'wanted' (not 'always')…
act:     `docker start syn-mind-probe`
prove:   re-measured: syn-mind-probe is up
record:  fixes.md line + one rune
```

The registry flipped to `criticality: always` and the container was stopped again; the loop
escalated instead of acting, and the container stayed down. The probe container and its
registry were then removed.

Two faults were found by running it, and both are fixed here:

1. **The judge chose `start-unit` for a container.** The verbs read right and run wrong, so
   a surface now carries its `kind` (`container` | `unit`), the prompt names it, and `act`
   refuses a verb whose road does not fit the surface.
2. **The first escalation landed in the worker's own seat state.** `paths.resolve` honours
   `BROKK_STATE_OVERRIDE`, which on a dispatched worker is its own `BROKK_MACHINE_STATE_DIR`
   — a wake nobody reads (plan 272, fault 1). `helm_state()` is now the Python twin of
   `bin/agents/eindri-wake-lib.sh:eindri_helm_state`: `BROKK_HELM_STATE`, else the override
   only when it is not the seat's own machine state, else `<home>/state`.

## What it refuses, on purpose

- a verb outside the six the house names, and a verb whose kind does not fit the surface;
- a target the measurement does not name;
- acting with no arm held (exit 3, never a quiet attempt);
- a surface marked `criticality: always` — that question is the Allfather's (plan 004
  §5.1), so the loop escalates in one message and does not retry.

## Tests

```sh
PYTHONPATH=src python3 -m unittest src.ymir_runtime.tests.test_supervisor -q
# Ran 26 tests … OK
```

The engine suite as a whole carries 12 pre-existing failures on `main` (config examples,
dispatch registry doors, state parity) and the same 12 before and after this change;
this errand adds 26 passing cases.

## Not decided here

Whether Sýn may stop a `criticality: always` unit on its own authority plan 004 §5.1 keeps
for the Allfather, and the crown/machine-arm rank question belongs to plan 310. Both remain
open; this change builds the loop and keeps its thresholds named and conservative.
