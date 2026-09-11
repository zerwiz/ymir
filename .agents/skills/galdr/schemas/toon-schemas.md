# Galdr Tool Schemas — TOON Output Formats

Galdr references these TOON (Token-Oriented Object Notation) schemas per tool type. All output converts to TOON at the output boundary; internal logic remains on JSON.

## 1. Factory Orchestrator Schema

```toon
factory:
  status: open|closed|in-progress
  phase: <phase-name>
  progress: integer 0-100
  next_action: string
  utgard_sandbox: boolean
  worktree: string
  phase_complete: boolean
```

**Usage**: Python factory scripts (`factory_*.py`) — status, phase, progress tracking, utgard sandbox flag, worktree branch, phase completion.

## 2. Brokk Crew Schema

```toon
crew:
  status: active|paused|completed
  agent_role: developer|marketer|researcher
  worktree: string
  utgard: boolean
  sandboxed: boolean
  session_id: string
```

**Usage**: Brokk Allfather communications — crew status, agent role, worktree branch, utgard flag, sandboxed flag, session identification.

## 3. Galdr Skill Generator Schema

```toon
skill:
  name: string Norse-skill-name
  category: feature|bug|infrastructure|compliance|system
  toon_output: boolean
  principles: [1,2,3,4,5,6,7,8,9,10]
  compliance_status: validated|pending
  eindri_role: developer|marketer|researcher|none
  utgard_sandbox: true
```

**Usage**: Galdr-crafter generated skills — skill name with Norse naming, category, TOON output flag, all 10 principles list, compliance status, Eindri role assignment, utgard sandbox flag.

## 4. Eindri Sub-Agent Profile Schemas

### Developer Profile
```toon
eindri:
  role: developer
  capabilities:
    - code_synthesis
    - refactoring
    - test_writing
    - cli_tools
    - package_management
  tools:
    - Yggdrasil
    - herder
    - hermes_runner
    - vector_db
    - supabase
  workspace_patterns:
    - development/
    - .agents/tools/
    - .agents/skills/
  security:
    runs_in_utgard: true
    utgard_network: none
    utgard_resource_caps: true
    yggdrasil_worktree: true
    sandboxed: true
```

**Usage**: Galdr compliance checking — verifying new skills are compatible with developer Eindri worker profiles.

### Marketer Profile
```toon
eindri:
  role: marketer
  capabilities:
    - content_creation
    - seo_optimization
    - social_copy
    - campaign_planning
    - market_research
  tools:
    - vector_db
    - supabase
    - hermes_runner
    - herder
    - Yggdrasil
  workspace_patterns:
    - marketing/
    - .agents/assets/templates/
    - .agents/skills/
  security:
    runs_in_utgard: true
    utgard_network: none
    utgard_resource_caps: true
    yggdrasil_worktree: true
    sandboxed: true
```

**Usage**: Galdr compliance checking — verifying new skills compatible with marketer Eindri worker profiles.

### Researcher Profile
```toon
eindri:
  role: researcher
  capabilities:
    - rag_search
    - web_search
    - analysis
    - summarization
    - entity_extraction
  tools:
    - vector_db
    - hermes_runner
    - herder
    - Yggdrasil
    - supabase
  workspace_patterns:
    - development/
    - .agents/memory/
    - .agents/assets/templates/
  security:
    runs_in_utgard: true
    utgard_network: none
    utgard_resource_caps: true
    yggdrasil_worktree: true
    sandboxed: true
```

**Usage**: Galdr compliance checking — verifying new skills compatible with researcher Eindri worker profiles.

## 5. Norse Aett Naming Schema

```toon
naming:
  aett: galdr|val|skyr|bifr|heimd|gjallar|mimir|yggd
  pattern: <aett>-<verb|noun|adjective>
  validity: follows_Norse_mythology_convention
  rejection_reason: if_not_following_aett_pattern
```

**Usage**: Galdr-crafter skill naming — ensuring new skill names follow the Norse aett pattern.

## 6. Session Integration Schema

```toon
session:
  hook: boolean (primary|secondary|none)
  hook_installed: boolean
  skill_loaded: boolean
  ambient_context: boolean
  context_richness: integer 1-10
  last_session_start: ISO8601-timestamp
```

**Usage**: Galdr skill integration tracking — whether primary session hook or secondary skill is loaded, ambient context richness score, last session start timestamp.

## 7. Compliance Gate Results Schema

```toon
compliance:
  toe_output_test: pass|fail (with token_savings_percentage)
  principle_compliance: pass|fail (per_principle)
  norse_name_validity: valid|invalid (with_aett_pattern)
  frame_integration: integrated|pending (with_skill_path)
  mimirsbrunn_observation: observed|pending (with_episode_id)
  eindri_compatibility: compatible|incompatible (with_profile_reference)
  utgard_sandbox: compliant|non-compliant (with_declarations)
```

**Usage**: Galdr-compliance checker output — all five gate results with detailed per-principle assessment.

## Conversion Rules

1. **JSON → TOON**: At output boundary only; internal logic remains JSON
2. **Token savings**: ~40% reduction versus equivalent JSON
3. **Minimal schemas**: Default to 3-4 fields, not 10+
4. **Empty states**: Always show total size "(truncated, N chars total)"
5. **Help hints**: Include "--full" escape hatch reference
6. **Error format**: Structured errors in TOON, never raw stack traces
7. **Exit codes**: 0 = success (including no-ops), 1 = error, 2 = usage error