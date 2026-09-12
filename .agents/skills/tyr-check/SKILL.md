---
name: tyr-check
description: Tyr — the one-handed judge of Ymir. Validates that tools, skills, and docs follow the 10 Galdr design principles with TOON output. Use when building, modifying, or reviewing Ymir agent-facing tools.
allowed-tools: read,write,bash,glob,grep
disable-model-invocation: true
---

# tyr-check — the judge — 10 principles + runtime gates

## Purpose

Tyr validates that Ymir tools, skills, and documentation follow the 10 Galdr design principles adapted for the Ymir Agent Operating System with TOON output format. Run this skill to ensure your changes maintain agent ergonomics and token efficiency.

Tyr is the Norse god of law and justice — he judges whether a tool is fit for agent consumption.

Tyr also judges the **runtime** and its **Galdr assets** for drift. Galdr is the master builder and maintainer (see `.agents/skills/galdr/SKILL.md`); Tyr is the one-handed judge that confirms what Galdr built matches what the plan, the code, and the assets claim. When code, plan, and asset disagree, that is a Tyr violation even if every test passes.

## Before You Start

Understand Ymir's architecture: AGENTS.md governs all agent behavior. docs/Architecture.md is the master blueprint. docs/append-only-log.md records all decisions. TOON output should be used for all compliance reports.

Run the gates as one command when you can:

```
bash .agents/skills/galdr/scripts/compliance-check.sh        # TOON output, exit 1 on any FAIL
python3 .agents/skills/galdr/scripts/toon-check.py <path>    # TOON blocks only
```

## The 10 Judgments of Tyr

### 1. Token-efficient output with TOON
Ymir tools should output in TOON (Token-Oriented Object Notation) format for ~40% token savings over equivalent JSON while remaining readable by agents. Convert to TOON at the output boundary — keep internal logic on JSON.

**Assess:** Does your tool/output use TOON format? Is token savings ~40% compared to JSON?
**Improve:** Convert stdout output to TOON format; maintain JSON for internal logic; measure token reduction versus JSON baseline.

### 2. Minimal default schemas
Every field in stdout costs tokens — multiplied by row count in collections. Default to the smallest schema that lets the agent decide what to do next: typically an identifier, a title, and a status.

**Assess:** Does your tool/output use minimal schemas (3-4 fields) rather than 10+?
**Improve:** Restrict to required fields only; add new fields only if essential; follow the "one change at a time" pattern.

### 3. Content truncation
Ymir's truncation convention (from append-only-log.md and daily logs):
- Always show total size: "(truncated, N chars total)"
- Never omit large fields entirely — include a truncated preview
- Use help hints: "Run `docs view <id> --full` to see complete content"
- Default truncation at 500 chars for previews

**Assess:** Does your output follow Ymir's truncation convention?
**Improve:** Use "(truncated, N chars total)" format; always show total size; add help hints for --full view; default to 500-char previews.

### 4. Pre-computed aggregates
Ymir includes aggregated counts in:
- Plan doc status tables (proposed → approved → in-progress → done counts)
- Appendix-only-log entry counts per realm
- Runes audit entry counts
- Talent/fleet registry counts (app_registry.json)

**Assess:** Does your tool/include pre-computed counts, or does it require follow-up calls?
**Improve:** Include total counts alongside page sizes; compute aggregates during creation; avoid requiring separate calls for "how many total".

### 5. Definitive empty states
Ymir's definitive empty states (from append-only-log.md):
- "0 closed tasks found in this repository" (ENTRY-006 format)
- Tenant separation notes when no tenants exist
- "No files found" in skill searches
- Empty state is always stated with context confirming the command succeeded

**Assess:** Does your output use Ymir's definitive empty state format?
**Improve:** Always state the zero with context confirming command success; never leave ambiguous empty output.

### 6. Structured errors & exit codes
Ymir error handling (from AGENTS.md and append-only-log.md):
- Errors recorded in append-only-log.md with status and directive
- Exit codes: success=0, user-blocked non-zero
- No interactive prompts — all operations via flags/instruction
- Structured error format: status + directive + files affected

**Assess:** Does your tool/error handling follow Ymir's patterns?
**Improve:** Record errors in append-only-log.md format; use defined exit codes; never prompt interactively; structure errors with status/directive/files.

### 7. Ambient context via session integrations
Ymir provides ambient context through:
- Session start: AGENTS.md loads, realm context verified
- Daily briefings at 07:00 written to svartalfaheim/<realm>/workspace/memory/daily/YYYY-MM-DD.md
- Runes audit provides append-only context of all actions
- Mimirsbrunn recall provides memory context before orchestration

**Assess:** Does your tool/skill provide ambient context at session start?
**Improve:** Load relevant context (AGENTS.md, realm env, active plans) before task execution; write to daily briefing on completion; recall Mimirsbrunn before orchestration.

### 8. Content first
Ymir's content-first approach:
- README.md shows live system map, not usage manual
- AGENTS.md is the root governance, not a "getting started" doc
- Plan docs in docs/plans/ are the source of truth
- Daily logs in workspace/memory/daily/ are the active context

**Assess:** Does your tool/show live data first, or help text first?
**Improve:** Show live system state (active plans, active tickets, realm status) as the default view; keep help/patterns as secondary references.

### 9. Contextual disclosure
Ymir's contextual disclosure patterns:
- After open item → suggest closing (e.g., "Run `tasks close <id>`")
- After empty list → suggest creating (e.g., "No plans found. ADD: docs/plans/21-company-houses.md")
- After list → suggest viewing (e.g., "View plan: docs/plans/25-ratatoskr-a2a.md")
- Suggestions use placeholders: <id>, <title>, not concrete values
- Guide discovery, not prescribed workflows

**Assess:** Does your output include contextual next-step suggestions?
**Improve:** After each output type (list, detail, error), add 1-2 relevant suggestions using Ymir's placeholder format; guide discovery without prescribing workflows.

### 10. Consistent way to get help
Ymir's help structure:
- AGENTS.md: root governance (the "help")
- --help always passes (per AGENTS.md law 8)
- Plan docs have --status, --priority filters
- Skills have SKILL.md with name + content required
- Version-awareness: tools should verify against current AGENTS.md version

**Assess:** Does your tool/provide consistent help access?
**Improve:** Always include help reference in output; reference AGENTS.md as the primary help; use --status/--priority filters where applicable; verify against current AGENTS.md version.

## The Runtime Judgments of Tyr (11–18)

These judge the Brokk distro runtime and its Galdr assets. Full detail and runnable checks
live in `.agents/skills/galdr/assets/runtime-compliance.md`.

### 11. Norse naming law
Every subsystem, component, and process is named for the figure whose role matches its work; the operator is the **Allfather**, never "Allfather"; no imported or Brokk term names a component. Flavor may season a line; it must never name a subsystem or leak into docs.
**Assess:** Does every new/changed component follow `galdr/assets/norse-naming.md`? Any imported term used as a name? Any stale legacy string in code or docs?
**Improve:** Rename to the role-matched figure; record the mapping; scrub stale legacy names from code and docs in the same pass.

### 12. Runtime syntax & format validity
All runtime shell scripts pass `bash -n`; all config/JSON parses; the smoke commands in each doc actually pass.
**Assess:** Run `bash -n` on every `bin/*.sh`; `python3 -m json.tool` (or `jq -e .`) on every JSON; execute the documented smoke checks.
**Improve:** Fix syntax/parse errors; add verification commands to the owning asset; never ship an unverified script.

### 13. Harness adapters fail-closed and documented
Each supported harness has a guide under `galdr/assets/harness-integration/`, an adapter on disk, a run/nudge tier, and a fail-closed dispatch (never launch on an unverified harness; a missing dependency is a blocker, not a silent fallback).
**Assess:** Does every supported harness have adapter + guide? Does the adapter fail closed? Is the tier accurate?
**Improve:** Add the missing guide/adapter; enforce verification before spawn; never guess a fallback.

### 14. Session lock bound to the live session
Gleipnir's lock is bound to the harness/session process via `BROKK_SESSION_PID`, not the short-lived digest helper; a lock-refused session is read-only.
**Assess:** Does the session open pass `BROKK_SESSION_PID`? Does `state/.lock` hold the live process? Does read-only mode gate all mutation?
**Improve:** Thread `BROKK_SESSION_PID` through the adapter; refuse mutation when the lock is not owned.

### 15. Turn-end guard inert until armed
Sýn's turn-end guard does nothing until the first successful arm writes `state/.supervision-armed`; after that it fires (exit 2) only when the watcher is missing or stale.
**Assess:** Does a fresh session avoid false turn-end prompts? Does it fire when supervision drops after arming?
**Improve:** Gate on the armed marker and the heartbeat staleness window; never fire before the first arm.

### 16. Production, no mocks
No examples, placeholders, or mock data in the shipped runtime; failures report a plain reason. (`.example` fixtures are permitted only as tracked templates, never loaded as runtime data.)
**Assess:** Grep the runtime for mock/stub/TODO/placeholder; confirm real `data/` and `config/` drive behavior.
**Improve:** Replace mocks with real implementations; fail honestly instead of faking.

### 17. Scheduled jobs are safe
Nornir jobs are idempotent and once-per-day date-guarded; the Huginn observer is strictly read-only over `~/Ymir` and `~/Brokk`; the Runes ledger is append-only with a chained checksum.
**Assess:** Does a job double-run in one minute? Does the observer write anywhere external? Is the ledger ever rewritten?
**Improve:** Add the date guard; make external access read-only; append, never rewrite.

### 18. Galdr assets complete and drift-free
The runtime change is reflected in the owning Galdr asset in the same pass; `galdr/assets/README.md` routes the task; code, plan, and asset agree. `tyr-check/assets/` mirrors `galdr/assets/`; Galdr's agent surface (`.agents/agents/galdr.md`) resolves to its skill.
**Assess:** Is there an asset for the changed subsystem? Does it match the code? Are the mirrored copies in sync? Does Galdr's agent symlink resolve? Does `assets/README.md` list it?
**Improve:** Write/update the asset now; reconcile plan vs code vs asset; re-mirror into `tyr-check/assets/`.

## Runtime compliance checklist

Run this against any runtime change (expected outputs and per-check commands are owned by
`.agents/skills/galdr/assets/runtime-compliance.md`):

```
[ ] bash -n clean on every bin/*.sh
[ ] every config/JSON parses
[ ] smoke evidence recorded for the touched chain
[ ] Norse naming valid (no imported names)
[ ] harness adapters fail closed; supported harnesses documented
[ ] session lock bound to BROKK_SESSION_PID
[ ] turn-end guard inert until armed
[ ] no mocks/examples/placeholders in the shipped runtime
[ ] Nornir jobs idempotent + date-guarded; observer read-only; Runes append-only
[ ] Galdr asset updated for the change; code = plan = asset
[ ] tyr-check/assets mirror in sync; Galdr agent symlink resolves
```

## Invocation

- opencode: /skill tyr-check
- Ymir harness: tyr-check skill
- One command: `bash .agents/skills/galdr/scripts/compliance-check.sh`

## Output

Compliance assessment per principle and per runtime gate, with "Assess" / "Improve" recommendations specific to Ymir's architecture and TOON output format. The script form emits a TOON `checks[N]{id,check,status,detail}` table and exits 1 on any FAIL.

## Files referenced

- Governance: `AGENTS.md`, `docs/Architecture.md`, `docs/append-only-log.md`, `docs/plans/*.md`
- Skills: `.agents/skills/*/SKILL.md`
- Scripts: `.agents/skills/galdr/scripts/compliance-check.sh`, `.agents/skills/galdr/scripts/toon-check.py`
- Galdr assets (also mirrored at `tyr-check/assets/`):
  - `galdr/assets/README.md` — routing table
  - `galdr/assets/principles.md` — the 10 principles (full doctrine)
  - `galdr/assets/build-method.md` — build/forge procedure
  - `galdr/assets/registry.md` — skills, tools, commands, profiles, aett
  - `galdr/assets/norse-naming.md` — naming law + component map
  - `galdr/assets/brokk-distro-runtime.md` — runtime spec
  - `galdr/assets/runtime-components.md` — component inventory
  - `galdr/assets/runtime-compliance.md` — runtime acceptance gates
  - `galdr/assets/harness-integration/` — per-harness adapters
  - `galdr/assets/porting-upstream-to-norse.md` — port methodology
  - `galdr/assets/eindri-orchestration.md` — worker orchestration
  - `galdr/assets/nornir-jobs.md` — scheduler, jobs, Runes
  - `galdr/assets/hlidskjalf-ui.md` — UI working guide
  - `galdr/assets/pi-boot-guide.md` — PI primary boot
