# YMIR — Complete Repository Structure

Authoritative layout of the Ymir Agent Operating System.
Legend: `[d]` = file tracked in git (doc/config/template) · `[g]` = git-ignored/generated · `[p]` = planned (not implemented yet)

```
ymir/
├── AGENTS.md                      # [d] Core directives, routing & operational laws for Brokk
├── STRUCTURE.md                   # [d] This document — authoritative tree
├── README.md                      # [d] Project overview & quickstart
├── .env.example                   # [d] Secret template (keys, URLs, tokens)
├── .env.local                     # [g] Local git-ignored secrets (master keys)
├── .gitignore
├── docker-compose.yml             # [d] Master container manifest
├── Dockerfile                     # [d] Core agent runner image (skeleton)
├── certs/                         # [g] SSL certs for Bifrost / reverse proxy
│
├── docs/                          # PLANNING & KNOWLEDGE LAYER
│   ├── Architecture.md            # [d] Master architecture document
│   ├── README.md                  # [d] Docs index & reading order
│   └── plans/                     # [d] One planning doc per feature
│       ├── README.md              # Feature index + status table
│       ├── 01-core-monorepo.md
│       ├── 02-memory-system.md
│       ├── 03-skill-synthesis.md
│       ├── 04-cron-automation.md
│       ├── 05-tooling-engine.md
│       ├── 06-yggdrasil-worktrees.md
│       ├── 07-utgard-sandbox.md
│       ├── 08-subagent-fleet.md
│       ├── 09-ratatoskr-bus.md
│       ├── 10-multi-tenant-realms.md
│       ├── 11-tenant-agent-runtime.md
│       ├── 12-hlidskjalf-portal.md
│       ├── 13-skrymir-file-access.md
│       ├── 14-bifrost-heimdall-gateway.md
│       ├── 15-gjallarhorn-tunnel.md
│       ├── 16-communication-gateways.md
│       ├── 17-portfolio-process-control.md
│       ├── 18-github-cicd.md
│       ├── 19-mjollnir-issue-pr.md
│       └── 20-midgard-shared-workspace.md
│
├── .agents/                       # AUTOMATION ENGINE (system core)
│   ├── assets/                    # [d] Reusable templates & schemas
│   │   ├── templates/
│   │   │   ├── PRD_template.md
│   │   │   ├── env.template
│   │   │   └── system_prompt.template
│   │   └── schemas/
│   │       └── tool_manifest.json
│   │
│   ├── subagents/                 # [d] Role profiles for Eindri workers
│   │   ├── developer.md
│   │   ├── marketer.md
│   │   └── researcher.md
│   │
│   ├── bus/                       # RATATOSKR — inter-agent message bus
│   │   ├── protocol.ts            # [p] InterAgentMessage schema
│   │   └── messages.json          # [g] Active message queue state
│   │
│   ├── cron/                      # GUNGNIR CRON — autonomous triggers
│   │   ├── daily_brief.ts         # [p] 07:00 executive briefing
│   │   ├── git_backup.ts          # [p] Auto-commit workspace sync
│   │   └── social_poster.ts       # [p] Marketing queue execution
│   │
│   ├── fleet/                     # VALHALLA — portfolio & process tracking
│   │   ├── app_registry.json      # [d] Manifest of all projects/tenants
│   │   └── process_monitor.ts     # [p] PM2/Docker health check engine
│   │
│   ├── filebrowser/               # SKRYMIR — web file access config
│   │   ├── .filebrowser.json      # [d] Root config mapping /files route
│   │   └── filebrowser.db         # [g] Auth, roles, scoped permissions
│   │
│   ├── gateway/                   # BIFROST — reverse proxy router
│   │   └── nginx.conf             # [p] Routes UI, Files, webhooks, WS
│   │
│   ├── github/                    # HEIMDALL & MJOLLNIR — GitHub integration
│   │   ├── secrets_rotator.ts     # [p] Injects secrets via gh secret set
│   │   ├── webhooks/
│   │   │   ├── issue_listener.ts  # [p] Inbound bug-report webhook
│   │   │   └── .gitkeep
│   │   └── workflows/
│   │       ├── deploy-staging.yml      # [p] CI/CD template
│   │       ├── deploy-production.yml   # [p] CI/CD template
│   │       └── .gitkeep
│   │
│   ├── memory/                    # MIMIRSBRUNN — vector & audit ledger
│   │   ├── mimirsbrunn.db         # [g] Vector embeddings store
│   │   └── runes_audit.md         # [d] Append-only system audit ledger
│   │
│   ├── sandbox/                   # UTGARD — ephemeral container isolation
│   │   ├── Dockerfile.utgard      # [d] Hardened execution container
│   │   ├── execute_utgard.ts      # [p] Docker runner for safe execution
│   │   └── utgard.config.json    # [d] CPU/RAM/timeout caps
│   │
│   ├── skills/                    # GUNGNIR — reusable executable skills
│   │   ├── README.md              # [d] Skill index & synthesis rules
│   │   ├── yggdrasil_manager.ts   # [p] Worktree create/sync/cleanup
│   │   ├── ratatoskr_bus.ts       # [p] Message dispatch & inbox
│   │   ├── mjollnir_solver.ts     # [p] Issue-to-PR pipeline
│   │   ├── brokk_exec.ts          # [p] Brokk agent launcher
│   │   ├── process_controller.ts  # [p] Start/stop/restart services
│   │   ├── register_foreign_app.ts# [p] Onboard external repos
│   │   ├── self_synthesize_skill.ts#[p] Invent & validate skills
│   │   ├── tenant_context_loader.ts#[p] Load realm env & workspace
│   │   ├── github_sync.ts         # [p] Clone/sync repos into realms
│   │   ├── github_deploy.ts       # [p] Zero-trust workflow deploy
│   │   ├── file_stream.ts         # [p] Live file change events to UI
│   │   ├── notify_user.ts         # [p] Telegram + WebSocket push
│   │   ├── auto_commit_sync.ts    # [p] Background git backup
│   │   └── workspace_rag.ts       # [p] Semantic memory retrieval
│   │
│   └── tools/                     # YGGDRASIL — CLI & execution harnesses
│       ├── README.md              # [d] Tool index
│       ├── yggdrasil.ts           # [p] Worktree CLI harness
│       ├── hermes_runner.ts       # [p] Realm agent CLI orchestrator
│       ├── herder.ts              # [p] Terminal multiplexer & pane state tracker
│       ├── vector_db.ts           # [p] Vector indexing & RAG search
│       ├── firebase.ts            # [p] Backend provisioning
│       └── supabase.ts            # [p] DB & edge function setup
│
├── midgard/                       # GLOBAL SHARED WORKSPACE (cross-tenant)
│   ├── README.md                  # [d]
│   ├── design-system/             # Shared UI components & assets
│   ├── shared-packages/           # Internal npm/cargo/python libs
│   ├── infrastructure/            # Terraform, Docker, K8s base configs
│   └── github_org_repos/          # Central company repositories
│       └── shared-core-api/       # Example shared repo (cloned)
│           ├── .yggdrasil/        # [g] Ephemeral worktree branches
│           └── .gitkeep
│
├── svartalfaheim/                 # REALM DOMAINS (scoped per operator)
│   ├── README.md                  # [d] Realm templates & rules
│   ├── examples/                  # [d] Public example realms (never real data)
│   └── work/                      # [d] Operator workspace scaffold
│
├── workspace/                     # GLOBAL / PERSONAL STATE & AUDIT
│   ├── README.md
│   ├── config/
│   │   ├── toolchain.md           # [d] Capabilities manifest (tools configured)
│   │   └── portfolio.md           # [d] Active projects, PIDs, pipelines
│   └── memory/
│       └── runes_audit.md         # [d] Global append-only audit ledger
│
└── apps/                          # USER INTERFACES & CONTROL PANELS
    ├── README.md
    └── hlidskjalf/                # MASTER CONTROL DASHBOARD (Expo/RN)
        ├── README.md
        ├── package.json           # [p] Expo dependencies
        ├── App.tsx                # [p]
        └── src/
            ├── app/               # Navigation & app entry
            ├── components/        # FileViewer, PRCard, NetworkView, TenantSelector, OmniChat, Fleet
            └── services/          # API & WebSocket clients
```

## Directory Intent Reference

| Path | Purpose | Generated content |
|------|---------|-------------------|
| `docs/` | Human-readable planning & architecture | Planning docs, master architecture |
| `.agents/assets/` | Reusable templates (PRDs, prompts, manifests) | Agent-created artifacts |
| `.agents/subagents/` | Role profiles for Eindri workers | None |
| `.agents/bus/` | Inter-agent message schema & queue | `messages.json` grows at runtime |
| `.agents/cron/` | Autonomous background triggers | Logs written to realm memory/daily |
| `.agents/fleet/` | App/process registry & health state | `app_registry.json` grows at runtime |
| `.agents/memory/` | Vector store + audit ledger | `mimirsbrunn.db`, `runes_audit.md` |
| `.agents/sandbox/` | Utgard container configs | None |
| `.agents/skills/` | Executable skills (recurring tasks) | New skills synthesized at runtime |
| `.agents/tools/` | Low-level CLI wrappers | None |
| `midgard/` | Cross-tenant shared repos/assets | Cloned repos |
| `svartalfaheim/` | Scoped realm domains | Realm docs, projects, daily logs |
| `workspace/` | Global state (non-realm) | Audit entries, toolchain state |
| `apps/hlidskjalf/` | Web/mobile control plane | Expo build output |
| `certs/` | SSL certificates for Bifrost | Runtime certs |

## Conventions

1. **No code at root** — root holds only directives and config.
2. **Realm-scoped anything** — product, marketing, life, or dev state belongs under `svartalfaheim/<realm>/`, never at platform root.
3. **Shared anything** — cross-realm assets belong under `midgard/`.
4. **Code only inside** — `.agents/tools`, `.agents/skills`, `.agents/cron`, `.agents/github`, `.agents/sandbox`, and `apps/`.
5. **Everything documented** — every feature has a planning doc in `docs/plans/` and is reflected in `docs/Architecture.md`.