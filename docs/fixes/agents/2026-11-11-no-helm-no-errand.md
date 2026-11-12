# No helm, no errand — and the helm runs the pin

**Date:** 2026-11-11 (built 2026-11-12) · **Component:** agents (the seat door, the arm, Rödd) · **Plan:** 257, phases H1–H3 and H6–H8

## What was wrong

- A worker could be sent out with no live arm, so its finished report reached nobody.
- The arm service ran the pinned runtime, but the per-turn arm clients and Rödd ran the
  working tree, which an agent may leave on any branch.
- The pin itself was **166 commits behind** origin/main (`4b09c4a1`, 2026-11-09) and had
  4 uncommitted files. Nothing on the board said so.
- A finished worker woke the arm only if it remembered to run `eindri-acclaim.sh`.
- The repeated desktop alarm *"Rödd refuses a wake beyond her writ: please merge PR 999"*
  came from `bin/voice/tests/test_rodd_helm.sh` driving the real speaker.

## What changed

| Phase | Change | Where |
|---|---|---|
| H1 | The seat door refuses before creating anything when no live helm holds the lease. It checks the lease exists, its `state=` is this house, the pid is alive with its recorded start time, and the heartbeat is fresh. The refusal is `NoHelm`, which exits **1**. | `src/ymir_runtime/seat.py`, `errors.py`, `__main__.py` |
| H2 | The errand's record root is the lease's own `state=`, never a seat's private `BROKK_STATE_OVERRIDE`. An unwritable arm shelf is refused. | `seat.py` (`arm_shelf`, `_helm_gate`) |
| H3 | A terminal status line newer than `state/<id>.woke` raises exactly one `signal:`. Lines older than the first poll are seeded silently. `eindri-acclaim.sh` writes the same cursor. | `src/ymir_runtime/watch.py`, `bin/agents/eindri-acclaim.sh` |
| H6 | One resolver for the pin (`bin/pi/arm-pin-lib.sh`). The tree's arm client hands over to the pin's; with no pin it stands read-only. The pi, OpenCode and Claude adapters call the pin's client. Gróa fast-forwards the pin and re-proves its units. The lease carries `pin=` and `pin_behind=`. | `bin/pi/syn-watch-arm.sh`, the adapters, `bin/agents/groa-update.sh` |
| H7 | Rödd's `start.sh` and Electron main run the pin and refuse in one line without it. `--install-unit` renders a unit the pinned-runtime ward can see. Every refusal is one room line, and one toast per key per hour. | `apps/rodd/`, `bin/voice/rodd-helm.sh` |
| H8 | `bin/pi/arm-pin.sh` prints the pin's age and names surfaces outside it. Eir has an `armpin` surface; the digest prints the one line. | `bin/pi/arm-pin.sh`, `eir-doctor.sh`, `saga-session-start.sh` |

> [!IMPORTANT]
> The first draft of H1 raised `EngineRefusal`, which exits 4. On exit 4,
> `einherjar-spawn.sh` runs its old road, so the worker would have been seated anyway.
> The proof through the real door caught it. `NoHelm` is a hard refusal for that reason.

## Proof

- `ymir-engine.sh seat proof-one …` with an empty synthetic state: `refused: no helm, no errand …`, rc 1, no worktree and no meta created.
- `HelmGateTest` (11 cases): no lease, dead pid, reused pid, stale heartbeat, missing heartbeat, foreign house, override recorded, live lease admitted with `helm_pid`/`helm_gen`/`helm_state` in the meta, record on the arm's shelf, symlinked tree shelf accepted, and exit 1 from the CLI.
- `test_watch`: `done:` alone wakes once, a second poll does not; old lines are seeded; an acclaimed line is not woken twice; `blocked:` never raises by the record.
- `bin/seat/tests/test_arm_pin.sh` 14/14, `test_arm_pin_board.sh` 11/11, `bin/voice/tests/test_rodd_pin.sh` 10/10, `test_rodd_helm.sh` 19/19, `bin/gates/tests/test_arm_client_helm.sh` passes.

## What is still owed

- On this box the pin is 166 behind and dirty, so `armpin` reports broken until the pin is
  cleaned and moved (`bin/engine/runtime-deploy.sh`) after this lands. Gróa skips a dirty pin
  on purpose.
- The two working-tree arm clients (pids 3244506 and 3597289) and Rödd (electron 121634,
  uvicorn 121707) retire only when their sessions re-arm with this code from a current pin.
- `ymir-rodd.service` is rendered by `apps/rodd/start.sh --install-unit`; it is not installed
  on this box by this change.
