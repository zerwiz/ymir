# gates/ — __PROJECT__

Deterministic validation gates. Decided by exit code.

## Files
- `check_env.sh` — required env vars present.
- `check_paths.sh` — no absolute paths.
- `check_platform.sh` — POSIX-portable.

## Rules
- Gates evaluate by `$? == 0`.
- Run before commit and before deploy.