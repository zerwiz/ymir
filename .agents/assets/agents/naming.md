# Naming — platform map (loaded from AGENTS.md)

The full Norse component map. AGENTS.md loads this when a task names a subsystem.
Deep doctrine (law, aetts, reject list): `.agents/skills/galdr-ymirsystem/assets/norse-naming.md`.

```
platform[29]{subsystem,norse,role}:
  "Master platform root","Ymir","base host OS, master daemon"
  "Primary agent","Brokk","main autonomous worker"
  "Sub-agent worker","Eindri","isolated sandboxed workers"
  "Git worktree manager","Yggdrasil","branch isolation, zero-collision parallel edits"
  "Docker execution sandbox","Utgard","ephemeral container execution barrier"
  "Reverse proxy / gateway","Bifrost","HTTP routing, external traffic ingress"
  "OAuth / security","Heimdall","authentication guardian"
  "Cloudflare tunnel","Gjallarhorn","outbound encrypted tunnel"
  "User dashboard","Hlidskjalf","observability, monitoring, control panel"
  "Live hall board","Óðrerir","fleet planning glass (:4322); app of its own at apps/odrerir"
  "Web file browser","Skrymir","web-based file explorer"
  "Multi-tenant domains","Svartalfaheim","scoped tenant workspaces"
  "Global shared workspace","Midgard","cross-tenant shared repos & assets"
  "Inter-agent A2A bus","Ratatoskr","A2A 1.0 backbone: agent cards, task lifecycle, Redis queue"
  "Vector DB & memory","Mimirsbrunn","long-term memory, embeddings, vector store"
  "Audit trail","Runes","append-only system audit ledger"
  "Issue-to-PR pipeline","Mjollnir","autonomous bug-fix and PR creation"
  "Process health monitor","Valhalla","PM2/Docker process supervisor"
  "Skill synthesis engine","Gungnir","dynamic skill creation & validation"
  "Skill optimization/refinement","Gunnlöð","keeper of the mead of poetry; distills trajectories into refined skill artifacts"
  "Agent ergonomics standards","Galdr","TOON output, 10 design principles, master builder"
  "MCP/A2A composition","Hermóðr","MCP vertical (agent→tools) + A2A horizontal (agent↔agent)"
  "Session-start digest","Sága","the seeress who sees all; boots the session"
  "Watch / supervision","Sýn","watchful sight; guards the turn boundary"
  "Session lock","Gleipnir","the chain that binds one session"
  "Scheduled jobs","Nornir","the fates who govern time"
  "Software smidja","Smíðja","repeatable agent+code pipeline: rosters, bounded phases, typed envelopes, retries/acceptance, trace"
  "Smíðja orchestrator","Völundr","the master smith who runs Smíðja (Kaia's seat inside the smidja)"
  "Control-plane hub / federation & sync","Vingólf","the assembly hall: coordination, identity, and sync across substrates; never executes code"
```

```
eindri[3]{role,norse,descriptor,domain}:
  "developer","Sindri","smith","code synthesis, refactoring, development"
  "marketer","Bragi","skald","content, SEO, social, marketing campaigns"
  "researcher","Huginn","sage","RAG, web search, analysis, knowledge discovery"
```

## Law

Name every subsystem for the figure whose role matches its work. The operator is
the **Allfather** (Odin); never name a component with an imported term. Flavor may
season a line; it must never name a subsystem or leak into docs.
