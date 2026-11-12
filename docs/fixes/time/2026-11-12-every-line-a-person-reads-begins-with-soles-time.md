# time · 2026-11-12 — every line a person or the helm reads begins with Sól's time

## What was wrong

Wake lines, status lines, drain lines and Rödd's error sentences carried no time, and Rödd's room showed epoch seconds. A repeat could not be told from a new event (plan 272, fault 4; plan 271).

## What changed

`sol.sh line` prints the one shape, for example `2026-11-12 14:55 CET`. `bin/time/sol-lib.sh` renders the same shape without a process per line: `sol_line`, `sol_stamped`, `sol_prefix`, `sol_from_epoch`.

| Road | Now |
|---|---|
| Wake queue (`eindri_queue_wake`) | each line begins with the stamp |
| Worker status line | `done: <stamp> — <text>`, so the state is still first for readers |
| Report shelf, acclaim output | begin with the stamp |
| Wake drain | an unstamped line is stamped when shown |
| Stop-hook banner | every line stamped; the arm's own grammar stays inside each line |
| Rödd (`rodd-arm.sh`) | errors stamped; the room's epoch `ts` is shown as the stamp |

Machine fields (`heartbeat=`, the room's `ts`) are unchanged for parsing.

## Proof

`bin/gates/tests/test_sol_stamps.sh` (11 checks) and `bin/voice/tests/test_rodd_arm.sh` (61 checks).

## Not done

The arm client's own `watcher:` lines and the user-wide hook in the home keep their grammar unstamped; the Stop-hook banner stamps them for the reader.

## CHANGE LOG

- **2026-11-12** — written with plan 272.
