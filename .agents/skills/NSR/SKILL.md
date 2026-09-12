---
name: NSR
description: Scaffold and validate a new Way-Of NorthStar (NSR) complaint repository/project. Use when creating a new project/repo, converting an existing repo to the NorthStar layout, or auditing a repo for NSR compliance. Installs the full dual-layer docs layout, .agents/skills automation layer, and .compliance deterministic harness, then runs compliance gates.
allowed-tools:
  - run_shell_command
  - run_bash_command
  - edit
  - write
---

# SKILL.md — NSR (WayOfNorthStarRules)

**Scaffold new projects and audit existing ones against the WayOfNorthStar Ruleset.**

The skill is self-contained: it carries every template (`assets/`) and every automation script (`scripts/`) needed to create a fully compliant NSR repository and gate it.

## When to Use

1. **Creating a new project** — from a blank folder to a complete NSR repo.
2. **Converting a legacy repo** — adopt the NorthStar layout + harness onto an existing codebase.
3. **Auditing compliance** — run the gates and report what's missing.

## Key Files

- `WayOfNorthstarRules.md` — the master spec (source of truth). Read before scaffolding when a rule is in question.
- `assets/root/` — root routing file templates (AGENTS.md, ARCHITECTURE.md, STRUCTURE.md, FEATURES.md, RULES.md, BEST_PRACTICES.md, CI_CD.md, TECH_STACK.md, README.md, .gitignore).
- `assets/RULES/` — execution & enforcement rule templates (kept at root).
- `assets/docs/` — the granular docs tree (BEST_PRACTICES, CI_CD, DEVELOPER_SETUP, HOSTING, RUNBOOK, features, research).
- `assets/agents_skills/` — the `.agents/skills/` automation layer templates (incl. the self-contained compliance skill that generates `.compliance/`).
- `assets/compliance/` — legacy `.compliance/` template tree (fallback stamp; the compliance skill's `generate.sh` is canonical).
- `scripts/` — scaffold.sh (create/convert), validate.sh (audit).

## Workflow

1. **Confirm scope** — new blank project, or conversion of an existing repo?
2. **Run the scaffolder:**
   ```bash
   .agents/skills/NSR/scripts/scaffold.sh /path/to/project --name "ProjectName" --description "What it does"
   ```
   - Creates the full NSR tree from templates (project name/description substituted).
   - Installs `.agents/skills/` and generates `.compliance/` via the compliance skill (`generate.sh`), with runnable gates + `WIRE ME` stub scripts.
   - Runs `validate.sh` as a post-condition.
3. **Convert existing repo (optional):** run the same scaffolder over the existing repo — it creates only missing folders/files and never overwrites existing ones.
4. **Author the skill layer** — fill feature dirs under `.agents/skills/features/<feature>/` for every feature in FEATURES.md (setup/test/smoke_test/rollback stubs are provided).
5. **Wire the compliance to the project** — replace `WIRE ME` stubs in `.agents/skills/lifecycle/` and per feature with the app's real commands (delegate + protect; never rewrite). Add `# gate: dev|guard|human` to destructive scripts. Prove it: `.compliance/gates/check_wiring.sh --strict` and `.compliance/gates/check_danger.sh`. Walkthrough: `docs/BEST_PRACTICES/compliance-wiring.md`.
6. **Configure environments** — create `.env.example` templates for env tiers, per-client, and tenant deployments under `docs/CI_CD/deployment/`.
7. **Document hosting & developers** — fill `docs/HOSTING/` and `docs/DEVELOPER_SETUP/` (one explicit doc per hosting & per developer).
8. **Audit:**
   ```bash
   .agents/skills/NSR/scripts/validate.sh /path/to/project
   ```
   Runs every gate (env, paths, platform, docs, structure) and reports pass/fail.

## Referenced Rules (Non-Negotiable)

- Root routing files are fluff-free; ALL granular detail lives under `docs/` (only `RULES/` stays at root).
- Zero ad-hoc shell commands — all ops via `.agents/skills/` scripts.
- Env-driven config — no hardcoded values, secrets never committed.
- Multi-deployment (env tiers + per-client + multi-tenant).
- Relative paths only (gated); cross-platform Mac/Linux/Windows (gated).
- Every hosting (`docs/HOSTING/`) and every developer (`docs/DEVELOPER_SETUP/`) documented.
- TECH_STACK.md maps every feature to a pinned stack.
- Deterministic gates pass/fail by exit code (`$? == 0`).