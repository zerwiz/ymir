---
section: agents-work-collaboration
---
| Agents | **The arm is never lost without a word** (`src/ymir_runtime/state/lock.py` · `bin/seat/arm-handover.sh` · `bin/time/saga-session-start.sh`) | His word, 2026-11-20: *"we need to fix so the arm cant randomly lose"* — the helm had changed hands four times in ninety minutes with nothing recorded anywhere. Every change of hands is now one append-only line in the session state (`.lock-journal`, plus `.arm.handover`), the lock has exactly ONE writer, a live owner is never taken from, a session start that finds the arm free but the last helm ALIVE stands read-only until the Allfather seats it (`BROKK_TAKE_HELM=1` or `bin/voice/rodd-arm.sh hold`), and `state/.arm.pane` names the holder's proved pane or nothing. | [docs/features/the-seats-and-the-arm.md](docs/features/the-seats-and-the-arm.md) |

## CHANGE LOG

- 2026-11-20 — added with the fix (`docs/fixes/runtime/2026-11-20-the-arm-is-never-lost-without-a-word.md`).
