# DEVELOPER_SETUP — Windows

Use WSL2 (recommended) or Git Bash for POSIX automation.

## Option A — WSL2
- `wsl --install`, then follow `linux.md`.

## Option B — Git Bash
- Install "Git for Windows"; run `.sh` from Git Bash.

## Gotchas
- LF line endings (rejected by `check_platform.sh` if CRLF).
- No `C:\...` absolute paths (rejected by `check_paths.sh`).
- No `taskkill`/`pkill` in project scripts.