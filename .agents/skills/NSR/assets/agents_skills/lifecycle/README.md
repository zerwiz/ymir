# lifecycle/ — __PROJECT__

Application lifecycle automation. Predictable spin-up, teardown, and health verification.

## What Goes Here

- `SKILL.md` — Tool routing & skill guidelines for lifecycle operations.
- `start.sh` — Safe application spin-up.
- `stop.sh` — Graceful shutdown.
- `status.sh` — Health check.
- `smoke_test.sh` — Post-boot verification.

## File Pattern

```
lifecycle/
├── SKILL.md
├── start.sh
├── stop.sh
├── status.sh
└── smoke_test.sh
```

## Rules

- No direct `kill` or manual background execution — always via these scripts.
- Scripts must exit `0` on success, non-zero on failure (harness parses exit codes, not stdout).