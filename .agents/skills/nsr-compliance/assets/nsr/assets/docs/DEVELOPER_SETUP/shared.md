# DEVELOPER_SETUP — Shared (All Platforms)

Cross-platform toolchain/env/git rules.

## Toolchain
- Runtimes per `TECH_STACK.md` (pinned versions).
- bash (POSIX) for automation; Windows uses WSL2 / Git Bash.

## Git & Credentials
- SSH key + secret manager (references only).
- Git ops via `.agents/skills/git_ops/`.

## Environment
- Copy `docs/CI_CD/deployment/envs/development.env.example` → `.env`.
- Inject real values via env / secret manager. Never commit `.env`.

## Rules
- Everything via `.agents/skills/` scripts — zero ad-hoc.
- Repo-relative paths; forward slashes; LF.