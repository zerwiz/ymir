# .compliance/ — __PROJECT__

Deterministic harness engine. Programmatic guardrails for every agent run.

## Structure
```
.compliance/
├── config/         # core_four.yaml (Core Four)
├── gates/          # check_env.sh, check_paths.sh, check_platform.sh
├── harness/        # runner.py + envelopes/
├── telemetry/      # logger.py
└── installer/      # install.sh
```

## Rules
- Code-based gates: `$? == 0`, never text parsing.
- Typed envelopes for inter-agent handoffs.
- Observability logged for every run.