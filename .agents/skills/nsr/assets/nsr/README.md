# NSR Skill

Scaffold + validate Way-Of NorthStar compliant projects.

## Layout

```
NSR/
├── SKILL.md           # Skill manifest (agent-facing workflow)
├── README.md          # This file
├── assets/            # Project templates (the source of truth for a new repo)
│   ├── root/          # Root routing files (AGENTS.md, STRUCTURE.md, ...)
│   ├── RULES/         # Execution rules (kept at root)
│   ├── docs/          # Granular docs tree (BEST_PRACTICES, CI_CD, DEVELOPER_SETUP, HOSTING, RUNBOOK, features, research)
│   ├── agents_skills/ # .agents/skills/ automation layer templates
│   └── compliance/       # .compliance/ deterministic harness templates
└── scripts/
    ├── scaffold.sh    # Create OR convert a project to the NSR layout
    └── validate.sh    # Audit a repo against NSR compliance gates
```

## Quick Start

```bash
# New project
.agents/skills/NSR/scripts/scaffold.sh ./my-project --name MyProject --description "SaaS thing"

# Existing repo (adds missing NSR pieces, never overwrites)
.agents/skills/NSR/scripts/scaffold.sh . --name "Existing" --description "Adopting NSR"

# Audit
.agents/skills/NSR/scripts/validate.sh ./my-project
```

## Rules

- Templates are generic; the scaffolder substitutes project name/description.
- Never overwrite an existing file during conversion.
- The scaffolder's post-condition is a passing `validate.sh`.
- Keep this skill in sync with `WayOfNorthstarRules.md`.