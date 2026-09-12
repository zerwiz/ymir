# GUNGNIR — Core Operational Skills

Every reusable task becomes a scripted skill here. Skills are validated in Utgard
before registration, and every skill is named for the myth figure whose role
matches its work (Gungnir naming law).

## Registry (`.agents/skills/`)

```
skills[24]{skill,does}:
  "galdr-cli","agent-CLI ergonomics — the master builder/maintainer of the runtime"
  "tyr-check","the judge — galdr principles + runtime gates"
  "no-mistakes","the clean-PR gate — vendored engine skill: validate, push, PR, CI"
  "smidja-factory","the smithy — agent factory: roster, phases, envelopes, visualizer"
  "hvild-afk","away-mode — supervision of routine wakes and batched escalations"
  "saga-bearings","bearings — fleet status digest (/bearings) + recap (/ahoy)"
  "muninn-stow","memory — session-knowledge curation, routing, persistence"
  "jord-projects","projects — registry + delivery posture"
  "urdh-hold","hold lifecycle — decisions held for the Allfather, reconciled"
  "frigg-consent","consent — ask-user authority gate"
  "vor-diagnostics","diagnostics — bootstrap + diagnostic reasoning"
  "nornir-schedule","schedule — event sources + quota-aware dispatch"
  "nsr-compliance","compliance — NorthStar scaffold/audit + the .compliance/ harness"
  "gjallarhorn-relay","relay — public replies (X/Discord)"
  "eindri-homes","worker homes — provisioning and upkeep of Eindri homes"
  "syn-recovery","recovery — stuck-worker playbook"
  "ymir-host","host ops — self-update, Omarchy desktop, Þjazi backend"
  "herdr-panes","terminal panes — seat/control panes, tabs, workspaces, agents (HERDR_ENV=1)"
  "ratatoskr-a2a","A2A/MCP mesh — a2abridge + wayofteams; registration"
  "hlidskjalf-ui","control plane UI — SPA, gate API, auth, desktop, tunnel"
  "hamr-adapters","harness adapters — per-harness reference"
  "pr-ops","pull requests — create, update, check status, request merge"
  "hnoss-design","design — artifacts via OpenDesign (prototypes, decks, dashboards, image, video)"
  "bragi-marketing","marketing — research/crawl (Firecrawl), agentic browser (browser-use)"
```

Not adopted as standalone skills: `firstmate-coding-guidelines` (folded into Galdr),
`firstmate-orca` / `firstmate-codexapp` (backend reference docs only).

## Skill synthesis rules (Gungnir)

1. Gap identified → write the skill doc + script to `.agents/skills/<name>/`.
2. Validate inside an Utgard container.
3. Register it in this index.
4. **Norse-name every new skill** at synthesis: choose the figure whose role
   matches the work and let the skill inherit that name (`<figure>-<what>`).

Governance: `.agents/skills/galdr-cli/SKILL.md`; adopted-skill provenance is recorded in
`.agents/skills/galdr-cli/assets/reference-adoption.md`.
