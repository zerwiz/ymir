---
section: memory-secrets
---
| Security | **The agnostic audit — the public repository carries your craft, never your life** (`bin/gates/agnostic-audit.sh` · [how-to](docs/features/agnostic-audit.md)) | His word, 2026-11-14 (plan 287 §5): *"it's critical that ymir's repo is 100% agnostic; our special tooling etc belongs in ymir home."* One door reads every tracked file against the words in your home (`hodd/identity/public-deny.txt`, seeded from `hodd/identity/public-deny.txt.example`) plus two generic shapes (a concrete private address, a real `ts.net` host), prints a report for a person and one row for a machine, and never prints the list itself. It is the pre-push ward over what a push adds, the two twice-daily clocks on the heart (`bin/time/nornir-job-agnostic-audit.sh` over a fresh `origin/main`, and `bin/time/nornir-job-private-scan.sh` over the working tree) — both call this engine rather than judging the same words twice. Proved by `bin/gates/tests/test_agnostic_audit.sh` | [docs/features/agnostic-audit.md](docs/features/agnostic-audit.md) |

## CHANGE LOG

- 2026-11-14 — added with the audit and its clock (plan 287 §6).
