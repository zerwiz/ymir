# UTGARD Sandbox (Docker Execution Barrier)

Isolated container execution for untrusted code, dynamic skills, and sub-agent tasks.

## Contents (to be implemented)
- `Dockerfile.utgard` — hardened minimal execution container (exists)
- `utgard.config.json` — CPU / RAM / timeout limits (exists)
- `execute_utgard.ts` — Docker launcher skill for safe script execution

## Rules
- `--network none` by default
- Strict `--memory` and `--cpus` limits
- No host root access
- Failed executions never touch main branches

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
