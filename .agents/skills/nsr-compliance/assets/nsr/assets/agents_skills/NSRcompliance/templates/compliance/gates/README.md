# gates/ — __PROJECT__

Deterministic validation gates. Decided by exit code.

## Files
- `check_env.sh` — required env vars present.
- `check_paths.sh` — no absolute paths.
- `check_platform.sh` — POSIX-portable.

## Rules
- Gates evaluate by `$? == 0`.
- Run before commit and before deploy.

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
