# GUNGNIR — Core Operational Skills

Every reusable task becomes a scripted skill here. Skills are validated in Utgard
before registration, and every skill is named for the myth figure whose role
matches its work (Gungnir naming law).

## Registry (`.agents/skills/`)

```
skills[23]{skill,does}:
  "galdr","agent-CLI ergonomics + master builder/maintainer of the runtime"
  "tyr-check","the judge — 10 principles + runtime gates"
  "smidja","the smithy (roster + phases + envelopes)"
  "hvild-afk","away-mode supervision (routine wakes self-handled, batched escalations)"
  "saga","session bearings: fleet status digest (/bearings) + recap & unresolved decisions (/ahoy)"
  "muninn-stow","session-knowledge curation, routing, and persistence"
  "jord-projects","project registry + delivery posture"
  "urdh","Allfather-hold lifecycle: decisions held for the Allfather, reconciled"
  "frigg-consent","consent / ask-user authority gate"
  "vor-diagnostics","bootstrap + diagnostic reasoning"
  "nornir","fate & schedule: process→event sources (events) + quota-aware dispatch (quota)"
  "nsr","WayOfNorthStarRules: scaffold/audit a repo + generate & run the deterministic .compliance/ harness"
  "gjallarhorn-relay","public relay replies (X/Discord)"
  "eindri-homes","isolated worker homes (provisioning)"
  "syn-recovery","stuck-worker recovery playbook"
  "ymir","operate the host: self-update · Omarchy desktop · Þjazi backend"
  "herdr","the pane backend — seat/control panes, tabs, workspaces, agents (HERDR_ENV=1)"
  "ratatoskr","the A2A/MCP mesh: a2abridge + wayofteams; registration"
  "hlidskjalf","the control plane UI: SPA · gate API · auth · desktop · tunnel"
  "hamr","per-harness adapter reference"
  "pr-ops","PR lifecycle — create, update, check status, request merge"
  "hnoss","design artifacts via the OpenDesign engine (prototypes, decks, dashboards, image, video)"
  "bragi","marketing — research/crawl with Firecrawl, agentic browser with browser-use"
```

Not adopted as standalone skills: `firstmate-coding-guidelines` (folded into Galdr),
`firstmate-orca` / `firstmate-codexapp` (backend reference docs only).

## Skill synthesis rules (Gungnir)

1. Gap identified → write the skill doc + script to `.agents/skills/<name>/`.
2. Validate inside an Utgard container.
3. Register it in this index.
4. **Norse-name every new skill** at synthesis: choose the figure whose role
   matches the work and let the skill inherit that name (`<figure>-<what>`).

Governance: `.agents/skills/galdr/SKILL.md`; adopted-skill provenance is recorded in
`.agents/skills/galdr/assets/reference-adoption.md`.
