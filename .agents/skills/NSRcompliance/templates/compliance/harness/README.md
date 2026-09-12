# harness/ — __PROJECT__

Local execution harness.

## Files
- `runner.py` — orchestrator (feature scripts + gates).
- `envelopes/` — typed handoff schemas.

## Rules
- Runner invokes `.agents/skills/features/<feature>/*.sh` and evaluates exit codes.
- Handoffs use typed envelopes.