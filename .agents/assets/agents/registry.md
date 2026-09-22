# Registry — skills, assets, tools, commands (loaded from AGENTS.md)

AGENTS.md loads this when a task needs the live inventories.

## Skills registry (`.agents/skills/`)

```
skills[4]{name,norse,purpose,path,status}:
  "galdr","Galdr","agent-CLI ergonomics + master builder/maintainer",".agents/skills/galdr-ymirsystem/SKILL.md","live"
  "tyr-check","Tyr","the judge — 10 principles + runtime gates",".agents/skills/tyr-check/SKILL.md","live"
  "brokk-craft","Brokk","the forger — generates Galdr-compliant skills in TOON","(planned) .agents/skills/brokk-craft/SKILL.md","planned"
  "elder-home","Reginn (the Elder)","the keeper — home records: plans ledger, docs, memory",".agents/skills/elder-home/SKILL.md","live"
```

The **canonical, complete** skill index is `.agents/skills/README.md` — read it for
the live set. The two removed legacy skills (`galdr-compliance`, `galdr-crafter`)
are superseded by `tyr-check` and the planned `brokk-craft`; their files are gone.

Loading: auto-load from `.agents/skills/` via `opencode.json` →
`skills.paths: [".agents/skills"]`. Use `skill galdr`, `skill tyr-check`.

## Galdr assets (`.agents/skills/galdr-ymirsystem/assets/`)

```
galdr_assets[6]{path,load_when}:
  "assets/README.md","the full asset routing index"
  "assets/principles.md","the 10 CLI design principles (full doctrine)"
  "assets/norse-naming.md","naming law + full component map"
  "assets/brokk-distro-runtime.md","the runtime spec (home, digest, lock, cron)"
  "assets/harness-integration/","per-harness adapters (opencode, pi, claude, cursor, codex)"
  "assets/runtime-compliance.md","runtime acceptance gates + runnable checklist"
```

Galdr scripts: `scripts/toon-check.py` (TOON validation) and
`scripts/compliance-check.sh` (all gates). Run the latter before claiming done.

## Assets inventory

```
assets[9]{asset,path,purpose}:
  "Eindri profiles",".agents/subagents/*.md","Sindri/Bragi/Huginn role profiles"
  "Build tool categories",".agents/skills/galdr-ymirsystem/assets/build-tool-categories.md","tool categories for synthesis"
  "TOON schemas",".agents/skills/galdr-ymirsystem/schemas/toon-schemas.md","schema types for validation"
  "Compliance requirements",".agents/skills/galdr-ymirsystem/assets/runtime-compliance.md","runtime + Utgard gates"
  "PI boot profile",".agents/skills/galdr-ymirsystem/assets/pi-boot/pi-profile.yml","PI harness profile"
  "PI herdr profile",".agents/skills/galdr-ymirsystem/assets/pi-boot/herdr-profile.toml","pane layout / Þjazi"
  "PI dispatch schema",".agents/skills/galdr-ymirsystem/assets/pi-boot/einherjar-spawn.schema.json","dispatch payload"
  "Templates",".agents/assets/templates/*","PRD, env, system-prompt boilerplate"
  "Tool manifest schema",".agents/assets/schemas/tool_manifest.json","tool manifest"
```

## Tools inventory (`.agents/tools/`)

```
tools[8]{tool,path,purpose,status}:
  "tasks-cli",".agents/tools/bin/tasks-cli","AXI task manager (list/view/create/close), TOON","live"
  "tasks-cli.ts",".agents/tools/tasks-cli.ts","TypeScript source","live"
  "yggdrasil.ts",".agents/tools/yggdrasil.ts","worktree CLI harness","planned"
  "hermes_runner.ts",".agents/tools/hermes_runner.ts","realm agent CLI orchestrator","planned"
  "herder.ts",".agents/tools/herder.ts","terminal multiplexer / pane state tracker","planned"
  "vector_db.ts",".agents/tools/vector_db.ts","vector indexing / RAG search","planned"
  "firebase.ts",".agents/tools/firebase.ts","backend provisioning","planned"
  "supabase.ts",".agents/tools/supabase.ts","DB / edge function setup","planned"
```

Usage: `python3 .agents/tools/bin/tasks-cli <command>`. All tools emit TOON.

## OpenCode commands

```
commands[8]{command,purpose}:
  "/create-plan","create detailed implementation plans iteratively"
  "/fixes-bump","bump version across project files"
  "/fixes-create","create fix note entry"
  "/implement-plan","implement approved plan phase-by-phase"
  "/rules","display/manage coding rules"
  "/standup","generate daily standup entries"
  "/ticket-create","interactive ticket creation"
  "/validate-plan","validate plan before implementation"
```

## Brokk commands — the Eindri wake bridge (control)

```
commands[4]{command,purpose}:
  "bin/eindri-watch.sh","the bridge's door: arm/retire/list/reconcile a when-source per smith (Norns' loom)"
  "bin/eindri-seen.sh","bridge condition: has the smith reported? (report file, or herdr left working)"
  "bin/eindri-acclaim.sh","bridge action: file the report, mark done, append the wake queue + desktop note"
  "bin/hall-snapshot.sh","the planning feed: real system state -> public-safe livehall.json for the Óðrerir Hall"
```

## The marketing stack doors (provisionable — one stack, any computer)

`bin/ymir-marketing-stack.sh up|status|down|doors` stands Mautic + Postiz +
Activepieces (+ optionally Forgejo) on ANY computer — same OSS engines the
server runs, env-driven, ports virtualized, secrets in the home, never inline.
The Allfather's server stack (zerwizserver) and the public doors agents reach:

```
marketing_doors[6]{service,door,reach_note}:
  "Mautic (email automation)","mautic.zerwiz.org -> server 127.0.0.1:8001","list building + campaigns; agent-carved via the local provisioned stack when the public door is closed"
  "Postiz (social publishing)","postiz.zerwiz.org -> server 127.0.0.1:4007","schedule X/LinkedIn/insta; queue per site"
  "Activepieces (workflow)","activepieces.zerwiz.org -> server 127.0.0.1:8080","event->post flows; meetup booked -> thread scheduled"
  "Forgejo (git · issues · PRs)","forgejo.zerwiz.org -> server 127.0.0.1:3030","the local git forge: issues->PR loop lives here"
  "SearXNG (search)","searxng on the server","private search for research (Bragi)"
  "Grafana","grafana on the server :3003","fleet + stack observability"
```

An agent (Bragi for marketing, Sindri for git) provisions the stack locally for
any user with `bin/ymir-marketing-stack.sh`; the server stack is the Allfather's
live one. Public-door exposure on the server is tunnel-driven (cloudflared) —
mend the door layer on the server, not in the tree.

## Maintaining this

- **Owner:** Brokk. **Loaded by:** `AGENTS.md`. **Mirror:** `.agents/skills/galdr-ymirsystem/assets/registry.md`.
