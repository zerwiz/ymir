# YMIR — The Single-Tenant Agent Operating System


---

<p align="center">
  <strong>created by zerwiz</strong> · <a href="https://zerwiz.org">https://zerwiz.org</a> · whynotproductions<br>
  <em>a hobby project, made for the love of the craft. use it, fork it, enjoy it.</em>
</p>

---

> **One operator. One repo. A whole business, run by a Norse-named agent fleet.**

![Ymir — the single-tenant agent OS](assets/ymir-banner-03.png)

Ymir is not lean. It is a single-operator agentic **distro**: a fleet of named
agents, sealed sandboxes, a memory well, an audit ledger, and a control plane
you actually look at — running from one repository. You are the **Allfather**;
**Brokk** is your primary agent; **Eindri** are the isolated workers it dispatches.
Everything —
development, marketing, business strategy, life — runs from one repository, with an
audit ledger, a memory well, one tenant and its workspaces, and a control plane you actually look at.

---

## The Allfather's Chain

The Allfather holds the only chain. If the Allfather does not draw it, Ymir walks
the machine as the Allfather walks it — no gate between the agent and the tools,
no second master but the Allfather's own hand.

---

## The Lore (short version)

Ymir is not a theme — the myths are **load-bearing allegory**. Every subsystem is
named for the figure whose role matches the machine's job:

The platform is the primordial giant **Ymir**, from whose body the worlds were
carved. The smiths are **Brokk** (the bellows-smith, your primary agent) and
**Eindri** (the workers who out-forged the gods). Memory is **Mimirsbrunn**, the
well at the root of **Yggdrasil**, and **Kaia** is the oracle who speaks from it.
Every significant action is carved into **Runes**, an append-only ledger. Work
passes the **seven gates** and is built on **borrowed anvils** — validated open
source first, always. The full tale: [`docs/lore.md`](docs/lore.md).

| Component | Role |
|---|---|
| **Ymir** | the platform / host daemon |
| **Brokk** | the primary autonomous agent |
| **Eindri** | isolated workers — Sindri, Bragi, Huginn, Mímir, Forseti, Snotra, Kvasir |
| **Mimirsbrunn** | the memory well (engram) + Kaia's bridge |
| **Yggdrasil** | git worktrees — zero-collision parallelism |
| **Utgard** | ephemeral Docker sandboxes — the execution barrier |
| **Runes** | the append-only audit ledger |
| **Hlidskjalf** | the control plane / observability |

---

## What it is

- **A distro, not an app.** Launch a supported harness in the repo and you take the
  high seat: context is injected before your first turn, the model bridge is raised,
  the scheduled jobs start.
- **Isolation by default.** Complex work runs in **Yggdrasil** worktrees sealed by
  **Utgard** sandboxes; a failed run never touches main.
- **Audit everything.** **Runes** is an append-only, checksum-chained ledger.
- **Memory that grounds.** **Mimirsbrunn** (engram) is drunk from before dispatch and
  watered after; a dry well never blocks.
- **Humans in the loop.** **Mjollnir** opens PRs; nothing force-merges.
- **Open source first.** Ymir owns only three things — the UI, the runtime, and
  A2A collaboration. Everything else wears a Norse name over a validated engine.

---

## Host platforms — three first-class identities

Ymir is not portable-in-theory; it is **native** to the machine it runs on. Three
platforms are first-class, and each one is detected, used, and learned rather than
merely tolerated.

| Identity | What it means | Where it lives |
|---|---|---|
| **Omarchy-native** | The host desktop is Omarchy (Arch + Hyprland). Ymir reads monitors/scale, lets Hyprland own window placement, mitigates the amdgpu GPU crash, and **learns the user's setup** — packages, configs, Omarchy version — re-learning after every `omarchy update` via a `post-update` hook. | `bin/omarchy-sense.sh`, `bin/omarchy-hook-install.sh`, skill `ymir` |
| **herdr-first (Þjazi)** | Agent panes need a terminal backend. **herdr** is preferred (Þjazi protocol **14+**; presentation spaces at **0.8.0+**), **tmux** is the accepted reference backend. A missing backend is reported, never silently degraded. | `bin/herdr-ensure.sh`, skill `ymir` |
| **pi-native** | The [pi](https://pi.dev) coding harness is a first-class surface: extensions, skills, prompt templates, themes, custom providers, and **pi packages** (npm/git) are all live. This is where Ymir gains reach — a new capability can be a pi extension or a packaged bundle, not just a shell script. | `.pi/extensions/`, `.pi/settings.json`, `.pi/mcp.json` |

**Why this matters.** The freedom runs both ways: because Ymir is pi-native it can
ship **pi packages** — bundling extensions, skills, prompt templates, and themes
for others to `pi install` — and because it is Omarchy-native it can help an
Omarchy user set up and tune the whole machine, not just the repo.

On a non-Omarchy host the Omarchy steps are a clean `SKIP`; Ymir still runs. On a
host without herdr, tmux carries the panes. On a harness that is not pi, the
runtime adapts through the harness adapters (see `hamr`).

### Omarchy-native

Ymir treats the host desktop as part of itself. It **detects** Omarchy
(`/usr/share/omarchy`), **reads** the real layout (`hyprctl monitors -j` — physical
size *and* scale, because a 1920×1200 panel at scale 1.5 is a 1280×800 logical
desktop, and mixing the two is the classic placement bug), and **lets Hyprland own
placement** rather than fighting the compositor.

- **Desktop placement.** On Omarchy the numbered **desktops** (`1 2 3 4 5 …`) are
the operator's "screens". `bin/desktop-place.sh` gives each Ymir app its **own
desktop, preferring an empty one**, via Omarchy's own rule idiom
(`o.window({ class = "^ymir-hlidskjalf$" }, { workspace = "2" })`), and never
edits `/usr/share/omarchy/`.
- **It learns the machine.** `bin/omarchy-sense.sh` records a comparable snapshot
(Omarchy version, explicit packages, config files, monitors, scale) and **diffs**
it, so Ymir can advise on *this* setup. `bin/omarchy-hook-install.sh` installs a
`post-update.d` hook, so **every `omarchy update` re-teaches it**.
- **It survives the hardware.** On a small-VRAM iGPU the Wayland GPU process can
die with `amdgpu: Not enough memory for command submission` (SIGSEGV, not an OOM);
`YMIR_DESKTOP_DISABLE_GPU=1` runs the dashboards on software rendering.

Full reference: the `ymir` skill. Omarchy's own skill is authoritative for
Omarchy itself; ours adds the Ymir integration.

### herdr-first (Þjazi)

Every Eindri worker lives in a terminal pane, so the backend matters. Ymir prefers
**herdr** and accepts **tmux** — and never degrades silently.

```
backend_priority[3]{rank,backend,note}:
  "1","herdr","preferred; protocol 14+ for panes, 0.8.0+ for presentation spaces"
  "2","tmux","verified reference backend"
  "3","none","spawn is refused with a plain reason"
```

`bin/herdr-ensure.sh` verifies the *version* (not just presence) and installs via
the pinned, SHA-256-verified installer when herdr is absent. Selection order:
`config/backend` → `BROKK_BACKEND` → `HERDR_ENV=1` → else tmux. Full reference:
the `ymir` skill.

### pi-native

[pi](https://pi.dev) is the harness Ymir runs in, and Ymir uses that fully rather
than treating it as a shell to be wrapped:

- **Extensions** — `.pi/extensions/` carries live behaviour (the watcher arm, the
turn-end guard, the Ró presentation preference, the agent-state surface).
- **Packages** — `pi install npm:<pkg>` / `git:<repo>` bundles extensions, skills,
prompt templates, and themes. Ymir can **ship its own**, so a Ymir capability can
be distributed and installed like any pi package, not only as a shell script.
- **Model providers** — pi resolves models from `~/.pi/agent/models.json`, whose
shape is `{"providers": {...}}`. Local servers (LM Studio, Ollama, vLLM) and the
Bifrost bridge are configured the same way, so the fleet runs on local or cloud
models by the operator's choice.

This is the freedom you gain from being pi-native: a new capability has three
possible homes — a shell script, a skill, or a **pi package** — and the last one is
installable by anyone running pi.

---

## System Map

| Subsystem | Norse Name | Role |
|---|---|---|
| Platform root | **Ymir** | master daemon / host OS |
| Primary agent | **Brokk** | the autonomous operator's hand |
| Sub-agent workers | **Eindri** | isolated sandboxed workers |
| Git worktrees | **Yggdrasil** | zero-collision parallel edits |
| Docker sandbox | **Utgard** | ephemeral execution barrier |
| Gateway | **Bifrost** | reverse proxy / HTTP routing |
| Model bridge | **Bifrost bridge** | local OpenAI-compatible endpoint for the fleet |
| OAuth guard | **Heimdall** | GitHub OAuth / JWT |
| Tunnel | **Gjallarhorn** | Cloudflare outbound tunnel |
| Dashboard | **Hlidskjalf** | observability & control plane |
| File browser | **Skrymir** | web file explorer |
| Workspaces | **workspace/** | personal & work scopes over domains |
| Shared space | **Midgard** | shared assets & repos |
| Message bus | **Ratatoskr** | A2A 1.0 backbone (cards, lifecycle, Redis) |
| Vector memory | **Mimirsbrunn** | engram store + Kaia's bridge (`:4602`) |
| Audit ledger | **Runes** | append-only system log |
| Issue→PR | **Mjollnir** | autonomous fixes & PRs |
| Process monitor | **Valhalla** | PM2/Docker supervision |
| Skill synthesis | **Gungnir** | dynamic skill creation |
| Skill optimization | **Gunnlöð** | trajectory-driven skill refinement |
| Smíðja | **Smíðja** | the smithy — roster, phases, trace |
| Session digest | **Sága** | the context injected at session open |
| Watch / supervision | **Sýn** | watcher, guard, seat continuity |
| Session lock | **Gleipnir** | one live session per home |
| Scheduled jobs | **Nornir** | the fates who govern time |
| Control-plane hub | **Vingólf** | coordination, identity, sync across substrates |
| Live hall board | **Óðrerir** | fleet planning glass (:4322) |
| Multi-tenant domains | **Svartalfaheim** | scoped tenant workspaces |
| Agent ergonomics | **Galdr** | TOON output, 10 design principles |
| Smíðja orchestrator | **Völundr** | runs Smíðja (Kaia's seat inside) |
| MCP/A2A composition | **Hermóðr** | MCP vertical (agent→tools) + A2A horizontal |
| Host desktop (Omarchy) | **Omarchy** | the machine Ymir runs on: monitors, scale, themes, hooks |
| Terminal backend | **Þjazi** | agent panes — herdr (protocol 14+) or tmux |
| Harness surface | **pi** | extensions, skills, prompt templates, packages |

---

## Skills

Every reusable capability is a skill in [`.agents/skills/`](.agents/skills/), each
named for the figure whose role matches the work (the Gungnir naming law). Galdr is
the master builder; Tyr judges compliance.

| Skill | Norse | Purpose |
|---|---|---|
| `galdr` | Galdr | agent-CLI ergonomics + master builder/maintainer of the runtime |
| `tyr-check` | Tyr | the judge — validates tools/skills/docs against the 10 principles |
| `smidja` | Smiðja | the smithy: roster + bounded phases + typed envelopes |
| `hvild-afk` | Hvíld | away-mode supervision: routine wakes self-handled, escalations batched |
| `saga` | Sága | session bearings: fleet digest (/bearings) + recap (/ahoy) |
| `muninn-stow` | Muninn | session-knowledge curation, routing, and persistence |
| `jord-projects` | Jörð | project registry + delivery posture |
| `urdh` | Urðr | Allfather-hold lifecycle |
| `frigg-consent` | Frigg | consent / ask-user authority gate |
| `vor-diagnostics` | Vör | bootstrap + diagnostic reasoning |
| `nornir` | Nornir | fate & schedule: events + quota |
| `gjallarhorn-relay` | Gjallarhorn | public relay replies (X / Discord) |
| `eindri-homes` | Eindri | isolated worker homes |
| `syn-recovery` | Sýn | stuck-worker recovery playbook |
| `ymir` | Ymir | operate the host: update · Omarchy · Þjazi |
| `hamr` | Hamr | per-harness adapter reference (OpenCode, Pi, Claude, Cursor, Codex) |
| `gunnlod` | Gunnlöð | skill optimization — trajectory-driven refinement via SkillOpt |

The Galdr family enforces the 10 ergonomic principles (TOON output, minimal schemas,
self-correcting errors) and the runtime acceptance gates; run
`bash .agents/skills/galdr-ymirsystem/scripts/compliance-check.sh` before claiming done.

---

## Agents

The **Eindri** take a mythic name whose craft matches the job, and each runs in an
Utgard sandbox on a Yggdrasil worktree.

| Eindri | Figure | Craft | Speciality |
|---|---|---|---|
| **Sindri** | the smith | developer | code synthesis, refactoring, tests, CLIs |
| **Bragi** | the skald | marketer | content, SEO, social, campaigns |
| **Huginn** | the sage | researcher | RAG, web search, analysis |
| **Mímir** | the wise | planner | architecture, sequencing, risk |
| **Forseti** | the just | reviewer | review, QA, acceptance — changes nothing |
| **Snotra** | the wise-woman | documenter | docs, write-ups, changelogs |
| **Kvasir** | the knowing | scout | reconnaissance — changes nothing |

Profiles live in [`.agents/agents/`](.agents/agents/) and are bound to each tool by
`bin/valknut-load.sh` (OpenCode reads `.opencode/agents/`; Pi links resolve under
`.pi/agents/`).

---

## The Runtime — taking the seat

When a harness opens in the repo, **Sága** speaks before the first turn: the seat is
bound by **Gleipnir**, the model bridge is raised, the **Nornir** jobs start, and
the fleet context is injected (hidden, by design). Run-tier harnesses run the digest
and inject it; nudge-tier harnesses are asked.

| Harness | Session-start surface |
|---|---|
| **OpenCode** | `.opencode/plugins/{saga-sessionstart,syn-watch-arm,syn-turnend-guard}.js` |
| **Pi** | `.pi/extensions/{syn-turnend-guard,gna-pi-watch,ro,skuld-branch-supervision}.ts` |
| **Claude Code** | `.claude/settings.json` — `SessionStart` + `Stop` |
| **Cursor** | `.cursor/hooks.json` — `sessionStart` + `stop` + `preToolUse` |
| **Codex** | `.codex/hooks.json` — `SessionStart` + `PreToolUse` + `Stop` |

- **Seat:** `bin/saga-session-start.sh` — the one ordered digest.
- **Lock:** `bin/gleipnir-lock-lib.sh` — bound to the live session pid.
- **Bridge:** `bin/bifrost-bridge.sh` — raises the local model endpoint.
- **Jobs:** `bin/nornir-cron-start.sh` — daily briefing 07:00, observer, housekeeping, git sync.
- **Watch:** `bin/syn-watch-arm.sh` + the harness adapter.

Details: [`docs/session-start.md`](docs/session-start.md).

---

## The Control Plane — Hlidskjalf

[`apps/hlidskjalf`](apps/hlidskjalf) is the dashboard. It runs **live** against a
small local gate API that reads the runtime, or in **demo mode** on seeded data.

```bash
scripts/start.sh     # raises the gate API (:3889) + the SPA (:3888)
scripts/stop.sh
```

Views: Fleet · Tasks · Well · Runes · Reviews · Processes · Files · OmniChat ·
Runtime · Cron · Forge · Profile. OmniChat speaks to **Kaia** for real (recall from
the well, replies via the local model bridge). Press **Enter demo mode** on the sign-in
screen to explore without the runtime.

---

## Quick Start

```bash
git clone <this-repo> ~/Ymir && cd ~/Ymir
cp .env.example .env.local          # fill in your keys (never committed)

# 1) First setup — prints a plan, asks you to accept, then validates itself
bin/ymir-install.sh                 # add --yes for non-interactive, or --check to preview

# 2) The control plane (live data)
scripts/start.sh                    # → http://127.0.0.1:3888/

# 3) The agent seat (any supported harness)
bin/saga-session-start.sh           # the digest (auto-runs on harness open)
```

The installer is idempotent and self-healing: it provisions what it can in user
space (`bun`, `uv`, `mcp`, the Þjazi backend), installs the OSS engines, learns
the machine, places the desktop apps, and — on an **Omarchy** host — sets the
update hook that re-teaches it after every `omarchy update`. It ends by opening
both desktop apps and running `bin/ymir-validate.sh` to prove what stands.

### What each platform buys you

The installer serves all three of Ymir's native homes on **every** run — a
non-Omarchy host loses only the Omarchy-specific hook, never the logic.

```
platform_gifts[3]{platform,what_the_install_does,what_you_gain}:
  "Omarchy","detects the host, reads hyprctl monitors+scale, writes o.window desktop rules, snapshots the setup, installs the post-update hook","your dashboards land on their own numbered desktops; Ymir knows THIS machine and relearns it when Omarchy moves"
  "herdr (Þjazi)","bin/herdr-ensure.sh verifies the version against the floors and installs via the pinned, SHA-verified installer; tmux is the accepted reference","every Eindri worker gets a real pane in a real terminal; presentation spaces at 0.8.0+, panes at protocol 14+"
  "pi","registers the harness surfaces, the MCP servers, and the model providers (local LM Studio / Ollama or the Bifrost bridge)","extensions, skills, prompt templates, themes, and pi PACKAGES are all live — a new Ymir capability can ship as an installable pi package"
```

A new capability therefore has three possible homes — a shell script, a skill, or
a **pi package** — and on Omarchy it can also reach the desktop itself. That is the
freedom of being native to all three rather than portable to none.

Point a harness (OpenCode, Pi, Claude Code, Cursor, Codex) at the repo and it takes
the seat as **Brokk**. Read [`AGENTS.md`](AGENTS.md) for the operating laws and
`$YMIR_HOME/docs/masterplan.md` for the forge orders.

### Bringing your own machine — Windows, macOS, Linux

Ymir is **Omarchy-first**: the Omarchy layer is first-class. But *first* is not
*only*. The core is portable, and every other host gets a layer of its own.
`bin/host-sense.sh` is the one place that looks before anything acts — distro,
kernel, session (Wayland/X11), desktop, and what that desktop can actually do:

```bash
bin/host-sense.sh                     # THIS machine, as TOON
bin/host-sense.sh capability tray     # yes | partial | no — for scripting
```

```
hosts[4]{host,how_you_get_it,what_it_is}:
  "Omarchy","bin/ymir-install.sh","the first-class layer: numbered desktops, launcher entries, the post-update hook"
  "other Linux (Ubuntu · Fedora · Debian · Arch)","bin/ymir-install.sh","the portable core; the Omarchy layer skips cleanly, never faked"
  "Windows","Ymir-Setup.exe — or bin/bootstrap-windows.ps1","Ubuntu on WSL2 is the host; Ymir installs inside it"
  "macOS","Ymir Installer.command (or the .pkg) — or bin/bootstrap-macos.sh","Ubuntu in a Lima VM is the host; Ymir installs inside it"
```

Windows and macOS do not run Ymir natively: what Ymir installs is a Linux
runtime, so those layers raise a Linux host and hand the work to
`bin/ymir-install.sh` inside it. Each is gated on its host and skips cleanly
everywhere else — no layer asserts a machine it is not standing on.

**Build the installers** — neither needs a matching host:

```bash
packaging/build.sh --check     # what this machine can build, and with what
packaging/build.sh --exe       # Ymir-Setup-<version>.exe   (NSIS: apt-get install nsis)
packaging/build.sh --mac       # Ymir-<version>.pkg         (pkgbuild — Apple-only)
```

CI builds both (`.github/workflows/ymir-installers.yml`): NSIS on an Ubuntu
runner, pkgbuild on a macOS runner. Signing and notarisation need the operator's
own Apple and Windows credentials, so the artefacts ship unsigned.

---

## Stack — Today vs Target

| Layer | Today (agent-proficient) |
|---|---|
| Control plane & daemons | **TypeScript** (Node 22) / **Bun** |
| Agent orchestration | **Python 3.12+** + TypeScript |
| UI / UX | **React + Vite** (Hlidskjalf) |
| Inter-agent | **A2A 1.0** (JSON-RPC 2.0 / SSE) + **Redis** |
| Memory | **engram** — the Mimirsbrunn well |
| Gateway / Auth / Tunnel | Traefik/Caddy · OAuth2-proxy · cloudflared |
| Sandbox | Docker (rootless, network-none) |
| Runtime backend | Pi / OpenCode harnesses; herdr/tmux panes |

**Target (Ymir Rut v2.6 — re-forged later, never redesigned):** Rust (Edition 2024) +
Tokio · NATS JetStream · gRPC/Protobuf · libgit2 · cgroups v2 / seccomp · PostgreSQL
16 · MinIO/S3. See [`docs/ymir-rut.md`](docs/ymir-rut.md).

---

## Design Language

**Carved, not skinned.** Cinzel (rune headings) · JetBrains Mono (code & telemetry) ·
Inter (body). Canvas: obsidian slate; accents: electric cyan for Bifrost, violet for
the realms. Emblem: the Algiz rune over a blacksmith's anvil. Tokens are the single
source of truth in [`midgard/design-system/tokens.css`](midgard/design-system/tokens.css);
full spec in [`docs/design.md`](docs/design.md).

---

## Folder Structure

> **Single tenant.** One operator (the Allfather), many **workspaces**
> (personal · work) over knowledge **domains** (company · marketing ·
> development · life · me). Houses (Ymir Labs, Brokk Forge, …) are brands, not
> isolation. OSS engines under Norse shells: **treehouse** → Yggdrasil
> (worktrees), **sandcastle** → Utgard (sandboxes), **no-mistakes** →
> Mjollnir/Glitnir (clean-PR gate).

```
ymir/
├── AGENTS.md                  # the always-loaded contract (Brokk)
├── bin/                       # Norse runtime: saga, syn, rodd, gleipnir, nornir, einherjar,
│                              #   yggdrasil (treehouse), utgard (sandcastle), mimir-bridge,
│                              #   ymir-install, workspace-provision, project-git, mjollnir,
│                              #   hermes-ensure (provision the Hermes worker runtime)
├── .agents/
│   ├── agents/                # Brokk + the Eindri profiles (and Galdr)
│   ├── skills/                # Gungnir skills (galdr, tyr-check, hvild-afk, …)
│   ├── backend/               # vendored fleet backend
│   ├── config/                # ro, cron.yaml, eindri-dispatch, eindri-harness
│   ├── memory/               # Mimirsbrunn well — kaia.engram + episodes.jsonl
│   ├── sandbox/               # Utgard barrier (Dockerfile.utgard, utgard.config.json)
│   └── bus/                   # Ratatoskr (A2A) protocol
├── .pi/extensions/  .pi/mcp.json   # Pi adapters (Sýn, Gná, Ró, Skuld) + engram MCP
├── .opencode/plugins/         # OpenCode adapters (Sága, Sýn, Rödd)
├── apps/hlidskjalf/           # the control plane (React + Vite + Bun gate API)
├── midgard/                   # shared assets, design tokens, icons
├── svartalfaheim/             # company container root (zerwiz) — future multi-user
├── workspace/                 # THE SINGLE TENANT: work/ · personal/ · companies/ ·
│                              #   workspaces.yaml · projects.yaml · memory/ · INSTALL.md
├── apps/smidja/                 # the smithy engine + smidja.db (runs, stats, trace)
├── state/                     # runtime state: lock, chat/, bridges, cron
├── scripts/start.sh stop.sh   # raise/lower the whole system
├── assets/                    # art, the OS diagram, reference material
└── docs/                      # lore, architecture, masterplan, plans, session-start
```

---

## Key combinations

Every key Ymir binds. On Omarchy they live in
`~/.config/hypr/ymir-launchers.lua` (generated by `bin/desktop-place.sh apply`)
and are required from `hyprland.lua`. See what is live with
`omarchy menu keybindings --print`.

| Key | What it does | Declared by |
|---|---|---|
| **SUPER + Y** | raise **Hlidskjalf** — the control plane | `bin/desktop-place.sh` → `~/.config/hypr/ymir-launchers.lua` |
| **SUPER + M** | raise **Smiðja** — the visualizer | same file |
| **ctrl + shift + e** | open the **file picker** over the working directory | `.pi/extensions/open-editor.ts` |

Each app window opens on **its own numbered desktop** (the placement rules in
`bin/desktop-place.sh` send it there), so a speed-start both raises the app and
keeps it off the desktop you are working on. `/edit [path]` is the same editor
surface as a slash command, with tab-completion over the directory.

Each app also offers the same speed-start **in its own UI** (`POST /api/desktop`),
so the keyboard is a convenience for the operator's hands, not the only way in.

> The editor is the Allfather's own surface: it registers no LLM tool, because
> agents already have `read` and `edit`. Name it when he would reach for it;
> never try to drive it.

---

## Inviting someone else in

Ymir is single-operator by design: one person directs the fleet. Someone else can
try yours without being handed your account. The installer mints an **invite
code** and prints it at the end of the run:

```bash
bin/ymir-invite.sh mint --limit 3   # a code that admits 3 accounts
bin/ymir-invite.sh list             # every code, what is spent, who is in
bin/ymir-invite.sh revoke CODE      # take one back, now
```

They open the gate and choose **“I have an invite code”**, then pick their own
username and password. Registration stays **closed** unless a live code exists,
and each code stops admitting accounts once its ceiling is spent — so an instance
is never accidentally open, and a link that leaks is not a door.

Accounts live in `~/.config/ymir/accounts.json` (mode `0600`) as argon2id
hashes; no plaintext password is ever written, and nothing about them enters the
repo. Your own credentials stay `HLIDSKJALF_AUTH` in `.env.local`.

---

## Desktop & Mobile

- **Desktop (Electron).** `scripts/electron.sh start` (or `npm run desktop` in
  `apps/hlidskjalf`) opens Hlidskjalf + Smiðja as a native window — app icon and
  a stable “Ymir · Hlidskjalf” title. It raises the stack if it is down.

- **Android APK (Capacitor).** A thin native shell over the Hlidskjalf web app —
  one codebase, pointed at your tunnel.

  ```sh
  cd apps/hlidskjalf
  npm install
  npm run build
  npx cap sync android
  cd android
  JAVA_HOME=<jdk-17> ANDROID_HOME=<android-sdk> ./gradlew assembleDebug
  # → android/app/build/outputs/apk/debug/app-debug.apk
  ```

  Change the server later **without touching code**:

  ```sh
  YMIR_SERVER_URL=https://your.server npx cap sync android
  ```

  Default target is `https://<your-host>` (`capacitor.config.ts`).

- **PWA.** Open the tunnel URL on a phone and “Add to Home Screen” — the manifest
  ships in `apps/hlidskjalf/public/manifest.webmanifest`.

---

## Naming Law

Every subsystem, component, and process is named for the figure whose role matches
its work; the operator is the **Allfather** (Odin). The house voice is Norse-natural;
flavor may season a line, but an imported term never names a subsystem. The full
component map lives in
[`.agents/skills/galdr-ymirsystem/assets/norse-naming.md`](.agents/skills/galdr-ymirsystem/assets/norse-naming.md).

---

## Built on

Ymir is a Norse-named derivative of the **firstmate** agent distro
([github.com/kunchenguid/firstmate](https://github.com/kunchenguid/firstmate),
MIT License, © kunchenguid). Ymir adopts and retargets firstmate's mechanism under
its open-source-first law; upstream names survive only as provenance. See
[`NOTICE`](NOTICE).

---

## Docs

- [`docs/lore.md`](docs/lore.md) — the mythos, realm by realm
- [`docs/session-start.md`](docs/session-start.md) — how the seat is taken
- [`docs/Architecture.md`](docs/Architecture.md) — the 7 realms, A2A, memory, migration
- [`docs/masterplan.md`](docs/masterplan.md) — the append-only forge orders
- [`docs/plans/README.md`](docs/plans/README.md) — the feature plan index
- [`docs/design.md`](docs/design.md) — the design system
- [`docs/ymir-rut.md`](docs/ymir-rut.md) — the Rust re-forging spec
- [`AGENTS.md`](AGENTS.md) — Brokk's always-loaded operating contract

---

> *“A webhook hits Bifrost and is queued on Ratatoskr. Ymir allocates resources and
> launches Brokk. Brokk drinks from Mimirsbrunn, cuts a branch via Yggdrasil inside
> Svartalfaheim, and hands execution to an Eindri inside Utgard. Tests pass, Mjollnir
> raises the PR, the outcome is observed back into the well, Runes carves the entry,
> and Hlidskjalf renders the state.”*

*The bellows feed the flame; the smith reads the metal; the well remembers every blow.*

## What was wrought — 2026-09-14

One day, one loom. Everything below lives in this main and in the world:

- **The cloth** — Hlidskjalf, Smiðja and Sessrúmnir wear one carved look (stone,
  bronze, bone, blood; Cormorant · Newsreader · IBM Plex Mono); Smiðja's default
  theme is **Fensalir**; text highlighting is carved amber — the blue is dead.
- **Óðrerir, the Live Hall** — the landing's live board: a dealt slate pile, a
  carved ledger (underway · landed · charted), and a planning glass fed by real
  machine state. See it at the landing repo: `zerwiz/ymir-homepage` (local:
  `:4321`), with the `To the Hall` rune in every app's chrome.
- **The wake bridge** — every smith's finish files a saga and wakes the
  primary; the echo-guard keeps the wire honest.
- **The mark** — recoloured into the cloth, and the anvil-bars bug found and
  fixed (the metal was always there; now it is seen).

The lore runs to **XXXI — The Weaving of the Halls**; the masterplan carries
the full day's ledger.

---

## With gratitude — the people we stand on

Ymir is a Norse shell over other people's excellent work. We did not build the
engines; we built the hall around them. Every project below is theirs, kept under
their own licence, and we are glad to name them. Go and look at what they made —
follow them, star them, learn from them.

| Project | Who made it | Licence | What it powers in Ymir |
|---|---|---|---|
| [treehouse](https://github.com/kunchenguid/treehouse) | kunchenguid | MIT | Yggdrasil — git worktrees |
| [sandcastle](https://github.com/mattpocock/sandcastle) | [Matt Pocock](https://www.youtube.com/@mattpocockuk) | MIT | Utgard — sealed sandboxes |
| [no-mistakes](https://github.com/kunchenguid/no-mistakes) | kunchenguid | MIT | the clean-PR gate |
| [pi](https://github.com/earendil-works/pi) | Earendil Works | MIT | the coding harness |
| [oh-my-pi](https://github.com/can1357/oh-my-pi) | can1357 | MIT | prior art for the pi surface |
| [hermes-agent](https://github.com/NousResearch/hermes-agent) | Nous Research | MIT | the Hermes worker runtime |
| [pi-desktop](https://github.com/FaqFirebase/pi-desktop) | FaqFirebase and the Pi Desktop contributors | Apache-2.0 | Sessrúmnir (our re-themed fork) |
| [A2A protocol](https://github.com/a2aproject/a2a) | the A2A project | Apache-2.0 | the agent-to-agent backbone |
| [firstmate](https://github.com/kunchenguid/firstmate) | kunchenguid | MIT | the fleet |
| [axi](https://github.com/kunchenguid/axi) | kunchenguid | MIT | agent-ergonomics principles |
| [lavish-axi](https://github.com/kunchenguid/lavish-axi) | kunchenguid | MIT | the HTML-artifact editor |
| [SkillOpt](https://github.com/zerwiz/SkillOpt) | zerwiz | MIT | **Gunnlöð** — skill optimization (trajectory-driven refinement) |

Their full licence texts are bundled in [THIRD-PARTY-LICENSES](THIRD-PARTY-LICENSES),
and their attribution in [NOTICE](NOTICE).
If we have benefited from your work and missed you here, tell us — we will fix it,
loudly.

Thank you all. The forge is hot because you lit it.

_Where a maker teaches on YouTube we link the channel — Matt Pocock's is
[youtube.com/@mattpocockuk](https://www.youtube.com/@mattpocockuk). If you make a
tutorial for a project we use, tell us and we will link yours too._

---

## GitHub

The public repository lives at **zerwiz/ymir** on GitHub:
[github.com/zerwiz/ymir](https://github.com/zerwiz/ymir).

- **Issues** — report bugs, request features, or ask questions.
- **Pull Requests** — all changes ship via PR; every PR requires
  explicit Allfather approval before merge. No force-pushes. No auto-merge.
- **Projects** — the board tracks every workstream across the hall.
- **Actions** — CI runs `bin/secret-guard.sh` and `bin/docs-guard.sh`
  on every push and PR. A violation blocks the build.

Your own login is always your own: **never** share a token, never
commit credentials, never use a shared account. All secrets are
resolved from `$YMIR_HOME/secrets/platform.env` at runtime.

---

## Install — the four doors

```bash
curl -fsSL https://raw.githubusercontent.com/zerwiz/ymir/main/install.sh | bash
npx @zerwiz/ymir install          # no global install
git clone https://github.com/zerwiz/ymir.git ~/Ymir && cd ~/Ymir && bin/ymir-install.sh
npm install -g @zerwiz/ymir       # the CLI, global
```

**Who can install this today — everyone.** The distro is public; the four
commands above are open, and the npm road is the smoothest: `npm i -g
@zerwiz/ymir` stands the platform and its four surfaces (Hlidskjalf, Óðrerir,
Sessrúmnir, Smíðja), and `ymir raise` lifts the hall. The ship is measured:
the seat wears the cloth of the halls — stone and bone, bronze and blood —
with no remnant of the fork it grew from.

**Install now.** The installer is honest about what it cannot do, and says so the installer is honest about what it cannot do, and says so rather
than pretending. Bring a Linux host (or let the Windows/macOS bootstraps give
you one — see *Bringing your own machine* above), and read what the installer
prints before you trust it.

The npm package carries the runtime's `bin/` scripts and the installer; every
`npm update -g @zerwiz/ymir` re-runs the same self-healing setup that provisions
prerequisites, engines, and the Hlidskjalf seat. `@zerwiz/*` are the app
packages (Hlidskjalf, Óðrerir, Sessrúmnir, Smíðja) — one per app.

Private data never touches npm — all user data lives at `$YMIR_HOME` (the hoard
at `hodd/` and the realms at `svartalfaheim/`) and syncs via the user's
**private** GitHub repo, never a public one.

### After it installs — the doors

`npm install -g @zerwiz/ymir` puts **two** commands on your PATH: `ymir` and
`ymir-install`. Everything else is a door on `ymir`, named for the figure whose
work it does — because a great many doors either open or they do not, and a name
that says whose hand is on it is the difference between guessing and knowing.

```
ymir                     first setup: the plan, then your word
ymir raise | lower       lift the hall, or lay it down
ymir hlidskjalf          the high seat's window
ymir smidja              the smithy's board (:8437) — build · start · stop · status
ymir sessrumnir          the seat-hall's window
ymir heimdall            the way in — your credential (status · set · github)
ymir invite              let someone else in — mint · list · revoke
ymir eir                 what stands, and mend what does not
ymir groa [migrate]      take the latest, and mend this home forward
ymir mimir · sense · plan
```

A name the law has not given a home still answers, once, and tells you the name
that has it: `ymir doctor` replies *the door is named `ymir eir` now*.

**A long hour says so, in its own voice.** The installer opens with the plan and,
when the work will take a while, tells you plainly:

```
◆ much moves   the halls are being stood up for the first time
      this hour is long, and nothing of yours is lost in it —
      roots come home, shapes are re-cut, names are set true again.
      Your patience is noted, and it is earned.
```

### The packages — what is on npm

Six names were published; five serve. The distro **depends on the four
surfaces**, so one command brings the whole platform — and each can be installed
alone if you want only that hall.

```
packages[5]{package,what,live}:
  "@zerwiz/ymir","the distro — the runtime, the doors, the installer, the plan","0.1.12"
  "@zerwiz/hlidskjalf","the high seat — the control plane, the gate and the landing","0.1.0"
  "@zerwiz/odrerir","the live hall — the board on :4322","0.1.0"
  "@zerwiz/smidja-factory","the smithy — the agent factory, its skills and the visualizer on :8437","0.1.1"
  "@zerwiz/sessrumnir","the seat-hall — the desktop where you speak with Brokk","0.1.9"
```

```bash
npm install -g @zerwiz/ymir          # the distro AND the four surfaces (dependencies)
npm install -g @zerwiz/hlidskjalf    # or one hall on its own
```

**Why the smithy's name is not `@zerwiz/smidja`.** It was published under that
name and the registry accepted it twice — `0.1.0`, then `0.1.1` — while serving
neither: the package document answered 404, the website 403, and a republish was
refused as *already published*. The name was retired and the smithy ships as
**`@zerwiz/smidja-factory`**, which resolves. A second look before publishing
costs less than explaining a name that never worked.

### Both shapes — a clone and a package are one tree

Ymir runs the same whether you **cloned** it or **installed** it from npm. The
apps are the difference, and only in where they live:

| | a clone | an npm install |
|---|---|---|
| the surfaces | `apps/hlidskjalf` · `odrerir` · `sessrumnir` · `smidja-factory` | `node_modules/@zerwiz/hlidskjalf` · `odrerir` · `sessrumnir` · `smidja-factory` |
| how they got there | the registry's `repo: apps/<path>` block clones each | declared as dependencies of the distro |

One resolver (`bin/app-lib.sh`) answers for both, so a script never has to care
which shape it woke in — and the same is true of the smithy (`bin/smidja-lib.sh`)
and of a desktop shell's runtime (`bin/electron-lib.sh`). The plan tells you which
surfaces are present, which are declared but not yet fetched, and which have no
package at all.

**Colour is for the eye, never for the pipe.** `bin/ymir-style.sh` renders in the
halls' own cloth — bone for words, bronze for what acts, steel for what stands,
blood for what is wrong — and only when a human is watching (a terminal, no
`NO_COLOR`). What a pipeline reads on stdout stays plain TOON.
