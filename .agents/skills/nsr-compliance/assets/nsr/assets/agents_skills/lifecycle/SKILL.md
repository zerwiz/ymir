# SKILL.md — lifecycle

Routing for application lifecycle operations.

## Scripts
| Command | Script | Usage |
|---------|--------|-------|
| start | `start.sh` | Spin up the app for the configured env |
| stop | `stop.sh` | Graceful shutdown |
| status | `status.sh` | Health check |
| smoke_test | `smoke_test.sh` | Post-boot verification |

## Rules
- Run only these scripts for lifecycle ops.
- Exit codes are authoritative (`0` pass, non-zero fail).

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
