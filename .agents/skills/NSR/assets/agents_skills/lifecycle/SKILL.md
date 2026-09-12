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