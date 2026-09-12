# docs/DEVELOPER_SETUP/

Per-developer core setup — explain every developer so no one guesses.

## Who Develops Here (Brief)

1. **Developer 1 — *(name)*:** *(role)* — *(stack)*.
2. *(add each developer)*

## Core Setup (Common)

1. Platform: Mac/Linux/Windows (WSL2 / Git Bash for POSIX).
2. Toolchain: pinned in `TECH_STACK.md`.
3. Clone + install via `.agents/skills/` scripts.
4. Env: copy `docs/CI_CD/deployment/envs/development.env.example` → `.env`; inject via secret manager.
5. Credentials: SSH key + secret manager (references only).
6. Verify: `check_env.sh`, `check_paths.sh`, `check_platform.sh`.

## Explicit Per-Developer Files

- `developers/dev-1.md` .. `dev-N.md` — one file per developer.

## Platform Appendices

- `shared.md` — cross-platform rules.
- `macos.md`, `linux.md`, `windows.md`, `agent.md`.