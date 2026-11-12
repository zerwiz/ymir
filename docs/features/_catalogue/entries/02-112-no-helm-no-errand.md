---
section: agents-work-collaboration
---
| Agents | **No helm, no errand — and the helm runs the pin** (`src/ymir_runtime/seat.py` · `bin/pi/arm-pin.sh` · [how-to](docs/features/no-helm-no-errand.md)) | His word, 2026-11-11: *"it should not be able to send out an endri with out making them talking to the arm"* · *"he are running the pinned code"*. The engine's seat door refuses (exit 1, nothing created) when no live helm holds the arm lease; the errand's record goes to the shelf the lease names, and its meta carries `helm_pid`, `helm_gen` and `helm_state`. A terminal status line wakes the arm once by itself. The arm client, its three harness adapters and Rödd run the pinned runtime, and `arm-pin.sh` puts the pin's age on the board (`pin <sha> · <n> behind`, Eir's `armpin`). Plan 257 | [docs/features/no-helm-no-errand.md](docs/features/no-helm-no-errand.md) |

## CHANGE LOG

- 2026-11-12 — added with the gate and the pin (plan 257 H1–H3, H6–H8).
