---
section: core-install-run-operate
---
| Adding a gate | Every CI gate is one file under `bin/gates/checks.d/`, so two branches adding two gates never conflict | a new gate is a new file named `<NNNN>-<name>.sh` that calls `gate` once; `bin/gates/ci-verify.sh` reads the directory and runs it, and `bin/gates/tests/test_gate_directory.sh` proves two added gates merge and a failing gate fails the run | [docs/features/adding-a-gate.md](docs/features/adding-a-gate.md) |

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #767
