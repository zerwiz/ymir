# YMIR — Complete Repository Structure

Authoritative layout of the Ymir Agent Operating System, cut from the live tree (2026-09-20).
Legend: `[d]` = tracked in git (doc/config/template/manifest) · `[g]` = git-ignored/generated ·
`[p]` = planned (structure exists or is promised, not yet built). Private data never lives here —
it rests in `$YMIR_HOME/hodd` (Rule 04); the repo is the public program.

```
ymir/
├── AGENTS.md                      # [d] the public contract — Brokk's doctrine, the house law, the lore
├── STRUCTURE.md                   # [d] this document — the authoritative tree
├── README.md                      # [d] overview + the three install doors (curl · npx · npm -g)
├── CONTRIBUTING.md · SECURITY.md  # [d] contribution + security policy
├── LICENSE · NOTICE · THIRD-PARTY-LICENSES   # [d] licensing
├── TODO.md · justfile · .tasks.toml         # [d] backlog + task runner
├── install.sh                     # [d] the one-liner (`curl … | bash`) — npm package install
├── .env.example · .env.sample     # [d] env templates
├── .env.local                     # [g] local secrets (.gitignore; HLIDSKJALF_AUTH etc.)
├── docker-compose.yml · Dockerfile          # [d] container manifests (companion, not the path)
├── .no-mistakes.yaml              # [d] the clean-PR gate posture
├── .gitignore · .secret-guardignore         # [d] the wards
│
├── bin/                            # THE FORGE — every door of the hall (355 files; counted, never assumed)
│   ├── ymir.js                    # [d] the npm CLI front door (install/raise/lower/eir/groa/pi…)
│   ├── ymir-install.sh            # [d] first setup (--plan · --yes · --no-desktop)
│   ├── ymir-migrate.sh · ymir-invite.sh · ymir-setup-auth.sh · ymir-say.sh
│   ├── saga-session-start.sh      # [d] the Sága digest (seated before first word)
│   ├── saga-sessionstart-run.sh · saga-wake-drain.sh
│   ├── nornir-cron-start.sh       # [d] the schedule spine; + nornir-job-*.sh (briefing, observer, housekeeping, git-sync…)
│   ├── eir-doctor.sh · groa-update.sh        # heal · renew (Eir · Gróa)
│   ├── app-lib.sh · smidja-lib.sh · hoard-lib.sh · gleipnir-lock-lib.sh · hamr-harness.sh
│   ├── einherjar-spawn.sh · eindri-start/send/control/seat/watch.sh    # the Eindri doors
│   ├── pi-seat.sh · pi-local.sh · pi-agent.sh · pi-ensure.sh            # Pi seats
│   ├── herdr-run.sh · herdr-ensure.sh · herdr-agents.py                 # herdr panes
│   ├── mimir*.{sh,py}             # the well (engram) · bifrost-*.sh (bridge) · gjallarhorn-*.sh (tunnel)
│   ├── mjollnir.sh · github-deploy.sh · branch-guard.sh · fixes-guard.sh · fixes.sh
│   ├── secret-guard.sh · hoard-guard.sh · perm-guard.sh · docs-guard.sh
│   ├── syn-watch-arm.sh · syn-turnend-guard.sh    # Sýn supervision
│   ├── valknut-load.sh            # [d] binds the distro into each harness
│   └── …                          # full inventory lives in bin/ itself
│
├── scripts/                        # THE RAISE — stand the hall, or lay it down
│   ├── start.sh                   # [d] raise: SPA :3888 · gate :3889 · Óðrerir :4322 · visualizer :8437 · services
│   ├── stop.sh · raise.sh · lower.sh
│   └── electron.sh                # [d] the desktop shell (views: hlidskjalf · smidja · odrerir; --both)
│
├── apps/                           # THE SURFACES — each its own npm package (workspaces)
│   ├── hlidskjalf/                # the high seat — React + Vite SPA, server/ gate API, electron/ shell
│   ├── odrerir/                   # the live hall — Astro board on :4322
│   ├── sessrumnir/                # the seat-hall — Electron GUI for the Pi/OMP coding agents
│   ├── smidja-factory/            # the smithy — factory (skills/templates/docs) + apps/visualizer (Vue trace :8437)
│   ├── smidja/                    # [g] the smithy engine install (python smidja_* + smidja_data) — generated
│   └── README.md                  # [d]
│
├── .agents/                        # THE AUTOMATION ENGINE
│   ├── agents/                    # [d] canonical agent profiles — brokk.md + the 19 Eindri
│   ├── skills/                    # [d] the 27 galdr-style skills (SKILL.md router + assets/); skillopt-staging is a stub
│   ├── assets/                    # [d] agents/ (naming · registry · runtime guides) + templates/
│   ├── backend/                   # [d] the FM/supervision backend (fm-*.sh)
│   ├── harness/                   # [d] per-harness plugin/agent sources (opencode …)
│   ├── bus/                       # [p] Ratatoskr A2A stub — the live mesh is the a2abridge daemon
│   ├── config/                    # [d] config/ symlink target: cron.yaml · agents.yaml · app-repos.yaml · einherjar*
│   ├── memory/                    # [g] the well (kaia.engram) + well/ episodes — private runtime
│   ├── migrations/                # [d] versioned home migrations (0001-hodd-layout …)
│   ├── gateway/ · github/ · filebrowser/ · sandbox/ · tools/ · tests/ · state/   # engine shelves
│   └── README.md                  # [d]
│
├── .pi/ · .opencode/ · .claude/ · .codex/ · .cursor/     # HARNESS DIRS (adapters + agent links)
│   ├── .pi/extensions/ · settings.json · mcp.json        # [d] Pi adapter (Gná; the session-start digest)
│   └── agents/ · plugins/ · hooks.json …                 # bound by bin/valknut-load.sh from .agents/
│
├── docs/                           # PLANNING & KNOWLEDGE
│   ├── Architecture.md · lore.md · design.md · integration.md · session-start.md
│   ├── fixes/<component>/         # [d] one file per fix (append-only; the fix history)
│   ├── runbooks/ · installations/ · research/
│   ├── workspaces.md · sync-system.md · skillopt-integration.md · ymir-rut.md
│
├── RULES/                          # THE LAW (append-only) — 01 domains · 02 agents · 03 houses ·
│   #                                04 hoard · 05 platforms · 06 append-only · 07 config ·
│   #                                08 delivery gate · 09 electron
├── .compliance/                    # [d] the NSR compliance harness (gates · telemetry · config)
├── data/                           # [g] untracked operator facts work-area (learnings, models) — truth lives in the home
├── state/ · .run/                  # [g] runtime state. `state/` is a SYMLINK to $YMIR_HOME/state (migration 0007), or absent; .run/ holds pid files/logs — never tracked
├── hodd/                           # [d] the hoard EXAMPLE templates (AGENTS.example.md, .ymir-layout.yaml.example) — never private data
├── midgard/                        # [d] shared public assets — design-system/ (tokens, icons, ymir-mark)
├── svartalfaheim/                  # [d] realm templates + examples (never real realm data)
├── workspace/                      # [d] project-registry examples (projects.yaml.example) + memory/daily scaffold
├── packaging/                      # [d] installers: build.sh · macos/ · windows/
├── deploy/                         # [d] self-host: compose/ · quadlet/ · Containerfile · env.example
├── assets/                         # [d] banners, emblems, mock/, reference/, skills/, icon-family/
├── .github/                        # [d] workflows (eindri-* · ymir-secret-scan · ymir-installers) + PR template
├── .yggdrasil/                     # [g] Brokk's worktree homes (isolation — Yggdrasil)
└── .kilo/                          # [g] older worktrees (vintage, kept apart)
```

## Directory intent

| Path | Purpose | Generated content |
|------|---------|-------------------|
| `bin/` | Every door of the hall: install, raise, heal, renew, dispatch, seat, supervise | none — [g] logs in state/ |
| `scripts/` | The raise: start/stop/lower + the Electron desktop shell | pid/log files under `$ROOT/.run` (moving to the home) |
| `apps/` | The five surfaces: high seat, live hall, seat-hall, smithy, visualizer | `dist/ out/ node_modules/` per app |
| `.agents/` | Agents (canonical profiles), 27 skills, the FM backend, harness sources, the well | well/ episodes, state |
| `.pi/ .opencode/ .claude/ .codex/ .cursor/` | Harness adapters + agent links (bound by valknut-load) | links; `~/.pi/agent/` holds the deployed cut |
| `docs/` | Knowledge: architecture, lore, runbooks, per-fix notes | fixes notes append |
| `RULES/` | Numbered house law (append-only) | corrections append |
| `.compliance/` | NSR gate harness (wiring, danger, env, paths) | `.compliance/` stamps in target repos |
| `state/ .run/` | Runtime state. `state/` is a symlink to `$YMIR_HOME/state` (migration 0007): the tree keeps the name, the home owns the truth; `.run/` holds pid files/logs | none tracked (git-ignored) |
| `hodd/ midgard/ svartalfaheim/ workspace/` | Example templates; shared public design assets; realm scaffolds; registry examples | none |

## Conventions

1. **The repo is the public program; private data lives in `$YMIR_HOME/hodd`** (Rule 04) — never a name, key, plan, or schedule tracked here.
2. **Brokk is the counsellor and dispatcher**: he stays in the main hall, plans, steers, reviews, and sends Eindri out to forge; complex/isolated work is done by Eindri on Yggdrasil worktrees (AGENTS.md — keep this in step with it).
3. **Code only inside** `bin/ · scripts/ · apps/ · .agents/`; root holds directives and config only.
4. **Realm-scoped anything** belongs under `svartalfaheim/<realm>/` — never at platform root; cross-realm shared assets go to `midgard/`.
5. **Everything governed is documented**: every subsystem's code change updates its owning Galdr asset in the same change; every fix gets one append-only note in `docs/fixes/<component>/`.
6. **Every change leaves by PR** (Rule 08) — never a direct push to main; the Allfather's approval is the merge.