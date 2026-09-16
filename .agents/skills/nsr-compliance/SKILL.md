---
name: nsr
description: >-
  WayOfNorthStarRules — the doctrine and its deterministic gate. Load when
  creating a new NSR-compliant project, converting a legacy repo to the
  NorthStar layout, auditing a repo for NSR compliance, generating the
  .compliance/ harness, or running its gates (danger, wiring, env, paths).
  One skill for the NorthStar law.
allowed-tools: run_shell_command, run_bash_command, edit, write
metadata:
  internal: true
---

# nsr-compliance — compliance — NorthStar scaffold/audit + the .compliance/ harness

The NorthStar doctrine and the compliance harness that enforces it, under one
skill.

```
assets[2]{path,load_when}:
  "assets/nsr/scaffold-spec.md","scaffold a new NSR repo · convert a legacy repo · audit compliance (master spec, templates, scripts)"
  "assets/nsrcompliance/SKILL.md","generate and run the .compliance/ harness: danger, wiring, env, path gates + telemetry"
```

Stamp the harness into a repo:

```bash
.agents/skills/nsr/assets/nsrcompliance/generate.sh [TARGET] [--force] [--dry-run]
```
