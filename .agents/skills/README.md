# GUNGNIR — Core Operational Skills

Every reusable task becomes a scripted skill here. Skills are validated in Utgard
before registration, and every skill is named for the myth figure whose role
matches its work (Gungnir naming law).

## Registry (`.agents/skills/`)

```
skills[20]{name,norse,purpose,origin}:
  "galdr","Galdr","agent-CLI ergonomics + master builder/maintainer of the runtime","core"
  "tyr-check","Tyr","the judge — 10 principles + runtime gates","core"
  "smidja","Smiðja","the smithy (roster + phases + envelopes)","core"
  "modeltesting","—","model evaluation harness","core"
  "hvild-afk","Hvíld","away-mode supervision (routine wakes self-handled, batched escalations)","adopted"
  "saga","Sága","session bearings: fleet status digest (/bearings) + recap & unresolved decisions (/ahoy)","adopted"
  "muninn-stow","Muninn","session-knowledge curation, routing, and persistence","adopted"
  "jord-projects","Jörð","project registry + delivery posture","adopted"
  "urdh","Urðr","Allfather-hold lifecycle: decisions held for the Allfather, reconciled","adopted"
  "frigg-consent","Frigg","consent / ask-user authority gate","adopted"
  "vor-diagnostics","Vör","bootstrap + diagnostic reasoning","adopted"
  "nornir","Nornir","fate & schedule: process→event sources (events) + quota-aware dispatch (quota)","adopted"
  "gjallarhorn-relay","Gjallarhorn","public relay replies (X/Discord)","adopted"
  "eindri-homes","Eindri","isolated worker homes (provisioning)","adopted"
  "syn-recovery","Sýn","stuck-worker recovery playbook","adopted"
  "ymir","Ymir","operate the host: self-update · Omarchy desktop · Þjazi backend","new"
  "hamr","Hamr","per-harness adapter reference","adopted"
  "pr-ops","—","PR lifecycle — create, update, check status, request merge","new"
  "hnoss","Hnoss","design artifacts via the OpenDesign engine (prototypes, decks, dashboards, image, video)","new"
  "bragi","Bragi","marketing — research/crawl with Firecrawl, agentic browser with browser-use","new"
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
