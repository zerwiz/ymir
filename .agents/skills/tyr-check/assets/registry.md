# Galdr Registry — skills, tools, commands, profiles, schemas

The reference registries Galdr routes to when synthesizing or validating a skill.
Load this when the task is about skill synthesis, the tool inventory, OpenCode
commands, or compliance assets.

## Internal skills registry

```
skills[5]{name,norse,purpose,path,status}:
  "galdr","Galdr","AXI incantation standards + master builder/maintainer",".agents/skills/galdr/SKILL.md","live"
  "tyr-check","Tyr","The judge — validates tools/skills/docs against the 10 principles",".agents/skills/tyr-check/SKILL.md","live"
  "brokk-craft","Brokk","The forger — generates new Galdr-compliant skills in TOON","(planned) `.agents/skills/galdr/brokk-craft/SKILL.md`","planned"
  "galdr-compliance","(legacy)","Older compliance checker — superseded by tyr-check",".agents/skills/galdr/galdr-compliance/SKILL.md","legacy"
  "galdr-crafter","(legacy)","Older skill crafter — superseded by brokk-craft",".agents/skills/galdr/galdr-crafter/SKILL.md","legacy"
```

**Loading:** Skills auto-load from `.agents/skills/` via `opencode.json` →
`skills.paths: [".agents/skills"]`. Use the `skill` tool: `skill galdr`,
`skill tyr-check`.

## Eindri sub-agent profiles (`.agents/subagents/*.md`)

```
eindri[3]{role,norse,domain,capabilities,tools,workspaces}:
  "developer","Sindri (smith)","code synthesis, refactoring, tests, CLI tools, packaging","code_synthesis, refactoring, test_writing, cli_tools, package_management","yggdrasil, herder, hermes_runner, vector_db, supabase","development/, .agents/tools/, .agents/skills/"
  "marketer","Bragi (skald)","content, SEO, social copy, campaigns","content_creation, seo_optimization, social_copy, campaign_planning, market_research","vector_db, supabase, hermes_runner, herder, yggdrasil","marketing/, .agents/assets/templates/, .agents/skills/"
  "researcher","Huginn (sage)","RAG, web search, analysis, knowledge discovery","rag_search, web_search, analysis, summarization, entity_extraction","vector_db, hermes_runner, herder, yggdrasil, supabase","development/, .agents/memory/, .agents/assets/templates/"
```

All three declare the Utgard security posture: `runs_in_utgard: true`,
`utgard_network: none`, `utgard_resource_caps: true`, `yggdrasil_worktree: true`,
`sandboxed: true`.

## Build tool categories (`.agents/skills/galdr/assets/build-tool-categories.md`)

```
build_tools[4]{category,role}:
  "Python smidja tools","deterministic Python orchestrators in `templates/smidja/`"
  "smidja","validated OSS smidja (agents + typed JSON envelopes + SQLite trace + Vue visualizer)"
  "Agent-distro orchestration","validated upstream distro pattern (see porting asset)"
  "Galdr skill assets","internal reference data under `assets/`"
```

## TOON output schemas (`.agents/skills/galdr/schemas/toon-schemas.md`)

```
schemas[7]{schema,fields}:
  "Smíðja orchestrator","status, phase, progress, next_action, utgard_sandbox, worktree, phase_complete"
  "Worker orchestration","status, agent_role, worktree, utgard, sandboxed, session_id"
  "Galdr skill generator","name, category, toon_output, principles, compliance_status, eindri_role, utgard_sandbox"
  "Eindri profile","capabilities, tools, workspace_patterns, security"
  "Norse aett naming","aett pattern, validity, rejection reasons"
  "Session integration","hook, installed, skill_loaded, ambient_context, context_richness, last_session_start"
  "Compliance gate results","toon_output_test, principle_compliance, norse_name_validity, frame_integration, mimirsbrunn_observation, eindri_compatibility, utgard_sandbox"
```

## Norse aett pattern

```
aett[8]{prefix,pattern,examples}:
  "galdr-","incantation / chant standards","galdr, galdr-compliance, galdr-crafter"
  "val-","hall / health","valhalla"
  "skyr-","giant / file scope","skrymir"
  "bifr-","bridge / gateway","bifrost"
  "heimd-","gate / guard","heimdall"
  "gjallar-","horn / signal","gjallarhorn"
  "mimir-","memory / wisdom","(planned)"
  "yggd-","tree / worktree","(planned)"
```

## Internal tools inventory

```
tools[8]{tool,path,purpose,status}:
  "tasks-cli",".agents/tools/bin/tasks-cli","AXI task manager (list/view/create/close), TOON output","live"
  "tasks-cli.ts",".agents/tools/tasks-cli.ts","TypeScript source","live"
  "yggdrasil.ts",".agents/tools/yggdrasil.ts","Worktree CLI harness","planned"
  "hermes_runner.ts",".agents/tools/hermes_runner.ts","Realm agent CLI orchestrator","planned"
  "herder.ts",".agents/tools/herder.ts","Terminal multiplexer / pane state tracker","planned"
  "vector_db.ts",".agents/tools/vector_db.ts","Vector indexing / RAG search","planned"
  "firebase.ts",".agents/tools/firebase.ts","Backend provisioning","planned"
  "supabase.ts",".agents/tools/supabase.ts","DB / edge function setup","planned"
```

Usage: `python3 .agents/tools/bin/tasks-cli <command>`. All tools emit TOON.

## OpenCode commands

Available as `/command-name` in OpenCode:

```
commands[8]{command,purpose}:
  "create-plan","Create detailed implementation plans iteratively"
  "fixes-bump","Bump version across project files"
  "fixes-create","Create fix note entry"
  "implement-plan","Implement approved plan phase-by-phase"
  "rules","Display/manage coding rules"
  "standup","Generate daily standup entries"
  "ticket-create","Interactive ticket creation"
  "validate-plan","Validate plan before implementation"
```

## Session integration hooks

- **Primary — session hook**: installs/repairs after user intent is clear, provides a
  compact dashboard as context at session start, loads every session, works only in
  agents that support hooks.
- **Secondary — installable skill**: loads on demand when the agent recognizes a
  matching task, no per-session token cost, works in any agent that supports the
  skill format.
- Recommended order: hook first (ambient context + live state), skill second (lower
  overhead, broader support). They are complementary; install either or both.

## Utgard sandbox compliance checklist

Every Galdr-generated CLI tool must declare:

```
[runs_in_utgard: true]
[utgard_network: none]
[utgard_resource_caps: true]
[yggdrasil_worktree: true]
[sandboxed: true]
```

Failure to declare all five results in compliance-gate rejection.

## Maintaining this

- **Owner:** Brokk. **Router:** `.agents/skills/galdr/SKILL.md`.
- **Mirror:** `.agents/skills/tyr-check/assets/registry.md`.
- Update a registry row whenever a skill, tool, command, or profile changes.
