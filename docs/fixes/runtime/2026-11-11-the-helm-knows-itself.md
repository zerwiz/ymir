# The helm knows itself — and Rödd runs the pin

Plans 254 (B1b, B1c, B7) and 257 (H7, H8).

## What was wrong

The arm lease named a pid, a generation, a service mode and a shelf. It did not say whose hand held the helm,
what that hand was for, which machine it stood on, or how old the code it ran was. Each of those had to be
inferred from a path or from behaviour.

Rödd ran the working tree. Her window was `electron ~/ymir/apps/rodd` and her tool server was
`uvicorn --app-dir ~/ymir/apps/rodd/ui`. No unit pinned her, so the pinned-runtime ward could not see her.

Her refusals were not keyed. The toast about a merge of "PR 999" came back night after night, because each
time she met the instruction she raised a fresh notification. PR 999 exists in no repository the house owns.

## What changed

| Part | Change |
|---|---|
| `src/ymir_runtime/identity.py` | new: resolves seat, charter, host, machine, fleet role, fleet and the pin's sha and age, once per five minutes |
| `src/ymir_runtime/watch.py` | the lease carries those fields, written at take; a missing host or role writes `identity=readonly` |
| `bin/engine/ymir-engine.sh identity [--check]` | prints the identity; `--check` exits 3 and names the missing field |
| `bin/seat/helm-identity.sh` | new: the ONE row (and the digest's one line) read from the lease |
| `bin/voice/rodd-arm.sh`, `bin/seat/lock-ask.sh`, `bin/time/saga-session-start.sh` | read that row back |
| `bin/voice/rodd-arm.sh hold`, `bin/pi/syn-watch-arm.sh` (clause 4) | refuse a holder that cannot resolve its host or fleet role |
| `apps/rodd/start.sh`, `apps/rodd/src/main.js`, `apps/rodd/src/pin.js` | resolve the code root from the pin; hand over to the pinned copy; refuse with one line when the pin is absent |
| `apps/rodd/electron/ymir-rodd.service.in`, `bin/desktop/desktop-place.sh` | her unit, rendered with `ExecStart=<pin>/apps/rodd/start.sh`; the launcher starts it |
| `bin/seat/armpin.sh`, `bin/agents/eir-doctor.sh` | new `armpin` surface: the pin is current, and every supervisor executes from it |
| `bin/voice/rodd-helm.sh` | every refusal goes through `bin/notify/send.sh --key rodd:refusal:<sha>`; her own notices are never re-judged |
| `bin/voice/voice-toolbox.py` | a memory item asking her to merge is served `void`, with the reason |

Her memory under `$YMIR_HOME/hodd/state/rodd/memory.jsonl` carries the dated correction: PR 999 exists in no
repository this house owns, and merging is the Allfather's hand (Rule 08).

## Proof

- `src/ymir_runtime/tests/test_watch.py` — 61 tests, seven new on the identity.
- `bin/voice/tests/test_rodd_arm.sh` — 60 passed, with the one-row `who`, `unnamed` rendering and the hold gate.
- `bin/voice/tests/test_rodd_helm.sh` — 26 passed: clause 4, and the same refused instruction twice is one
  `send` and one `duplicate` from the real notify door, with two room lines.
- `bin/agents/eir-doctor.sh check` reports `armpin` — on heimdall today it is broken, honestly: the pin is
  166 behind, and Rödd plus two arm clients run the working tree.

> [!IMPORTANT]
> Owed after merge: `bin/engine/runtime-deploy.sh` to move the pin, then `bin/desktop/desktop-place.sh apply`
> to render Rödd's unit, then restart her from the launcher. Until then `armpin` stays red, as it should.

## CHANGE LOG

- **2026-11-11** — written with the change it describes.
