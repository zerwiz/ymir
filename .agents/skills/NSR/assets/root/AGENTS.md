# AGENTS.md — __PROJECT__

__DESCRIPTION__. This file is the fluff-free router — read the referenced docs before acting.

## Routing

- **`WayOfNorthstarRules.md`** — the canonical ruleset every project follows. Read first.
- **`ARCHITECTURE.md`** — system overview.
- **`STRUCTURE.md`** — repo tree map. Use it to find files without guessing.
- **`FEATURES.md`** — master feature registry (prevents duplication).
- **`TECH_STACK.md`** — what stack to use for what feature.
- **`RULES.md` / `RULES/`** — execution rules index + detail.
- **`docs/HOSTING/`** — hosting core info; never break production.
- **`docs/DEVELOPER_SETUP/`** — developer core setups.
- **`docs/CI_CD/deployment/`** — envs, per-client, per-tenant deployment configs.
- **`docs/working-with-agents.md`** — operating manual: how to work with agents.
- **`docs/project-skills.md`** — every skill this project ships (compliance-ready checklist).

## Core Rules

1. **Zero ad-hoc shell commands** — all operations via `.agents/skills/` scripts. No raw `npm test`, `git commit -m ...`, `kill -9`.
2. **Env-driven config** — no hardcoded values; everything from `.env`/secret manager; secrets never committed.
3. **Multi-deployment** — env tiers, per-client deployments, shared multi-tenant instances.
4. **Relative paths only** — repo-root-relative; absolute paths forbidden (gated).
5. **Cross-platform** — Mac, Linux, Windows (WSL/Git Bash); POSIX scripts.
6. **Subfolder `AGENTS.md`** — every functional subfolder defines scoped rules.
7. **No feature duplication** — register in `FEATURES.md`, ship scripts under `.agents/skills/features/<feature>/`.
8. **Deterministic gates** — pass/fail by exit code (`$? == 0`), never text parsing.
9. **Hosting & developer docs** — production hostings (`docs/HOSTING/`) and developers (`docs/DEVELOPER_SETUP/`) always documented.
10. **Tech-stack discipline** — use `TECH_STACK.md`; one primary stack per feature.

## Workflow

1. Start at `STRUCTURE.md` to locate code; check `FEATURES.md` before building.
2. Read `docs/working-with-agents.md` before dispatching any agent.
3. Run operations via `.agents/skills/` scripts (lifecycle, git_ops, feature skills).
4. Configure env via `docs/CI_CD/deployment/envs/*.env.example` → `.env`.
5. Pass all gates (`.compliance/gates/*`) before committing or deploying.