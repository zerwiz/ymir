# Registry — skills, assets, tools, commands (loaded from AGENTS.md)

AGENTS.md loads this when a task needs the live inventories.

## Skills registry (`.agents/skills/`)

```
skills[5]{name,norse,purpose,path,status}:
  "galdr","Galdr","agent-CLI ergonomics + master builder/maintainer",".agents/skills/galdr-cli/SKILL.md","live"
  "tyr-check","Tyr","the judge — 10 principles + runtime gates",".agents/skills/tyr-check/SKILL.md","live"
  "brokk-craft","Brokk","the forger — generates Galdr-compliant skills in TOON","(planned) .agents/skills/galdr-cli/brokk-craft/SKILL.md","planned"
  "galdr-compliance","(legacy)","older compliance checker — superseded by tyr-check",".agents/skills/galdr-cli/galdr-compliance/SKILL.md","legacy"
  "galdr-crafter","(legacy)","older skill crafter — superseded by brokk-craft",".agents/skills/galdr-cli/galdr-crafter/SKILL.md","legacy"
```

Loading: auto-load from `.agents/skills/` via `opencode.json` →
`skills.paths: [".agents/skills"]`. Use `skill galdr`, `skill tyr-check`.

## Galdr assets (`.agents/skills/galdr-cli/assets/`)

```
galdr_assets[6]{path,load_when}:
  "assets/README.md","the full asset routing index"
  "assets/principles.md","the 10 CLI design principles (full doctrine)"
  "assets/norse-naming.md","naming law + full component map"
  "assets/brokk-distro-runtime.md","the runtime spec (home, digest, lock, cron)"
  "assets/harness-integration/","per-harness adapters (opencode, pi, claude, cursor, codex)"
  "assets/runtime-compliance.md","runtime acceptance gates + runnable checklist"
```

Galdr scripts: `scripts/toon-check.py` (TOON validation) and
`scripts/compliance-check.sh` (all gates). Run the latter before claiming done.

## Assets inventory

```
assets[9]{asset,path,purpose}:
  "Eindri profiles",".agents/subagents/*.md","Sindri/Bragi/Huginn role profiles"
  "Build tool categories",".agents/skills/galdr-cli/assets/build-tool-categories.md","tool categories for synthesis"
  "TOON schemas",".agents/skills/galdr-cli/schemas/toon-schemas.md","schema types for validation"
  "Compliance requirements",".agents/skills/galdr-cli/assets/runtime-compliance.md","runtime + Utgard gates"
  "PI boot profile",".agents/skills/galdr-cli/assets/pi-boot/pi-profile.yml","PI harness profile"
  "PI herdr profile",".agents/skills/galdr-cli/assets/pi-boot/herdr-profile.toml","pane layout / Þjazi"
  "PI dispatch schema",".agents/skills/galdr-cli/assets/pi-boot/einherjar-spawn.schema.json","dispatch payload"
  "Templates",".agents/assets/templates/*","PRD, env, system-prompt boilerplate"
  "Tool manifest schema",".agents/assets/schemas/tool_manifest.json","tool manifest"
```

## Tools inventory (`.agents/tools/`)

```
tools[8]{tool,path,purpose,status}:
  "tasks-cli",".agents/tools/bin/tasks-cli","AXI task manager (list/view/create/close), TOON","live"
  "tasks-cli.ts",".agents/tools/tasks-cli.ts","TypeScript source","live"
  "yggdrasil.ts",".agents/tools/yggdrasil.ts","worktree CLI harness","planned"
  "hermes_runner.ts",".agents/tools/hermes_runner.ts","realm agent CLI orchestrator","planned"
  "herder.ts",".agents/tools/herder.ts","terminal multiplexer / pane state tracker","planned"
  "vector_db.ts",".agents/tools/vector_db.ts","vector indexing / RAG search","planned"
  "firebase.ts",".agents/tools/firebase.ts","backend provisioning","planned"
  "supabase.ts",".agents/tools/supabase.ts","DB / edge function setup","planned"
```

Usage: `python3 .agents/tools/bin/tasks-cli <command>`. All tools emit TOON.

## OpenCode commands

```
commands[8]{command,purpose}:
  "/create-plan","create detailed implementation plans iteratively"
  "/fixes-bump","bump version across project files"
  "/fixes-create","create fix note entry"
  "/implement-plan","implement approved plan phase-by-phase"
  "/rules","display/manage coding rules"
  "/standup","generate daily standup entries"
  "/ticket-create","interactive ticket creation"
  "/validate-plan","validate plan before implementation"
```

## Maintaining this

- **Owner:** Brokk. **Loaded by:** `AGENTS.md`. **Mirror:** `.agents/skills/galdr-cli/assets/registry.md`.
