# Developer N

## Identity
- **Name:** *(replace)*
- **Role:** *(e.g., Backend / Frontend / DevOps)*
- **Platform:** *(macOS / Linux / Windows)*

## Core Setup
- **Stack:** *(from TECH_STACK.md)*
- **Toolchain:** *(pinned versions)*
- **Environment:** `.env` from `docs/CI_CD/deployment/envs/development.env.example`
- **Credentials:** *(SSH key, secret-manager refs — never raw secrets)*

## Local Loop
- **Start:** `.agents/skills/lifecycle/start.sh`
- **Test:** `.agents/skills/features/<feature>/test.sh`
- **Verify:** `.compliance/gates/check_env.sh`, `check_paths.sh`, `check_platform.sh`

## Responsibilities
- *(what this developer owns)*