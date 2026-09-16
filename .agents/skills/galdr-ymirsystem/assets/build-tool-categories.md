# Galdr Build Tool Categories

Galdr needs to understand these build tool categories and their asset requirements for proper skill synthesis and compliance checking.

## 1. Python Smíðja Tools

**Location**: `templates/smidja/` (deterministic Python scripts that own sequencing/retries/acceptance)

**Key Files**:
- `smidja_*.py` — Orchestrator scripts (smidja_simple_sdlc, smidja_orchestrate, etc.)
- `smidja_modules/data_types.py` — Pydantic v2 data types and data contracts
- `smidja_modules/tracer.py` — SQLite WAL + JSONL events for tracing
- `smidja_modules/quality.py` — Deterministic subprocess runs for quality gates
- `smidja_modules/permissions.py` — Path-based write enforcement
- `smidja_modules/agents.py` — Context handoff, sub-agent lane materialization (G2)
- `agent_pi.py` — Pi agent runtime
- `agent_opencode.py` — OpenCode agent runtime

**Assets Galdr Needs**:
- Tool schemas for smidja module data types
- Quality gate validation patterns
- Permission enforcement rules
- Context handoff format specifications
- Sub-agent task packet structures

## 2. Command-Smíðja (Reuse OSS)

**Validated OSS project**: `smidja` (disler-style "Smíðja")

**Features**:
- Deterministic Python owns graph, agents bounded nodes
- Typed JSON envelopes carry context
- Everything streams into SQLite for the polled visualizer
- Vue visualizer served at port 8437 (API + built UI; `apps/visualizer/`)

**Assets Galdr Needs**:
- Smíðja script patterns
- JSON envelope schemas
- SQLite telemetry structure
- Visualizer data format

## 3. Brokk Crew Orchestration

**External agent distro**: kunchenguid's Brokk

**Features**:
- One Allfather talks to first mate running autonomous coding agents
- Agents in tmux panes on git worktrees
- Project modes: no-mistakes/direct-PR/local-only/+yolo
- Crew orchestration, worktree isolation (Yggdrasil/orca)
- Restart-proof disk state, supervision watcher
- X/Discord Relay, eindri-homes

**Assets Galdr Needs**:
- Worktree isolation patterns
- tmux pane management schemas
- Restart-proof disk state format
- Supervision watcher patterns

## 4. Galdr Skill Assets (Internal)

**Location**: `.agents/skills/galdr-ymirsystem/assets/`

**Purpose**: Reference data for skill synthesis and compliance checking

**Contents**:
- Eindri sub-agent profiles (see eindri-profiles.md)
- Tool-specific TOON output schemas
- Norse naming aett patterns
- Utgard sandbox compliance checklists
- Session integration hooks

## Tool-Specific TOON Schemas

Galdr references these TOON output schemas per tool type:

### Smíðja Orchestrator (Python)
```toon
smidja:
  status: open|closed|in-progress
  phase: <phase-name>
  progress: 0-100
  next_action: <action-description>
  utgard_sandbox: true
  worktree: <branch-name>
```

### Brokk Allfather
```toon
crew:
  status: active|paused|completed
  agent_role: <developer|marketer|researcher>
  worktree: <branch-name>
  utgard: true
  sandboxed: true
```

### Galdr Skill Generator
```toon
skill:
  name: <norse-skill-name>
  category: <feature|bug|infrastructure|compliance|system>
  toon_output: true
  principles: [1,2,3,4,5,6,7,8,9,10]
  compliance_status: validated|pending
```

## Norse Aett Pattern Reference

All new Galdr skills follow this naming aett (family of eight):

| Aett Name | Pattern | Examples |
|-----------|---------|--------|
| **galdr-** | incantation / chant standards | `galdr`, `tyr-check` |
| **val-** | hall / health | `valhalla` (process monitor) |
| **skyr-** | giant / file scope | `skrymir` (file browser) |
| **bifr-** | bridge / gateway | `bifrost` (gateway/proxy) |
| **heimd-** | gate / guard | `heimdall` (auth/security) |
| **gjallar-** | horn / signal | `gjallarhorn` (cloudflared tunnel) |
| **mimir-** | memory / wisdom | (planned) |
| **yggd-** | tree / worktree | (planned) |

## Utgard Sandbox Compliance Checklist

Every Galdr-generated CLI tool must declare:

```
[runs_in_utgard: true]
[utgard_network: none]
[utgard_resource_caps: true]
[yggdrasil_worktree: true]
[sandboxed: true]
```

Failure to declare all five results in compliance gate rejection.

## Session Integration Hooks

Galdr references these hook patterns:

### Primary: Session Hook
- Installs/repairs after user intent is clear
- Provides compact dashboard as context at session start
- Loads on every session
- Works only in agents that support hooks

### Secondary: Installable Skill
- Loads on demand when agent recognizes matching task
- No per-session token cost
- Works in any agent that supports skill format
- Recommended: hook first, skill second (complementary)

### Hook Command Pattern
```
provide_explicit_setup_command that installs or repairs a session hook or plugin after user intent is clear
at_session_start the integration runs your tool and provides a compact dashboard as context
agent receives this as initial context and can act immediately
```

## Compliance Gate Asset References

| Asset File | Path | Purpose |
|------------|------|---------|
| Eindri profiles | `.agents/subagents/*.md` | Sub-agent role definitions |
| Tool schemas | `.agents/skills/galdr-ymirsystem/schemas/` | TOON output formats per tool |
| Workspace patterns | `.agents/skills/galdr-ymirsystem/assets/` | Workspace directory conventions |
| Aett pattern | `.agents/skills/galdr-ymirsystem/assets/` | Norse naming convention |
| Compliance requirements | `.agents/skills/galdr-ymirsystem/assets/compliance-requirements.md` | Five Utgard sandbox gates |

## Usage in Skill Synthesis

When a skill is forged, it:
1. References Eindri profiles from `.agents/subagents/*.md`
2. Assigns appropriate aett naming from the Norse pattern table
3. Generates TOON output schema based on tool category
4. Includes Utgard sandbox compliance declarations
5. Adds session integration hook recommendations
6. Validates against `tyr-check`'s principles checklist