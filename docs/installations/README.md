# Installations — the engines and tools Ymir adopts

Extra installations beyond the base runtime. **Open-source first:** every entry
is a validated OSS project (or SDK) under a Norse shell, or a first-party tool the
agents drive. Keys live at `$YMIR_HOME/secrets/platform.env` — **never inline**.

See [`ymir-home.md`](ymir-home.md) for the `$YMIR_HOME` data layout and env var contract.

```
installations[15]{tool,role,oss,install,used_by}:
  "treehouse","worktree pool (Yggdrasil)","kunchenguid/treehouse","curl -fsSL https://kunchenguid.github.io/treehouse/install.sh | sh","yggdrasil.sh · Eindri workers"
  "sandcastle","sandbox engine (Utgard)","mattpocock/sandcastle","npm i @ai-hero/sandcastle","utgard.sh · einherjar-spawn"
  "no-mistakes","clean-PR gate (Mjollnir/Glitnir)","kunchenguid/no-mistakes","curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh | sh","mjollnir.sh (mode no-mistakes)"
  "hermes","worker agent runtime","NousResearch/hermes-agent","curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash","bin/hermes-ensure.sh"
  "opendesign","design engine (Hnoss)","nexu-io/open-design","od mcp install <agent>","skills/hnoss · design Eindri"
  "firecrawl","web crawl/scrape","firecrawl.dev","pip install firecrawl-py","skills/bragi (research/SEO)"
  "scrapy","optional scraper (large/custom crawls)","scrapy.org","pip install scrapy","skills/bragi (optional)"
  "browser-use","agentic browser","browser-use/browser-use","pip install browser-use","skills/bragi (publish/post)"
  "chrome-devtools","browser debugging","developer.chrome.com/docs/devtools","Chrome DevTools MCP / built-in","Sindri (developer craft)"
  "engdbram","the well (Mimirsbrunn) — module name is engram","engdbram","bin/prereq-ensure.sh engram (pip install --user engdbram; NOT the PyPI 'engram', which is a renderer)","bin/mimir-bridge.py · well"
  "mcp","MCP SDK (engram-mcp needs <2)","modelcontextprotocol","pip install --user --break-system-packages 'mcp<2'","engram MCP for all harnesses"
  "electron","desktop shell","electron","npm i -D electron@^33","apps/hlidskjalf/electron · scripts/electron.sh"
  "capacitor","mobile APK shell","capacitor","npm i @capacitor/core @capacitor/android @capacitor/cli","apps/hlidskjalf/android"
  "cloudflared","tunnel (Gjallarhorn)","cloudflare/cloudflared","(system package)","bin/gjallarhorn-tunnel.sh"
  "jdk17","Android build toolchain","Adoptium Temurin 17","user-space tarball → ~/.local/jdk-17","gradlew assembleDebug"
```

## Engine installs (one command)

```sh
bin/ymir-install.sh          # prereqs, tree, engines, hermes, sandbox, memory, loaders, services
```

`bin/ymir-install.sh` self-heals the fixable gaps (`engram`, `mcp<2`, `treehouse`,
`no-mistakes`, **Hermes**) and reports the system-level ones (`git`, `python3`,
`bun`, `docker`, `gh`). See [`../.agents/skills/galdr-ymirsystem/assets/installation.md`].

## Per-skill engines

- **Hnoss** (design) → **OpenDesign**: `od mcp install opencode` / `pi` / `hermes`.
- **Bragi** (marketing) → **Firecrawl** + **browser-use**:
  `pip install firecrawl-py browser-use`; `FIRECRAWL_API_KEY` in `.env.local`.
- **Sindri** (developer) → **Chrome DevTools** — for inspecting, profiling, and
  debugging the running app: [developer.chrome.com/docs/devtools](https://developer.chrome.com/docs/devtools)
  (Elements, Network, Performance, Sources, Console, Application, Lighthouse,
  and the Chrome DevTools **MCP** for agent-driven inspection).

## Mobile / desktop / tunnel

- **Capacitor** wraps the Hlidskjalf SPA into an Android APK
  (`apps/hlidskjalf/android`); rebuild with `./gradlew assembleDebug` (needs
  JDK 17 + Android SDK — see `docs/installations/`).
- **Electron** is the desktop shell (`scripts/electron.sh`).
- **cloudflared** exposes Hlidskjalf at your own hostname (`YMIR_TUNNEL_HOST`)
  (`bin/gjallarhorn-tunnel.sh`); cache purge needs `CLOUDFLARE_API_TOKEN`.

## Rules

1. **OSS first.** Adopt the validated engine; never rebuild what exists.
2. **Keys via env.** `FIRECRAWL_API_KEY`, `OD_API_TOKEN`, `CLOUDFLARE_API_TOKEN`,
   provider keys — `$YMIR_HOME/secrets/platform.env` only.
3. **No mock.** A tool reported present must be real; `bin/ymir-install.sh --check`
   tells the truth.
