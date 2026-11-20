# .agents/skills/ — __PROJECT__

Deterministic scripted automation layer. Zero ad-hoc shell commands — every operation runs through these skills.

## Structure

```
.agents/skills/
├── lifecycle/            # start.sh, stop.sh, status.sh, smoke_test.sh
├── git_ops/              # create_branch.sh, safe_commit.sh, sync_upstream.sh
├── features/             # <feature>/ (setup, test, smoke_test, rollback)
└── compliance/              # Embedded Agent Skill Compliance
```

## Rules

- Agents are forbidden from raw terminal commands.
- Scripts exit `0` on success, non-zero on failure.
- Each skill dir has a `SKILL.md` manifest.
- Every project ships the full skill set per `docs/project-skills.md`.