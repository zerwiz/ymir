# Galdr Assets — Build Tools & Worker References

This directory contains the assets that Galdr needs to understand about different build tools and their requirements, including worker profiles and tool-specific configurations.

## The Einherjar — Agent Fleet

Eight specialists, one primary. Each is named for the figure whose role matches its work.

| Agent | Norse | Role | Domain | File |
|-------|-------|------|--------|------|
| **Brokk** | Brokk | Primary agent — forge-master, dispatcher, supervisor | All | `.agents/agents/brokk.md` |
| **Sindri** | Sindri (smith) | Code synthesis, refactoring, tests, CLI tools | Development | `.agents/agents/sindri-developer.md` |
| **Bragi** | Bragi (skald) | Marketing, content, SEO, social copy | Marketing | `.agents/agents/bragi-marketer.md` |
| **Huginn** | Huginn (sage) | Research, web search, analysis, knowledge discovery | Research | `.agents/agents/huginn-researcher.md` |
| **Mimir** | Mimir | Planner — memory, recall, architecture sequencing | Planning | `.agents/agents/mimir-planner.md` |
| **Kvasir** | Kvasir (wisest) | Scout — reconnaissance, investigation | Scout | `.agents/agents/kvasir-scout.md` |
| **Forseti** | Forseti (reconciler) | Reviewer — QA, acceptance, compliance | Review | `.agents/agents/forseti-reviewer.md` |
| **Snotra** | Snotra (modest) | Documenter — docs, changelogs, runbooks | Docs | `.agents/agents/snotra-documenter.md` |

**Rule:** Every agent carries its rune of introduction (Agent Card). Every agent
reports to Brokk. Brokk reports to the Allfather.

## Legacy Sub-Agent Profiles (`.agents/subagents/*.md` — superseded)

These profiles were superseded by the Einherjar fleet above. They remain for
historical reference only.

Each worker operates inside Utgard containers on Yggdrasil worktrees with specific specializations:

### developer (`.agents/subagents/developer.md`)
- **Role**: Code synthesis, refactoring, test writing, CLI tools, package management
- **Capabilities**: code_synthesis, refactoring, test_writing, cli_tools, package_management
- **Tools**: yggdrasil, herder, hermes_runner, vector_db, supabase
- **Workspace patterns**: development/, .agents/tools/, .agents/skills/
- **Security**: runs_in_utgard: true, utgard_network: none, utgard_resource_caps: true, yggdrasil_worktree: true, sandboxed: true

### marketer (`.agents/subagents/marketer.md`)
- **Role**: Content creation, SEO, social copy, marketing campaigns
- **Capabilities**: content_creation, seo_optimization, social_copy, campaign_planning, market_research
- **Tools**: vector_db, supabase, hermes_runner, herder, yggdrasil
- **Workspace patterns**: marketing/, .agents/assets/templates/, .agents/skills/
- **Security**: runs_in_utgard: true, utgard_network: none, utgard_resource_caps: true, yggdrasil_worktree: true, sandboxed: true

### researcher (`.agents/subagents/researcher.md`)
- **Role**: RAG, web search, analysis, knowledge discovery
- **Capabilities**: rag_search, web_search, analysis, summarization, entity_extraction
- **Tools**: vector_db, hermes_runner, herder, yggdrasil, supabase
- **Workspace patterns**: development/, .agents/memory/, .agents/assets/templates/
- **Security**: runs_in_utgard: true, utgard_network: none, utgard_resource_caps: true, yggdrasil_worktree: true, sandboxed: true

## Build Tool Categories

Galdr needs to know about these build tool categories and their asset requirements:

### 1. Python Smíðja Tools
- **Location**: `templates/smidja/` (deterministic Python scripts)
- **Key files**: `smidja_*.py` orchestrator scripts, `smidja_modules/*.py`
- **Data contracts**: Pydantic v2 data types in `smidja_modules/data_types.py`
- **Agent runtime**: `agent_pi.py` (Pi), `agent_opencode.py` (opencode)
- **Tracing**: SQLite WAL + JSONL events in `smidja_modules/tracer.py`
- **Quality gates**: Deterministic subprocess runs in `smidja_modules/quality.py`
- **Permissions**: Path-based write enforcement in `smidja_modules/permissions.py`
- **Context handoff**: File-based `context_handoff/` dir in `smidja_modules/agents.py`
- **Sub-agents**: Task-tool lane materialization (G2) in `smidja_modules/agents.py`

### 2. Command-Smíðja (Skill-based)
- **Location**: Reuse `smidja` validated OSS project
- **Features**: Smíðja: deterministic Python owns graph, agents bounded nodes, typed JSON envelopes, SQLite telemetry, Vue visualizer (`apps/visualizer/`, served at port 8437)
- **Assets**: Smíðja scripts, roster/config, visualizer

### 3. Brokk Crew Orchestration
- **Location**: External agent distro by kunchenguid
- **Features**: One Allfather talks to first mate running autonomous coding agents in tmux panes on git worktrees
- **Project modes**: no-mistakes/direct-PR/local-only/+yolo
- **Assets**: Crew orchestration, worktree isolation (yggdrasil/orca), restart-proof disk state, supervision watcher, X/Discord Relay, secondmates

### 4. Galdr Skill Assets
- **Location**: `.agents/skills/galdr/assets/`
- **Purpose**: Reference data for skill synthesis and compliance checking
- **Contents**: Tool schemas, template patterns, Eindri profile references

## Tool-Specific Asset Requirements

### TOON Output Format
- All Galdr-generated CLI tools must output in TOON (Token-Oriented Object Notation) format
- ~40% token savings over equivalent JSON
- Convert to TOON at the output boundary — keep internal logic on JSON
- Minimal default schemas: 3-4 fields per list item, not 10+

### Norse Naming Convention
- All new skills must follow Norse mythology naming (aett pattern)
- galdr aett: incantation / chant standards
- Examples: galdr, galdr-compliance, galdr-crafter, valhalla, skrymir, bifrost, heimdall

### Utgard Sandbox Requirements
- All agent-facing tools must specify: runs_in_utgard: true
- Network: utgard_network: none (no network access)
- Resource caps: utgard_resource_caps: true
- Worktree integration: yggdrasil_worktree: true
- Sandboxed execution: sandboxed: true

### Session Integration
- Primary: session hook (installs/plugin after user intent is clear)
- Secondary: installable Agent Skill (loads on demand, no per-session token cost)
- Recommended: hook first (ambient context plus live state), skill second (lower overhead, broader support)

## Compliance Gates

Before a new Galdr skill is considered "forged", it must pass:

1. **TOON output test** — all stdout output uses TOON format, measured ~40% smaller than equivalent JSON across 3 sample outputs
2. **Principle compliance** — all 10 design principles assessed via galdr-compliance
3. **Norse name validity** — skill name follows the aett pattern, not a random label
4. **Frame integration** — SKILL.md placed in `.agents/skills/<name>/`, referenced in `.agents/skills/README.md`
5. **Mimirsbrunn observation** — the skill's creation is observed into the well (`POST /observe`) before it is deemed "live"
6. **Eindri worker compatibility** — skill declares workspace patterns compatible with Eindri sub-agent profiles
7. **Utgard sandbox validation** — skill specifies: runs_in_utgard: true, utgard_network: none, utgard_resource_caps: true, yggdrasil_worktree: true, sandboxed: true

## Asset Reference Files

| File | Purpose | Reference |
|------|---------|-----------|
| `eindri-profiles.md` | Eindri sub-agent role profiles | `.agents/subagents/` |
| `build-tool-categories.md` | Build tool category definitions | This file |
| `tool-schemas/` | JSON/TON schemas for different tool types | `tool-schemas/` directory |
| `workspace-patterns.md` | Workspace pattern conventions | `workspace-patterns.md` |
| `compliance-requirements.md` | Compliance gate requirements | `compliance-requirements.md` |

## Usage

Galdr references these assets when:
- Synthesizing new skills via `galdr-crafter`
- Validating existing skills via `galdr-compliance`
- Ensuring new CLI tools adhere to Ymir ergonomic standards
- Maintaining Norse naming convention and aett pattern consistency
- Verifying Utgard sandbox compliance for all agent-facing tools