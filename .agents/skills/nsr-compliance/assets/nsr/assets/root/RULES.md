# Rules — __PROJECT__

Core enforcement & execution rules. Detail lives in `RULES/`.

## Non-Negotiable Core Rules

1. **Dual-layer docs** — root routing files are fluff-free; detail in `RULES/` and under `docs/`.
2. **Zero ad-hoc shell commands** — every op via `.agents/skills/` scripts.
3. **Env-driven config** — no hardcoded values; secrets never committed.
4. **Multi-deployment + multi-tenant** — env tiers, per-client, shared tenants.
5. **Relative paths only** — gated by `check_paths.sh`.
6. **Cross-platform** — POSIX, forward slashes, LF; gated by `check_platform.sh`.
7. **Deterministic harness** — Core Four config, `$? == 0` gates, typed envelopes, telemetry.
8. **No feature duplication** — `FEATURES.md` registry + skill dirs.
9. **Subfolder `AGENTS.md`** — scoped boundaries per folder.
10. **Hosting/developer docs** — `docs/HOSTING/`, `docs/DEVELOPER_SETUP/` always current.
11. **Tech-stack discipline** — `TECH_STACK.md`, one primary stack per feature.
12. **Work with agents per `docs/working-with-agents.md`** — bounded nodes, code owns the graph.
13. **Ship the `docs/project-skills.md` skill set** before compliance-ready.

## Rule Files (`RULES/`)

| File | Status | Domain |
|------|--------|--------|
| `security.md` | ✅ | Access control, secrets, tenant isolation |
| `git-workflow.md` | ✅ | Branching, commits, PR gate |
| `tech-stack.md` | ✅ | One primary stack per feature, pinned versions |

## Mandatory Script Domains (per feature)

| Domain | Files | Responsibility |
|--------|-------|----------------|
| Lifecycle | `start.sh`, `stop.sh`, `status.sh` | Predictable spin-up/teardown |
| Testing | `test.sh`, `smoke_test.sh` | Targeted suites + smoke checks |
| Data & Setup | `setup.sh`, `seed.sh`, `migrate.sh` | Deterministic state prep |
| Source Control | `safe_commit.sh`, `sync.sh` | Safe git operations |
| Diagnostics | `audit.sh`, `logs.sh` | Health & telemetry |