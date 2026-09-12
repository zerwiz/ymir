# SKILL.md — Embedded Agent Skill Compliance

Headless CLI runner + local validation layer — the sole, script-first compliance mechanism.

The compliance skill is **self-contained**: it needs no rest of the NSR repo. It carries its own runner, gates, telemetry, envelopes, templates, and a generator that stamps `.compliance/` into whatever repo it is deployed into.

## Purpose

- Generate the deterministic `.compliance/` harness into a repo with one command.
- Execute feature + lifecycle scripts and gate checks locally inside that repo.
- Enforce typed envelopes (validated before any run) and wired, non-stub scripting.
- Record every run (phase, status, latency, cost) into a local SQLite DB.

## Capabilities

- **Generate** — `generate.sh [TARGET]` stamps a `.compliance/` tree into the host repository (idempotent; `--force`). Stack-agnostic: the wiring that follows adapts to whatever stack the repo uses.
- **Harness** — `harness/runner.py` orchestrates gates + feature scripts; validates typed envelopes; full `--plan` runs (envelope → gates → feature action → result envelope); `--list` shows the script registry.
- **Danger validation** — `gates/check_danger.sh` flags scripts containing dangerous primitives unless they declare `# gate: dev|guard|human`. The runner refuses to auto-run human/guard-gated scripts.
- **Wiring awareness** — `gates/check_wiring.sh` reports which scripts are still shipped stubs vs bound to the project's real commands (`--strict` must pass before agents are trusted).
- **Gates** — `gates/check_env.sh`, `check_paths.sh`, `check_platform.sh`, `validate_code.sh`, `verify_docs.py` decide pass/fail by `$? == 0`.
- **Config** — `config/core_four.yaml` governs Context, Model, Prompt, Tools per phase.
- **Envelopes** — `harness/envelopes/task_envelope.json` (+ `result_envelope.json`) valid task packets; success must be earned.
- **Telemetry** — `telemetry/logger.py` writes runs/events to SQLite (`runs.db`); readers poll SQLite.

## Usage

```
# 1. Generate the harness into this repo (self-contained)
.agents/skills/NSRcompliance/generate.sh

# 2. Report wiring status; strict before trusting agents
.compliance/gates/check_wiring.sh
.compliance/gates/check_wiring.sh --strict

# 3. Danger audit
.compliance/gates/check_danger.sh

# 4. Validate a task envelope (exit 1 on any schema violation)
.compliance/harness/runner.py --envelope .compliance/harness/envelopes/task_envelope.json

# 5. Full run: envelope -> gates -> feature action -> result envelope
.compliance/harness/runner.py --plan <task-envelope.json> --action test

# 6. Run a feature / all gates / inspect the registry
.compliance/harness/runner.py --feature <name> --action test
.compliance/harness/runner.py --gates
.compliance/harness/runner.py --list

# 7. Telemetry
.compliance/telemetry/logger.py log --phase plan --status success --latency-ms 120
.compliance/telemetry/logger.py query --last 10
```

## Wiring to the project (what binds the compliance to your stack)

The compliance is project-agnostic by design; the WIRING layer is where it benefits the specific project.

1. Replace the stub bodies in `.agents/skills/lifecycle/{start,stop,status,smoke_test}.sh` with your real commands (Phoenix: `mix phx.server`; Node: `npm run dev`; Django: `manage.py runserver`...). Existing procedures are **wrapped, never replaced** — delegate to them and add env/exit-code guards.
2. For every feature in `FEATURES.md`, wire `features/<name>/{setup,test,smoke_test,rollback}.sh` to the app's real suites and seeds.
3. Add `# gate: dev|guard|human` to any script that touches production-affecting primitives.
4. Prove it: `check_wiring.sh --strict` and `check_danger.sh` must pass.

Walkthrough: `docs/BEST_PRACTICES/compliance-wiring.md`.

## Rules

- Zero ad-hoc shell commands — invoke compliance scripts only.
- Gate results are evaluated by `$? == 0`, never by parsing text output.
- Never lose a function: wiring delegates to existing procedures and adds guards.
- Generated `.compliance/` is derived from this skill — regenerate, don't hand-edit both copies.
- Syncs with WayOfTeams (Kanban Board, Knowledge Base, Anchor Memory) over MCP.