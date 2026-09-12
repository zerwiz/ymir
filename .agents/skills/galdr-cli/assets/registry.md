# Galdr Registry — skills, tools, commands, profiles, schemas

The reference registries Galdr routes to when synthesizing or validating a skill.
Load this when the task is about skill synthesis, the tool inventory, OpenCode
commands, or compliance assets.

## Internal skills registry

```
skills[30]{name,norse,purpose,path,status}:
  "galdr","Galdr","AXI incantation standards + master builder/maintainer",".agents/skills/galdr-cli/SKILL.md","live"
  "tyr-check","Tyr","The judge — validates tools/skills/docs against the 10 principles",".agents/skills/tyr-check/SKILL.md","live"
  "smidja","Smíðja","The smithy — roster, phases, envelopes, trace",".agents/skills/smidja/AGENTS.md","live"
  "volundr","Völundr","The master smith — Smíðja orchestrator (Kaia's seat inside the factory)",".agents/skills/smidja/skills/volundr/SKILL.md","live"
  "smidja-launcher","Smíðja","One command to start/watch/audit/stop the smithy",".agents/skills/smidja/skills/smidja-launcher/SKILL.md","live"
  "smidja-instructions","Smíðja","Turn a vague request into a runnable request file",".agents/skills/smidja/skills/smidja-instructions/SKILL.md","live"
  "smidja-start","Smíðja","Start the smithy's agents for work (teams/models/chains)",".agents/skills/smidja/skills/smidja-start/SKILL.md","live"
  "how-to-run-agent-teams","—","Run a full agent team with the smithy",".agents/skills/smidja/skills/how-to-run-agent-teams/SKILL.md","live"
  "add-or-edit-ai-models","—","Tune model/prompt/injected context for agents",".agents/skills/smidja/skills/add-or-edit-ai-models/SKILL.md","live"
  "create-new-agent","—","Create a new agent role",".agents/skills/smidja/skills/create-new-agent/SKILL.md","live"
  "create-new-teams","—","Create a new smithy team (roster stack)",".agents/skills/smidja/skills/create-new-teams/SKILL.md","live"
  "git-ops","—","Branch creation, safe commits, sync upstream",".agents/skills/smidja/skills/git-ops/SKILL.md","live"
  "pr-ops","—","PR lifecycle — create, update, status, merge",".agents/skills/pr-ops/SKILL.md","live"
  "vog","Vog","Local-model operation (llama.cpp, LM Studio, Ollama): engines, wiring, honest measurement",".agents/skills/galdr-cli/assets/local-models.md","asset"
  "hamr","Hamr","Per-harness adapter reference",".agents/skills/hamr/AGENTS.md","live"
  "frigg-consent","Frigg","Consent / ask-user authority gate",".agents/skills/frigg-consent/AGENTS.md","live"
  "jord-projects","Jörð","Project registry + delivery posture",".agents/skills/jord-projects/AGENTS.md","live"
  "urdh","Urðr","Allfather-hold lifecycle: decisions held for the Allfather, reconciled",".agents/skills/urdh/SKILL.md","live"
  "nornir","Nornir","fate & schedule: process→event sources + quota-aware dispatch",".agents/skills/nornir/SKILL.md","live"
  "saga","Sága","session bearings (/bearings) + recap and unresolved decisions (/ahoy)",".agents/skills/saga/SKILL.md","live"
  "ymir","Ymir","self-update · Omarchy-native operation · the Þjazi backend",".agents/skills/ymir/SKILL.md","live"
  "vor-diagnostics","Vör","Bootstrap + diagnostic reasoning",".agents/skills/vor-diagnostics/AGENTS.md","live"
  "gjallarhorn-relay","Gjallarhorn","Public relay replies (X/Discord)",".agents/skills/gjallarhorn-relay/AGENTS.md","live"
  "eindri-homes","Eindri","Isolated worker homes (provisioning)",".agents/skills/eindri-homes/AGENTS.md","live"
  "syn-recovery","Sýn","Stuck-worker recovery playbook",".agents/skills/syn-recovery/AGENTS.md","live"
  "hvild-afk","Hvíld","Away-mode supervision",".agents/skills/hvild-afk/AGENTS.md","live"
  "muninn-stow","Muninn","Session-knowledge curation, routing, persistence",".agents/skills/muninn-stow/AGENTS.md","live"
  "open-design","—","OpenDesign CLI — prototypes, pages, dashboards, decks, video",".agents/skills/open-design/SKILL.md","live"
  "galdr-compliance","(legacy)","Older compliance checker — superseded by tyr-check",".agents/skills/galdr-cli/galdr-compliance/SKILL.md","legacy"
  "galdr-crafter","(legacy)","Older skill crafter — superseded by brokk-craft",".agents/skills/galdr-cli/galdr-crafter/SKILL.md","legacy"
```

**Loading:** Skills auto-load from `.agents/skills/` via `opencode.json` →
`skills.paths: [".agents/skills"]`. Use the `skill` tool: `skill galdr`,
`skill tyr-check`.

## The Einherjar — agent fleet

Eight specialists, one primary. Each is named for the figure whose role matches its work.

```
einherjar[8]{agent,norse,role,domain,file}:
  "Brokk","Brokk","Primary agent — forge-master, dispatcher, supervisor",".agents/agents/brokk.md",".agents/agents/brokk.md"
  "Sindri","Sindri (smith)","Code synthesis, refactoring, tests, CLI tools",".agents/agents/sindri-developer.md",".agents/agents/sindri-developer.md"
  "Bragi","Bragi (skald)","Marketing, content, SEO, social copy",".agents/agents/bragi-marketer.md",".agents/agents/bragi-marketer.md"
  "Huginn","Huginn (sage)","Research, web search, analysis, knowledge discovery",".agents/agents/huginn-researcher.md",".agents/agents/huginn-researcher.md"
  "Mimir","Mimir","Planner — memory, recall, architecture sequencing",".agents/agents/mimir-planner.md",".agents/agents/mimir-planner.md"
  "Kvasir","Kvasir (wisest)","Scout — reconnaissance, investigation",".agents/agents/kvasir-scout.md",".agents/agents/kvasir-scout.md"
  "Forseti","Forseti (reconciler)","Reviewer — QA, acceptance, compliance",".agents/agents/forseti-reviewer.md",".agents/agents/forseti-reviewer.md"
  "Snotra","Snotra (modest)","Documenter — docs, changelogs, runbooks",".agents/agents/snotra-documenter.md",".agents/agents/snotra-documenter.md"
```

**Rule:** Every agent carries its rune of introduction (Agent Card). Every agent
reports to Brokk. Brokk reports to the Allfather.

## Legacy sub-agent profiles (`.agents/subagents/*.md` — superseded)

These profiles were superseded by the Einherjar fleet above. They remain for
historical reference only.

```
eindri[3]{role,norse,domain,capabilities,tools,workspaces}:
  "developer","Sindri (smith)","code synthesis, refactoring, tests, CLI tools, packaging","code_synthesis, refactoring, test_writing, cli_tools, package_management","yggdrasil, herder, hermes_runner, vector_db, supabase","development/, .agents/tools/, .agents/skills/"
  "marketer","Bragi (skald)","content, SEO, social copy, campaigns","content_creation, seo_optimization, social_copy, campaign_planning, market_research","vector_db, supabase, hermes_runner, herder, yggdrasil","marketing/, .agents/assets/templates/, .agents/skills/"
  "researcher","Huginn (sage)","RAG, web search, analysis, knowledge discovery","rag_search, web_search, analysis, summarization, entity_extraction","vector_db, hermes_runner, herder, yggdrasil, supabase","development/, .agents/memory/, .agents/assets/templates/"
```

All three declare the Utgard security posture: `runs_in_utgard: true`,
`utgard_network: none`, `utgard_resource_caps: true`, `yggdrasil_worktree: true`,
`sandboxed: true`.

## Build tool categories (`.agents/skills/galdr-cli/assets/build-tool-categories.md`)

```
build_tools[4]{category,role}:
  "Python smidja tools","deterministic Python orchestrators in `templates/smidja/`"
  "smidja","validated OSS smidja (agents + typed JSON envelopes + SQLite trace + Vue visualizer)"
  "Agent-distro orchestration","validated upstream distro pattern (see porting asset)"
  "Galdr skill assets","internal reference data under `assets/`"
```

## TOON output schemas (`.agents/skills/galdr-cli/schemas/toon-schemas.md`)

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
  "mimir-","memory / wisdom","mimir-recall, mimirsbrunn"
  "yggd-","tree / worktree","yggdrasil, yggd-branch"
```

**Naming form:** `<aett>-<verb|noun|adjective>`, e.g. `mimir-recall`, `yggd-branch`.
The aett table lives in `SKILL.md:288-301` and `assets/norse-naming.md`; keep both
in sync when an aett gains its first real skill.

**Aett prefix rules:**
- `galdr-` is reserved for Galdr-family skills (incantation/chant standards)
- `val-` is for hall/health subsystems
- `skyr-` is for giant/file-scope tools
- `bifr-` is for bridge/gateway components
- `heimd-` is for gate/guard components
- `gjallar-` is for horn/signal components
- `mimir-` is for memory/wisdom components
- `yggd-` is for tree/worktree components

## Internal tools inventory

```
tools[9]{tool,path,purpose,status}:
  "tasks-cli",".agents/tools/bin/tasks-cli","AXI task manager (list/view/create/close), TOON output","live"
  "tasks-cli.ts",".agents/tools/tasks-cli.ts","TypeScript source","live"
  "agents-config.sh","bin/agents-config.sh","Show/apply the personal agent→model combination (config/agents.yaml)","live"
  "yggdrasil.ts",".agents/tools/yggdrasil.ts","Worktree CLI harness","planned"
  "hermes_runner.ts",".agents/tools/hermes_runner.ts","Realm agent CLI orchestrator","planned"
  "herder.ts",".agents/tools/herder.ts","Terminal multiplexer / pane state tracker","planned"
  "vector_db.ts",".agents/tools/vector_db.ts","Vector indexing / RAG search","planned"
  "firebase.ts",".agents/tools/firebase.ts","Backend provisioning","planned"
  "supabase.ts",".agents/tools/supabase.ts","DB / edge function setup","planned"
```

Usage: `python3 .agents/tools/bin/tasks-cli <command>`. All tools emit TOON.

## External tools (adopted, not rebuilt)

Ymir adopts validated OSS projects first — never rebuilds a subsystem that already
exists on this machine. These are the adopted tools, each wearing a Norse name:

| OSS Project | Norse Name | Purpose | Path |
|---|---|---|---|
| adopted upstream smithy (provenance: `command-factory`) | **Smíðja** | Deterministic agent pipeline + trace | `.agents/skills/smidja/` |
| `a2aproject/a2a` | **Ratatoskr** | Agent-to-agent collaboration | `.agents/bus/protocol.ts` |
| Redis | **Ratatoskr queue** | Pub/sub message queue | platform service |
| Traefik / Caddy | **Bifrost** | Reverse proxy / routing | platform service |
| OAuth2-proxy | **Heimdall** | Authentication guardian | platform service |
| cloudflared | **Gjallarhorn** | Cloudflare tunnel | platform service |
| MinIO / FileBrowser | **Skrymir** | File browser | platform service |
| PM2 / Docker | **Valhalla** | Process supervisor | platform service |
| MCP servers | **Hermóðr** | Tool composition | `.agents/skills/galdr-cli/assets/pi-boot/herdr-profile.toml` |
| — (Ymir-owned) | **Gungnir** | Dynamic skill creation | `.agents/skills/` |
| OpenDesign CLI | **Od** | Design engine (HTML/PDF/PPTX/video) | `od` CLI |
| Þjazi backend | **Þjazi** | Terminal pane presentation | `config/herdr-presentation-spaces` |
| llama.cpp router | **llama-swap** | Local model serving | `http://127.0.0.1:8080` |

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

## Memory (the Well — Mimirsbrunn / engram)

| Component | Path | Purpose |
|---|---|---|
| Store | `.agents/memory/kaia.engram` | single shared engram memory |
| Append log | `.agents/memory/well/episodes.jsonl` | raw episodes; re-seed source |
| HTTP bridge | `bin/mimir-bridge.py` / `.sh` | `:4602` recall/observe/recent/episode/timeline |
| CLI | `bin/mimir.sh` | health / recall / observe / timeline |
| Ingest | `bin/mimir-ingest.sh` | drink a directory into the well |
| MCP | `engram-mcp` | stdio tools: remember/recall/why/forget/stats |
| Gate API | `apps/hlidskjalf/server/index.ts` | `/api/well`, `/api/well/episode`, `/api/mimir/health` |
| UI | `gates/Well.tsx`, `components/RecallPanel.tsx` | live metrics + click-to-read |

Full spec: [`memory-well.md`](memory-well.md). Law: **no mock data in the well**.

## Smithy runtime (Smíðja)

| Component | Path / port | Purpose |
|---|---|---|
| Trace DB | `smidja/smidja_data/smidja.db` | sessions/phases/events/gates/envelopes/agent_sessions (WAL, read-only readers) |
| Roster / config | `smidja/smidja_smidja_config/smidja.config.yaml` | teams, roles, `provider/id` models resolved by **pi** (`~/.pi/agent/models.json`) |
| Run | `justfile` (`just demo/scout/sdlc`), `uv run smidja/smidja_*.py` | chains |
| Visualizer (**Smíðja's eye**) | `.agents/skills/smidja/apps/visualizer/`, served at **`:8437`** (API + built UI) | sessions / trace / decisions / stats / chat |
| Gate API | `apps/hlidskjalf/server/index.ts` → `/api/smidja/*` | read-only trace for the Hlidskjalf gates |
| Observer (**Huginn**) | `bin/nornir-job-observer.sh` | self-contained Runes lines, incl. `smidja.runs` |
| Start / stop | `scripts/start.sh` / `scripts/stop.sh` | raises/lowers SPA `:3888`, gate API `:3889`, visualizer `:8437`, Nornir cron, Bifrost bridge |

Full spec: [`smidja.md`](smidja.md). Lore: `docs/lore.md` §XI / §XIII.

## Maintaining this

- **Owner:** Brokk. **Router:** `.agents/skills/galdr-cli/SKILL.md`.
- **Mirror:** `.agents/skills/tyr-check/assets/registry.md`.
- Update a registry row whenever a skill, tool, command, or profile changes.

## Organisation law — `RULES/` (domains · houses · Eindri)

The house law lives in `RULES/`; Galdr must know it (Rule 01/02/03):

- **A house is a company** — and only that. **WayOf** is the house.
- **A domain is a field of knowledge — a *Grein* (pl. *Greinar*).** The eight:

| Domain (Grein) | id | Covers |
|---|---|---|
| Ymir Labs | `ymirlabs` | the system itself — agents knowledgeable about Ymir |
| Brokk Forge | `brokkforge` | engineering & build tooling |
| Runestone Labs | `runestone` | records & compliance |
| Muninn Labs | `muninn` | memory & knowledge |
| Dvalin | `dvalin` | crafted tools |
| Utgard Studios | `utgard` | creative |
| Askr | `askr` | human-centered products |
| Mannheim | `mannheim` | holding — allocated when a claim lands |

- **Eindri are the specialists** (marketer, builder, researcher, planner,
  reviewer, documenter, scout, …); each names its **domain** and its **craft**.
- **Agents live only in `.agents/agents/*.md`.** `.opencode/agent` and
  `.pi/agents` are **symlinks** to the canonical profiles — never edit them;
  edit `.agents/agents/<profile>.md` and run `bin/valknut-load.sh --all`.
- **No mock agents.** Ids, names, domains, models, status are real and sourced;
  the demo roster is the one labelled mock and appears only in demo mode.

**In the code:** the eight are `DOMAINS` (type `DomainId`/`DomainDef`) in
`src/data/realms.ts`; an agent carries `domain` (not `house`); the Forge picker
is labelled **Domain**. `svartalfaheim/<company>/companies/` holds the house
card(s); the eight domain cards live under `.../domains/`. The workspace-folder
union is `TopicId`.

## The personal agent/model combination — `config/agents.yaml`

The Allfather chooses **which smith runs on which model** in one YAML; no other
file hardcodes a model for him.

- **Source of truth:** `config/agents.yaml` — `default_model` (the fallback),
  `providers` (local, keyless servers), and `agents` (name → `provider/model`).
- **Applier:** `bin/agents-config.sh show` prints the live combination (TOON);
  `apply` writes `model:` into the canonical `.agents/agents/*.md` (matched by
  their `name:`) **and** into project `opencode.json` (`provider` + `agent.*`).
  It is idempotent and safe to re-run.
- **Local servers.** A local llama.cpp **router needs the exact served id** —
  including the quant suffix, e.g. `frontend-design-expert-8b@q4_k_m`; the bare
  alias returns `model not found`. Declared under `providers:` so `apply` places
  it in project `opencode.json`.
- **Current choice:** Hnoss the designer runs
  `llama.cpp/frontend-design-expert-8b@q4_k_m` on `127.0.0.1:8080` (no cloud
  key); the rest inherit `opencode-go/deepseek-v4.1-flash`.
- **Subagent caveat:** a `mode: subagent` profile (Hnoss) cannot be run with
  `opencode run --agent`; the lowercased model is taken from its profile when a
  primary dispatches it. A thin **primary** alias is the way to prove it end to
  end.
- **Template & privacy:** `config/agents.yaml.example` is tracked; installation
  (step `host`) or `bin/agents-config.sh init` copies it to the private,
  gitignored `config/agents.yaml` — push that to a private repo. Override its
  path with `YMIR_AGENTS_YAML`.
- **Harness rule:** the harness is chosen by where the model lives — a local
  provider runs through **`pi`**, a hosted model through **`opencode`** — unless
  an agent names `harness:`. The same server is renamed per harness
  (`llama.cpp` → `llama-cpp` for pi).
- **Updating this registry:** when a new provider or model is added to
  `config/agents.yaml`, add its id here and (if it is a new server) to the
  external-tools inventory.

## Hodd — the private hoard (Rule 04)

`hodd/` is the ONE private place: `secrets/ · docs/ · tenants/ · identity/`.
`hodd/.gitignore` tracks only itself, the README, and `*.example`; every other
file beneath is untracked on every clone. Secrets are **referenced by path**
(`YMIR_HOARD`; `bin/hodd.sh path|init|ls|load|emit|tenant`), never inlined. The
outer ward is `bin/secret-guard.sh` (pre-commit + CI). Law: `RULES/04-hoard.md`.

## Consolidated skills — galdr-style routers (2026-09-12)

Split pairs were merged into one `SKILL.md` router + `assets/` (a change edits an
asset, not a new skill). Same-figure split pairs only — merging distinct figures
is held pending the naming law.

consolidated[5]{skill,absorbed,assets}:
  "ymir","ymir-update + ymir-omarchy + ymir-thjazi","update · omarchy · thjazi"
  "urdh","urdh-decisions + urdh-hold","hold · decisions"
  "saga","saga-bearings + saga-recap","bearings · recap · board-template.html"
  "nornir","nornir-events + nornir-quota","events · quota"
  "nsr","NSR + NSRcompliance","nsr/ · nsrcompliance/"

**Ruling (2026-09-12):** `frigg-consent` + `hvild-afk` and `syn-recovery` +
`vor-diagnostics` stay **separate** — each names a distinct figure, and the
naming law keeps one figure per skill. Only same-figure split pairs consolidate.

## Operator runbooks — `docs/runbooks/` (indexed by the `ymir` skill)

Task-oriented, operator-facing guides. The `ymir` skill carries the index at
`assets/runbooks.md`; when a capability gains an operator procedure, add a
runbook here and a row there.

```
runbooks[5]{file,subject}:
  "models.md","models per agent (local llama.cpp / hosted); per-machine overlays"
  "agents.md","Eindri profiles: home, add, run, dispatch"
  "tailscale-sync.md","sync pi data across your machines over Tailscale"
  "updates-and-migrations.md","update the runtime; heal old homes"
  "secrets-and-hoard.md","Hodd: secrets, secret-guard, rotation + scrub"
```
