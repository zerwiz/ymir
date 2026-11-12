# harness/ — __PROJECT__

Local execution harness.

## Files
- `runner.py` — orchestrator (feature scripts + gates).
- `envelopes/` — typed handoff schemas.

## Rules
- Runner invokes `.agents/skills/features/<feature>/*.sh` and evaluates exit codes.
- Handoffs use typed envelopes.

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
