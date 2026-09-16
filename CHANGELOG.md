# CHANGELOG

## 2026-09-16 — the changelog guard: no push ships untold

- **Every push carries a CHANGELOG entry.** `bin/changelog-guard.sh` installs a
  pre-push hook that reads the refs git hands it, resolves the range being
  pushed, and refuses the push when `CHANGELOG.md` is untouched in that range.
  A change that ships is a change that was told; the record can no longer lag
  silently behind the code.
- **Rule 08 extracted and versioned.** The protected-branch check that lived
  only inside the ad-hoc `.git/hooks/pre-push` is now `bin/branch-guard.sh`, so
  the delivery gate is reproducible: `bin/changelog-guard.sh --install` writes
  the pre-push that runs both guards.
- **Escape hatch, deliberate and loud.** `YMIR_SKIP_CHANGELOG_GUARD=1 git push`
  when an entry truly does not belong.
- Checks by hand: `bin/changelog-guard.sh --range A..B`,
  `bin/branch-guard.sh --branch main`.

## 2026-09-16 — Apodex seat verified; the Weave mended

- **Correction (cites the entry below, never rewrites it).** The earlier
  entry said *"LM Studio is retired; its :1234 port belongs to Apodex now."*
  That was false as carved. LM Studio still holds `:1234` and is what serves
  the Apodex GGUF; Apodex took the **model seat**, not the server.
- **Live verification.** `bin/apodex-smoke-test.sh` → PASS (valid tool-capable
  response, exit 0). `bin/huginn-research-worker.sh` with **bare defaults** →
  `status: completed`, verdict written, observed into Mimirsbrunn. The Apodex
  seat (`http://127.0.0.1:1234/v1`) is live.
- **One model id, everywhere.** The seat serves **`apodex-1.0-mini`**; the
  worker, smoke test, `.env.example`, `opencode.json`, `config/agents.yaml.example`
  and Huginn's profile now all say so. Previously three names drifted
  (`apodex/Apodex-1.0-mini-Q4_K_M`, `apodex/apodex-mini-q4`, the served id) and
  the default worker call failed with `No models loaded`.
- **Four defects mended.** `bin/huginn-research-worker.sh` made executable
  (was 644 — bare invocation died with `Permission denied`); the smoke test's
  `--serve` GGUF path corrected to
  `~/Models/FlameF0X/Apodex-1.0-mini-Q4_K_M-GGUF/apodex-1.0-mini-q4_k_m.gguf`;
  `bin/models-detect.sh` env var renamed from the typo `APEDEX_URL` to
  `APODEX_URL`.
- **Weight truth.** The Apodex Q4_K_M weights are **21.7 GB**, not the ~4–6 GB
  the plan assumed — it cannot sit beside a coding model. `AGENTS.md` now says
  so: one local model at a time, by weight.
- **Smiðja relocated.** `.agents/skills/smidja-factory` is now a symlink to the
  app tree at `apps/smidja-factory/`, which is where the smithy's real files
  live (Amendment A/C of the Apodex plan).
- Plan (private hoard): `$YMIR_HOME/docs/plans/apodex-integration-into-ymir.md`
  — Amendment E records the live pass, the mended defects, and the one open
  item: the herdr-seat verification (Phase 3), which needs a spawn.

## 2026-09-16 — Apodex joins the Weave (research/planning provider)

- **Apodex provider.** Apodex-1.0-mini-Q4_K_M climbs into the machine as
  the research/planning GGUF on `http://127.0.0.1:1234/v1`, seated
  alongside llama.cpp coding models on :8080. LM Studio is retired; its
  :1234 port belongs to Apodex now.
- **Env template.** `.env.example` gains the `APODEX_*` block; the LM
  Studio block is marked RETIRED with its port claim corrected.
- **Smoke test.** `bin/apodex-smoke-test.sh` — probe or serve-and-test an
  Apodex seat; exits 0=pass, 1=fail, 2=unavailable. Never mutates config.
- **Research worker.** `bin/huginn-research-worker.sh` (Apodex-powered
  Eindri): takes a brief, recalls from Mimirsbrunn, dispatches to the
  Apodex chat/completions seat, writes a structured verdict, observes it
  back into the well. Wears the name **Huginn** per the naming law (the
  research seat; Gungnir stays the skill-synthesis engine).
- **Agents hall.** `.agents/agents/huginn-researcher.md` binds Huginn to
  the apodex model; `config/agents.yaml.example` registers the apodex
  provider and Huginn's seat; `opencode.json` carries the apodex provider
  block alongside llama.cpp; `bin/models-detect.sh` probes and emits the
  apodex provider for the Pi model file (`~/.pi/agent/models.json`).
- **Install seams.** Apodex rides the existing seams: models-detect merges
  it into the Pi models file at install; agents-config applies it into
  opencode.json. Model provider selection documented in AGENTS.md
  (`## Model Provider Selection`), Apache 2.0 licence noted.

## 2026-09-16 — Gunnlöð joins the hall (SkillOpt integration)

- **SkillOpt integration.** `pip install skillopt` into `.venv/`; training
  loop (`skillopt-train`), eval (`skillopt-eval`), and nightly
  self-evolution (`skillopt-sleep`) available for Smíðja prompts and
  Ymir skills. Nightly Nornir job at 00:30 (bin/nornir-job-skillopt-sleep.sh),
  staged artifacts only — Allfather approves before adopt. One-time setup:
  `bin/skillopt-setup.sh`.
- **Naming.** SkillOpt adopted the name **Gunnlöð** (keeper of the mead of
  poetry — distills trajectories into refined skill artifacts). Added to
  `.agents/assets/agents/naming.md` (platform map, 28 subsystems),
  `.agents/skills/galdr-ymirsystem/assets/registry.md` (skills + external tools),
  `README.md` (System Map + Skills + gratitude), `NOTICE` (MIT attribution).

## 2026-09-13 — the imported names leave the halls (Norse naming purge)

- **"firstmate" retargeted to Ymir's own names across every Ymir-owned surface.**
  The upstream distro's nautical vocabulary is gone from the docs, skills, `bin/`,
  config, and the Hlidskjalf review copy: `firstmate` → **Brokk**, `secondmate` →
  **Eindri-home**, `crew`/`crewmate` → **Eindri**, `captain` → **Allfather**
  (`docs/lore.md`, `docs/Architecture.md`, `.agents/agents/brokk.md`,
  `.agents/skills/herdr-panes/assets/{herdr,tmux}-backend.md`,
  `.agents/skills/eindri-homes/assets/control-plane.md`,
  `.agents/skills/saga-bearings/assets/board-template.html`,
  `.agents/skills/ymir-host/assets/thjazi.md`, `bin/README.md`,
  `apps/hlidskjalf/**`).
- **Engine literals kept.** Every real upstream identifier stays verbatim — the
  Herdr labels (`firstmate`, `2ndmate-<id>`, `firstmate-<id>`), the home marker
  `.fm-secondmate-home`, the envelope `FIRSTMATE_OP: ` and `[fm-from-firstmate]`,
  and all `FM_*`/`fm-*` names — because `.agents/backend/` (the vendored engine)
  and `assets/reference/` (provenance) are untouched.
- **Licensing.** `NOTICE` now records the upstream **firstmate** distro
  (`github.com/kunchenguid/firstmate`, MIT, © kunchenguid) and a README "Built on"
  section points to it; the MIT copyright/permission notice is retained.
- **Governed asset:** `galdr-ymirsystem/assets/hlidskjalf-ui.md` records the Allfather
  review copy in the same change. `compliance-check.sh` 10/10 PASS.

## 2026-09-13 — The realm seat, carved (wayof)

- **Problem:** the realm tree was bare (only the shipped example), no tenant
  was seated, and the session digest resolved the Allfather's realm to
  `default` — his company and private holdings unreachable by the map.
- **Seat:** `svartalfaheim/wayof/` carved from the example — `.env.realm`,
  `SECRETS.md`, `AGENTS.md` (persona), `domains/`, `projects/`, the five
  workspace branches, and the 9 company cards seeded from the identity hoard
  (askr · brokkforge · dvalin · mannheim · muninn · runestone · utgard · wayof ·
  ymirlabs), realm field unified to `wayof`, repo paths corrected to this
  machine. `data/realm.md` now pins `wayof` (was drifting between `way-of`,
  `wayof`, and `default`; hoard cards + persona updated to match).
- **Hood:** `svartalfaheim/wayof/HOOD.md` is the map of the hoard and the
  seat; `bin/saga-session-start.sh` stage 6 (context digest) now prints
  `--- hood ---` whole from the realm seat, so a session opens knowing the
  operator's holdings. Living overviews: `workspace/company/wayof-overview.md`
  and `workspace/company/aigf.md` (hodd stays the private store; the realm
  points at it).
- **Verified:** `bash -n` green; realm-lib resolves `wayof`; `realm env:
  present`.

## 2026-09-13 — Gleipnir sees when an agent is turned off

- **Problem:** the machine lock stuck “held by another Brokk session” forever.
  Nothing released it ( `gleipnir_lock_release` had zero callers; Pi's exit
  hook only stopped the arm child), and liveness was `kill(0)` alone — which
  reports a zombie (dead but unreaped) and a recycled pid as alive, so an
  agent you turned off kept the helm until its pid happened to look gone.
  Worse, the Sessrúmnir desktop RPC session holds the live lock yet never
  arms supervision (no turn ever calls `gna_watch_arm`), stranding every
  other session read-only.
- **Fix:** `bin/gleipnir-lock-lib.sh` now records the owner's starttime in a
  `brokk.lock.starttime` sidecar and reaps a holder whose `/proc/<pid>/stat`
  state is `Z`/`X` or whose starttime no longer matches (pid reuse) — dead,
  zombie, and recycled holders are cleared at session start/acquire. Gná
  (`gna-pi-watch.ts`) mirrors that liveness, reclaims a stale lock directly in
  `gna_watch_arm` (`missing` no longer punts to saga-session-start.sh), and
  drops its own lock on real process exit (`releaseLockIfOwned`); the turn-end
  guard (`syn-turnend-guard.ts`) uses the same zombie-aware check.
- **Impact:** turning an agent off — cleanly, by kill (zombie), or after pid
  reuse — frees the machine lock for the next session. The live desktop seat
  still holds it until that app is closed or its own session arms; that is the
  law (one live primary per machine), but it now releases and hands off
  correctly.
## 2026-09-13 — the cloth reaches all three halls (Hlidskjalf · Smíðja · the seat)

- **One look, one source.** The carved cloth (the landing page's `:root`) now
  dresses every hall, each through its own thin adapter, and `docs/design.md`
  gained §0 *The cloth* plus the re-cut §4.1/§4.2 tables — the contract, not a
  wish. `midgard/design-system/tokens.css` keeps every `--ymir-*` **name** and
  changes only the values: stone `#0e0c09`/`#151209`/`#1a1610`/`#221d14`, bone
  text `#cfc3a9`/`#9a8f75`/`#6b6250`, bronze `#c9973f` accent with `#7d5f2a` as
  the brass rule, blood `#c2584a` danger, steel `#96a0a8` ok, brass bevel
  `inset 0 0 0 1px rgba(201,151,79,.12)`.
- **Type.** Cormorant (display), Newsreader (body), IBM Plex Mono (data) — the
  landing's three faces — with Noto Sans Runic appended to every stack so runes
  fall through to the rune family. Hlidskjalf loads them from Google Fonts; the
  visualizer bundles them from `@fontsource` (its `@fontsource/play` is gone).
- **Hlidskjalf:** 24 old-palette `rgba()` literals and every role hex in the
  stylesheets now read tokens (`color-mix(… var(--ymir-ok) …)`); workspace tints
  are cloth (work bronze, personal steel); the `HallsChooser` cards no longer name
  two tokens that never existed (`--ymir-line`/`--ymir-panel`); the login's GitHub
  button is a bone plate; the realm-tint fallbacks in `global.css` follow.
- **Smíðja's eye:** the default theme is **fensalir** (the titlebar toggle cycles
  fensalir → classic → high-contrast, both overrides still winning); 77 hexes and
  62 `rgba()`s across the components were recast onto the theme's own tokens; the
  categorical event/lane palettes (`src/lib/events.ts`) were re-cut onto the cloth
  while staying mutually distinct.
- **Sessrúmnir:** text selection is now a **theme token**
  (`--color-selection-bg`/`-fg`) — the landing's amber `#57411a` on pale bone
  `#f0e6cd` — carried in `fensalir`/`sessrumnir` and derived per theme for
  everyone else; the global rule sits in `@layer base`, and the CodeMirror editor
  needs a second unlayered rule because CodeMirror paints its selection layer with
  unlayered CSS that beats any layered rule. A **To the Hall** button joins the
  status bar (local `:4322` when it answers, else `hall.ymir.zerw.org`, resolved in
  the main process).
- **Heraldry is not chrome:** the eight house/domain seals and the Emblem keep
  their own colours — exactly as the landing page keeps its house seals.
- **Geometry is untouched** (radius, spacing, the shell): the carved-slate
  squaring remains an open question for the Allfather.
- **Verified:** `tsc` clean and `npm run build` green in Hlidskjalf; the
  visualizer builds under `vue-tsc`; Sessrúmnir's build, lint, theme tests and
  semantic-colour check green. Headless passes: Hlidskjalf's gates render with
  **0 console errors** (login, fleet, tasks, processes, reviews, runtime, cron,
  stats), and the visualizer loads with 0 console problems.

## 2026-09-13 — the carved cloth reaches the seat-hall (Sessrúmnir)

- **The landing's cloth is now the seat's own look.** Every semantic token in
  `apps/sessrumnir/src/renderer/src/index.css` `@theme` was mapped to its carved
  twin from the landing page's `:root` (`CodeP/ymir-homepage/src/lore.html`):
  stone `#0e0c09` (app) with panels `#151209`/`#1a1610`/`#14100b`, bone text
  `#cfc3a9`/`#9a8f75`/`#6b6250` (faint/ghost as bone washes), bronze
  `#c9973f` accent and `#7d5f2a` brass rule for `border-strong`, blood
  `#c2584a`/`#7c3a30` for error, steel `#96a0a8` for success. Semantic names are
  unchanged — only the values moved.
- **Fensalir** (the weaving halls) is registered as a built-in theme
  (`themes/fensalir.json`, id `fensalir`, appended to `BUILTIN_THEME_IDS` — an
  additive change that keeps every persisted id resolving). The seat's own
  built-in `sessrumnir` theme was carved to the same cloth, so the default look
  of an existing profile is the cloth on restart. A new test holds the two
  together (`the cloth is one`) and another holds the CSS `@theme` base to the
  theme file (`never drift`).
- **Cloth is the default, not a cage:** the ThemeEngine's ordering is untouched —
  every other built-in theme, any user theme, and `high-contrast` still win when
  chosen.
- **Type:** Cormorant (display), Newsreader (body), IBM Plex Mono (mono) bundled
  from `@fontsource*` (offline, `font-src 'self'`), with Inter/JetBrains Mono
  kept as glyph fallbacks; the landing's carved syntax palette (`--cm-*`) rides
  along in the theme files.
- **Honest repairs on the way:** 29 raw `text-white` literals sat on token
  fills where white cannot be read on bronze (2.6:1). They now read the token
  that means "the rune on the filled plate" — `text-inverse` on `bg-accent`,
  `text-primary` on the dark blood `bg-error` — and the settings toggle knob is
  carved (stone when lit, bone when unlit). No colour literals remain in
  components.
- **Paper:** `apps/sessrumnir/AGENTS.md` and `README.md` no longer claim the old
  sky-on-navy palette; they describe the cloth and its rules.

## 2026-09-13 — the new tree, the mesh, the seat-hall

- **Everything in the new tree:** the Sessrúmnir work plus the orphaned fixes
  were migrated from the `ymir-old` working tree into this canonical tree —
  `apps/sessrumnir/` (deps vendored locally, never committed), the two
  `bin/sessrumnir-*.sh` scripts, `step_sessrumnir` in `bin/ymir-install.sh`,
  the Hoard registry entry, the `installation.md` asset, and the
  `syn-watch-arm.js` continuity fix (re-arm when `.supervision-armed` exists
  even with no task metadata). The superseded self-service register-gate work
  was **not** ported — this tree's committed invite-gate is canonical.
- **Full install ran green** in the new tree: every step OK, invite minted
  (`YMIR-DBN4-FXEX`), all five services up, `bin/ymir-validate.sh` 11/11 PASS.
- **Ratatoskr mesh healed:** the `a2abridge` engine (MIT,
  `vbcherepanov/a2abridge` v3.0.0) is installed at `~/.a2abridge/bin/`, its
  directory daemon runs on `127.0.0.1:7777`, and `bin/ratatoskr.sh
  status|doctor` pass. Forged `bin/a2abridge-ensure.sh` (installs the engine,
  patches the systemd unit's unwritable `/var/log` log paths to journal,
  keeps the directory up) and wired it into migration `0002-a2a-mcp.sh`, so
  every install/update heals the mesh instead of leaving a dangling MCP path.
- **MCP bridges fixed:** `engram-mcp` failed at startup (its Python env
  lacked the `mcp` SDK; mcp 2.x renamed FastMCP, so it is pinned to `mcp<2`)
  — the server now initializes against the `kaia.engram` store. `a2abridge`
  MCP is wired into both pi and opencode via `bin/a2a-mcp.sh install`.
- **Docs:** `docs/design.md` §5.4 documents the gate exactly as committed
  (operator credential + invite-gated registration + GitHub door + httpOnly
  30-day session); the hlidskjalf-ui skill gained the `register` surface row.

## 2026-09-13 — Sessrúmnir, the seat-hall

- **Sessrúmnir adopted:** the Apache-2.0 **pi-desktop** GUI
  (`FaqFirebase/pi-desktop`, v0.1.7-alpha) is vendored at `apps/sessrumnir/`
  and rebranded **Sessrúmnir** — the seat-hall where the Allfather converses
  with the machine. The external engine keeps its product name; the GUI the
  user sees is Sessrúmnir, themed with the way-of palette (sky `#38bdf8` on
  deep navy) as the new default built-in theme. Window titles, launcher,
  package identity, tray/autostart strings, data-dir name, and the Pi logo
  (now a Sowilo rune bolt) are rebranded; upstream `LICENSE` is preserved and
  `NOTICE` records the adoption.
- **Forge scripts:** `bin/sessrumnir-ensure.sh` (status/ensure/install — deps
  are never committed, installed on first run with the electron-binary heal
  `scripts/electron.sh` already uses) and `bin/sessrumnir.sh`
  (start/status/stop with a workspace argument).
- **Install wiring:** `bin/ymir-install.sh` gains a `sessrumnir` step (after
  `hermes`) and lists Sessrúmnir in `workspace/INSTALL.md`; the
  `installation.md` asset's step table, adopted-engines table, and Hermes-style
  section are updated in the same change.
- **Registry & audit:** the Hoard registry (`hodd/identity/projects.yaml`)
  gains the `sessrumnir` project (upstream remote); the adoption is inscribed
  in Runes.
- **Not yet installed:** `apps/sessrumnir/node_modules` is absent — run
  `bin/sessrumnir-ensure.sh install` when ready.

### 2026-09-13 — the seat-hall raised

- `bin/sessrumnir-ensure.sh install` completed: deps + Electron binary + build
  all green; full test suite **989/989 pass**, typecheck and lint clean (the
  `autostart-linux` test was updated for the new brand name). `bin/sessrumnir.sh
  start` raised the window — Hyprland reports class `sessrumnir`, title
  `Sessrúmnir`, data under `~/.config/sessrumnir`.

## 2026-09-12 — The well actually installs (it never did)

- **The memory engine was never installed by the installer.** `bin/prereq-ensure.sh`
  had no `engram` target at all, and `bin/ymir-install.sh` only *checked* for it
  and printed `SKIP "optional — install engine then run bin/mimir-bridge.sh"`. A
  SKIP never blocks, so the well was silently down on every install.
- **The hint named the wrong package.** PyPI's `engram` is an unrelated
  *rendering* library (mitsuba/drjit/torch): following the hint pulled gigabytes
  of CUDA wheels and still left no engine. The memory engine's distribution is
  **`engdbram`**; its module is `engram`. The pre-swap append-only log had the
  right answer all along (`PyPI engdbram, v2.2.1`).
- **Now it installs.** `prereq-ensure.sh engram` installs `engdbram` into an
  interpreter that can run it (>=3.11; uv supplies 3.12 here), records that
  interpreter in `~/.config/ymir/engram-python`, and `bin/mimir-bridge.sh` reuses
  it for both the check and the run. The installer provisions rather than hints,
  and reports WARN instead of a silent SKIP when it cannot.
- **Verified:** `curl 127.0.0.1:4602/health` -> `{"status": "up", "store":
  ".agents/memory/kaia.engram"}`; `.agents/skills/lifecycle/smoke_test.sh` exits 0
  with all five checks green.

## 2026-09-12 — The dashboards stop crash-looping on the iGPU

- **`scripts/electron.sh` decides its own GPU path.** Both dashboards appeared to
  work while `coredumpctl` filled with SIGSEGV cores from
  `electron --type=gpu-process`. An iGPU backs its graphics memory with system
  RAM (GTT), a local model served on that same iGPU held 5.8-8.0 GiB of it, and
  the amdgpu driver then failed the desktop's command submissions — which
  Electron turned into a NULL dereference at a constant offset. Only the GPU
  process died, so the windows stayed up and the failure was easy to miss.
  `igpu_vram_small()` now reads the render device's VRAM carve-out and switches
  to software rendering under `YMIR_IGPU_VRAM_SMALL_MIB` (default 2048). The old
  comment promised this auto-detect; now it exists. `YMIR_DESKTOP_DISABLE_GPU`
  still overrides, both ways.
- **Verified:** with the fix, the amdgpu submission errors stop and the
  gpu-process runs SwiftShader (`--use-angle=swiftshader-webgl`) rather than the
  hardware path; no new cores.

## 2026-09-12 — The editor keeps its own seat

- **`open-editor.ts` seats the editor in Þjazi:** inside herdr, `/edit` and
  `ctrl+shift+e` now open the Allfather's editor in its **own tab** of the home
  workspace (`herdr tab create --focus` + `herdr pane run`, label
  `ymir:edit[:<base>]`, recorded in `state/herdr-seats` for `close-all`) instead
  of suspending the pi session — the agent no longer dies when the editor
  opens. Outside herdr the old roads remain: GUI editors launch detached,
  terminal editors suspend the TUI and resume on exit.
- **`open-editor.ts` shows hidden files:** the picker and `/edit`
  tab-completion now merge the git listing with a bounded walk, so gitignored
  dotfiles (`.env.local`, `.env.realm`, …) are openable too.

## 2026-09-11 — Omarchy-first: host skills, machine learning, native fixes

- **New skill `ymir-omarchy`:** Omarchy-native operation — the two laws (never
  edit `/usr/share/omarchy/`; Hyprland owns placement), host detection, the
  monitor/scale coordinate trap, the amdgpu GPU crash and mitigation, desktop-app
  placement, and a safe-customisation table.
- **New skill `ymir-thjazi`:** Þjazi (herdr-first) — protocol floors (14+ panes,
  0.8.0 presentation spaces), verification, installation.
- **Ymir learns the host:** `bin/omarchy-sense.sh` snapshots and *diffs* the
  machine (Omarchy version, explicit packages, config files, monitors, scale) into
  `state/omarchy-setup.json`; `bin/omarchy-hook-install.sh` adds an Omarchy
  `post-update` hook so it re-learns after every `omarchy update`.
- **Þjazi in the installer:** `bin/herdr-ensure.sh` + new `step_backend`
  (herdr, else tmux — never a silent fallback).
- **New `step_omarchy`** (SKIP on a non-Omarchy host).
- **Desktop fixes:** window placement is now LOGICAL and work-area clamped, and
  prefers a non-primary display (the old math used physical pixels on a scale-1.5
  panel and filled the screen). Apps are identified by their command line, not the
  `.bin/electron` shim pid — which fixes the **double-launch** bug. `stop` kills
  every matching pid.
- **GPU mitigation:** `YMIR_DESKTOP_DISABLE_GPU=1` adds
  `--disable-gpu --disable-gpu-compositing` for small-VRAM iGPUs (the crash was
  `amdgpu: Not enough memory for command submission`, SIGSEGV, not an OOM).
- **Per-machine state un-shared:** `.agents/memory/kaia.engram*` and
  `well/*.jsonl` were tracked and pushed (one machine's private memory + volatile
  SQLite sidecars). Now gitignored and untracked; the contract is written in
  `.agents/memory/README.md`.
- **Assets updated:** `installation.md` (15 rows, consent, validation, Omarchy),
  `hlidskjalf-ui.md` (the desktop-apps section).
- **Verified:** full install green (15 rows; only the docker-group WARN), 9/9
  compliance, both skills registered.

## 2026-09-11 — Load the owning asset before editing a governed path (5 layers)

The runtime drifted from its documentation because the asset that governs a
subsystem was never loaded before the code changed. Five layers now prevent it:

- **1. `AGENTS.md`:** a new `governed[6]` table maps each governed path to the
  asset to load first, and `manual[]` gained `installation`, `ui`, `runtime-spec`.
- **2. Session digest:** `saga-session-start.sh` prints an `ASSET ROUTING` block
  every session, so the mapping is always in context.
- **3. Router loadable:** `galdr`'s `disable-model-invocation` is removed (it hid
  the one router that owns the assets); `tyr-check` keeps it (deliberate).
- **4. Enforced seatbelt:** new `bin/syn-asset-pretool-check.sh` denies an
  `edit`/`write` of a governed path until its asset was read (`state/asset-reads`);
  the Pi extension relays it and records asset reads.
- **5. Compliance gate:** `compliance-check.sh` gains an `assets` check that
  FAILS when a governed path changed without its asset (it caught this very
  change), and `runtime-compliance.md` documents G12 + the routing map.

## 2026-09-11 — Automate the install: consent gate, self-healing prereqs, visualizer-ready

- **Consent gate:** a real install now prints its plan and waits for the operator
  to accept (`[y/N]`). Declining changes nothing (exit 3). `--check` still previews
  without asking; non-interactive callers must pass `--yes`.
- **New `bin/prereq-ensure.sh`:** self-healing prerequisites in USER SPACE —
  installs `bun` and `uv` via their official installers, `mcp<2>` via pip, and can
  fetch a specific Python (e.g. `3.12`) with uv for packages that need one.
- **New `bin/smidja-bootstrap.sh`:** creates `smidja/smidja_data/smidja.db` from
  the tracer's own schema and seeds a bootstrap session, so the Smíðja visualizer
  has data from the first install. Fixed: it now bootstraps on a bare call
  instead of printing help, and reports failure honestly when the DB is absent.
- **`bin/ymir-install.sh`:** new `smidja` step; prerequisites delegated to the
  self-healing helper; `engram` reported as an honest optional `SKIP` with the
  exact next command; docker-group-permission and build-failure distinguished.
- **Verified:** consent refuse/accept/decline paths; smidja db created and read
  back (8 tables, bootstrap session); compliance 8/8.

## 2026-09-11 — Smooth install: provider choice, no forced key, real prereqs

- **Model provider is now the operator's choice** (`YMIR_MODEL_PROVIDER`):
  `opencode-go` (needs a key), `lmstudio` (keyless local), or
  `openai-compatible`. The bridge no longer forces `OPENCODE_GO_API_KEY`;
  with no key it auto-selects the keyless local provider so a fresh install works.
- **New:** `.agents/backend/model-bridge.py` (provider-aware, keyless-capable);
  `opencode-go-bridge.py` kept as a delegating shim so existing references work.
- **`bin/bifrost-bridge.sh` v2:** `--provider`, provider auto-selection, no hard
  env-file requirement, actionable errors per provider.
- **`bin/ymir-install.sh`:** installs `bun` for real (user-space, then a package
  hint); installs `mcp<2`; `engram` is now an honest `SKIP` with the Python
  version reason instead of a permanent WARN; distinguishes docker-group
  permission from a build failure.
- **`scripts/start.sh`:** fixed the early exit that skipped the gate API and all
  services whenever the SPA was already running.
- **Verified:** compliance 8/8; bridge relays models + chat + 404s; keyless
  start confirmed; `start.sh` raises Gate API, Nornir, Bifrost, visualizer.

## 2026-09-11 — Single-tenant workspaces shipped

- **First setup:** `bin/ymir-install.sh` (8 steps) + `bin/workspace-provision.sh`.
- **Model:** single tenant; workspaces (personal|work) over domains; houses = brands.
- **UI:** Login onboarding (name/kind/domains), Topbar workspace chip, AccountMenu/Profile relabelled.
- **Engines:** treehouse → `yggdrasil.sh pool`; sandcastle → `utgard.sh sandcastle`; no-mistakes → Mjollnir gate.
- **GitHub:** `bin/project-git.sh` reads `workspace/projects.yaml` `git{}`.
- **Verified:** build green, compliance 8/8, smoke 8/8, lint 4/4.


All significant runtime, policy, and architectural changes for the Ymir platform.
Entries are appended chronologically; never rewritten.

## 2026-09-11 — Hardcoded per-page feeds (header + stream)

- **New:** every gate has its own hardcoded, domain-appropriate rolling feed
  (16 pools, `src/data/feeds.ts`) — Fleet, Tasks, Well, Runes, Reviews,
  Processes (Valhalla), Files, Chat, Forge, Runtime, Cron, Sessions, Trace,
  Decisions, Stats, Profile. Extra Kaia “oracle by the well” lines for the chat
  page.
- **Header:** a live `PageFeed` now sits in the page header of every gate
  (glyph + hint on the left, the current page's latest 3 messages on the
  right), rolling.
- **Stream:** the bottom Stream keeps each page's last **40** domain messages,
  with the fleet-wide feed as fallback. A generator tops it up every 2.4s and
  the page is seeded on first visit so it is never cold.
- **Verified:** `tsc` + `vite build` green, SPA 200, compliance 8/8, smoke 8/8,
  lint 4/4.

## 2026-09-11 — Per-page rolling 40 message feeds

- **Change:** the bottom stream is no longer one global 120-line feed. Every gate
  keeps its own rolling window of the **last 40** messages, and events are routed
  to the page they belong to (module → gate: `well`, `sessions`, `forge`,
  `runes`, `cron`, `reviews`, `processes`), with the fleet-wide feed as fallback.
  The stream header shows the current page. `STREAM_WINDOW = 40`, matching the
  chat's `CHAT_WINDOW = 40`.
- **Verified:** `tsc` + `vite build` green, SPA 200.

## 2026-09-11 — Galdr/Tyr assets: symlink, not copies

- **Fix:** `tyr-check/assets` is now a **symlink** to the canonical
  `galdr/assets`, so the two can never drift. A background process had been
  rewriting the registry, flipping the sync gate red; a symlink makes drift
  structurally impossible. Compliance back to 8/8 stable.
- **Verified:** compliance 8/8, smoke 8/8, lint 4/4.

## 2026-09-11 — Chat uses the root Pi model catalog

- **Fix:** the Kaia chat guessed a llama.cpp model id by regex and fell through
  to the Bifrost bridge (`:4603` → 401) when the guess failed.
- **Now:** the gate API reads the operator's root Pi catalog
  (`~/.pi/agent/models.json`) for the exact provider → base URL, model id, and
  key (llama.cpp router `:8080`, `sk-not-key-required`). A chosen local model
  is tried only on its own base; the default is the operator's Pi default
  (`qwen3.6-35b-a3b@iq3_s`). `/api/chat/models` lists the real connected set.
- **Verified:** `gemma-4-12b@q3_k_s`, `qwen3.6-35b-a3b@iq3_s` (default), and
  `qwen3.5-9b@q4_k_s` all answered live; no 401.

## 2026-09-11 — Shared well for every harness; no mock; clickable memories

- **Harnesses:** the engram MCP server is now registered for all four OpenCode
  accounts (`opencode`, `opencode-rd`, `opencode-work`, `opencode-oczer`), Pi
  (`~/.pi/agent/settings.json` + `mcp.json` + `.pi/mcp.json`), Claude, Cursor,
  and Codex. Registered **unscoped** so every harness reads the one shared well
  (per-call `agent_id` still attributes writes).
- **No mock:** purged every test/mock episode (`smoke`/`Test observation`) from
  both the engram store and `episodes.jsonl` → 367 true episodes. Test writes
  never enter the well.
- **UI:** Well memories are now **clickable** — `GET /api/well/episode?id=` and
  a bridge `/episode` endpoint feed a modal with the full memory text.
- **Bridge fix:** `/recent` and `/recall` restored; added `/episode`.
- **Lifecycle fix:** `bifrost-bridge.sh` / `mimir-bridge.sh` now stop by process
  match when the PID file is missing, and record the PID when the port is
  already up — so `scripts/stop.sh` truly lowers the whole system and
  `scripts/start.sh` truly raises it.
- **Galdr:** new asset `.agents/skills/galdr-ymirsystem/assets/memory-well.md` (store,
  bridge, MCP, harness matrix, laws, verify), routed in `SKILL.md`; registry +
  harness README updated; mirrored to tyr.
- **Verified:** MCP recall 1.0 / stats 367, full stop→start cycle (3888/3889/
  4602/4603/8437), compliance 8/8, smoke 8/8.

## 2026-09-11 — The well is real (Mimirsbrunn / engram)

- **New:** `bin/mimir-bridge.py` + `bin/mimir-bridge.sh` — the `:4602` HTTP face
  the supervision tree named but that upstream never shipped (engram exposes a
  CLI + MCP server only). Endpoints: `/health`, `/recall`, `/recent`,
  `/timeline`, `/inspect`, `/observe`.
- **New:** repo-local store `.agents/memory/kaia.engram`, seeded from the
  368-episode JSONL well.
- **Wired:** gate API `/api/well` now does semantic recall via the bridge (local
  file fallback) and `/api/mimir/health` is live; the Well gate's Bridge tile
  and timeline read real data (mock removed).
- **Harnesses:** the engram MCP server is registered for OpenCode, Pi, Claude,
  Cursor, and Codex; requires the `mcp<2` SDK (`engram-mcp` breaks on mcp 2.x).
- **Lifecycle:** the bridge is raised by `scripts/start.sh` and
  `bin/saga-session-start.sh`; the stale `engram.server` command was corrected.
- **Verified:** bridge up (370 episodes), semantic recall, MCP handshake
  (engram 1.30), compliance 8/8, smoke 8/8.

## 2026-09-11 — Stats 1:1, Kaia chat, Forge prompts

- **Stats:** ported the full Smiðja `StatsResponse` 1:1 into the gate API and
  the Stats gate — runs/success/fail/running/rate, token optimization
  (input/output/cache_read/cache_write, cache-hit ratio, avg CHR/run),
  local-vs-online provider split with per-model table, 40-model commercial
  catalog (cached/total/savings/%), by-chain and by-workflow. A real run
  renders live.
- **Chat (Kaia):** per-session JSONL store (`state/chat/`), list/history/delete
  endpoints, a rolling **40-message** window, query-grounded well recall before
  every dispatch, an animated "Kaia is thinking…" indicator, a session sidebar
  (new/switch/delete), a connected-model datalist (314 models) with free-type,
  and Eindri lane toggles.
- **Forge:** a Prompts mode to read/edit the smithy's
  `prompt_engineering/<agent>/{system,user}.md` (path-guarded save) and a
  connected-model datalist for agent models.
- **Verified:** `tsc` + `vite build` green, live chat via local model with
  recall on, prompt roundtrip + traversal guard, compliance 8/8, smoke 8/8,
  lint 4/4.

## 2026-09-11 — Smiðja views are repo-local

- **Change:** Removed the last external dependency. `bin/factory-observe.sh`
  (which defaulted to `~/command/factory/factory_data/factory.db`) is gone;
  `bin/smidja-observe.sh` reads the repo's own
  `smidja/smidja_data/smidja.db` read-only and reports absence honestly.
- **API:** `/api/factory` replaced by `/api/smidja/{health,sessions,sessions/:id,decisions,stats}`
  (`bun:sqlite`, read-only).
- **UI:** four Hlidskjalf gates added — Sessions, Trace, Decisions, Stats —
  reading the smithy's trace. No `command`/`factory` references remain in the
  runtime or portal.
- **Verified:** `tsc` + `vite build` green, SPA 200, endpoints honest-absent,
  Galdr compliance 8/8, smoke 8/8.

## 2026-09-11 — Gleipnir lock PID binding fix

- **Problem:** The session lock (`state/.lock`) was written with the digest
  helper's PID (a short-lived child) instead of the live Pi harness PID. The
  harness adapter (`gna-pi-watch.ts`) reported "no live session holds the lock"
  and refused to arm the watcher.
- **Root cause:** `BROKK_SESSION_PID` was never injected into the spawn chain.
  `gleipnir_lock_acquire` fell back to `$$` (helper PID).
- **Fix:** `.pi/extensions/syn-turnend-guard.ts` and
  `.pi/extensions/gna-pi-watch.ts` now pass `BROKK_SESSION_PID: String(process.pid)`
  in the spawn env, so the lock binds to the live Pi process.
- **Impact:** Session lock reclamation works on next Pi session start/reload.
  The stale lock (dead PID) is overwritten by the live PID.

## 2026-09-11 — Desktop shell, tunnel, and temporary auth

- **Electron:** `apps/hlidskjalf/electron` + `scripts/electron.sh` open Hlidskjalf
  (and Smiðja) as a native window; raises the stack if down.
- **Tunnel:** `ymirdell.zerwiz.org` → `:3889` via `bin/gjallarhorn-tunnel.sh`
  (cloudflared config in `midgard/infrastructure/ingress/cloudflared-ymir.yml`).
- **Auth:** hardcoded HTTP Basic (`zerwiz:allfather`, `HLIDSKJALF_AUTH`) on the
  gate API, which now also serves the built SPA. Temporary — move to Heimdall +
  `.env.local`.
- **Mobile:** PWA manifest added; recommended APK = Capacitor over the tunnel.

## 2026-09-12 — Updater forged + credential moved to env

- **`bin/brokk-update.sh`** — the sanctioned, guarded updater the `ymir-update`
  skill calls: fast-forward only, refuses a dirty/diverged tree, `--yes` to
  stash+restore, `--check` to report. Never force-pushes.
- **Credential law:** the gate login (`HLIDSKJALF_AUTH`) no longer has an inline
  default; it is read from `.env.local` (Bun auto-loads it). Server falls back to
  an open gate only when unset (dev), with the key added to `.env.example`.

## 2026-09-12 — Ró preference moved out of the tracked tree

- `.agents/config/ro` was a **git-tracked** per-user toggle (calm on/off); any
  toggle dirtied the tree and made `bin/brokk-update.sh` refuse. It now lives in
  the gitignored `state/ro`; `YMIR_RO`/`BROKK_RO` set a default; the legacy
  `config/ro` is read once for upgrade then never written. Tracked file removed.

## 2026-09-12 — Fleet preferences

- `data/fleet.md` (gitignored) holds fleet-wide per-user settings (`ro: on|off`).
- `bin/fleet-apply.sh` applies them to this home + every registered Eindri-home
  (into each home's gitignored `state/`; remote routes reported).
- `bin/brokk-update.sh` re-applies fleet preferences on every sweep — one setting
  reaches the whole fleet, no tracked tree dirtied.

## 2026-09-12 — House law (RULES/) and the Grein naming

- New `RULES/` (the house law): `01-domains.md` (house = company; domain = a
  **Grein**/**Greinar**; Eindri = specialists), `02-agents.md` (agents live only
  in `.agents/agents`; harness dirs are symlinks; no mock agents), `03-houses.md`
  (a house is a company — WayOf; the eight Labs are domains, never houses).
- Live Fleet de-mocked (real domain/model/status; seeded stats only in demo).

## 2026-09-14 — A vacant helm is entered, not punted (watcher wake repair)

- **Problem:** a watcher wake reported the Pi extension could not restore
  continuity — "this session no longer owns the lock". Root cause found by
  inspection: an **empty/truncated** machine lock (`~/.local/state/ymir/brokk.lock`)
  was classified by `gna-pi-watch.ts` `lockOwnership()` as `other` (another
  live session) and by `bin/syn-watch-arm.sh`'s gate as read-only — so a helm
  with *no verifiably-live holder* was refused and punted to a manual
  `saga-session-start.sh` reclaim.
- **Fix (both seams in one change):** the extension now classifies an empty
  lock as `missing`, so `gna_watch_arm`'s reclaim takes the helm in place; the
  arm script, on finding no owner (or an owner verifiably gone), runs
  `gleipnir_lock_acquire` itself — which refuses only a genuinely live other
  session — instead of printing read-only. The "run saga-session-start.sh"
  punt is gone; a vacant helm is entered by the watcher's own hand.
- **Verified:** scratch-state test — empty machine lock → `watcher: started`,
  lock bound to the session pid + starttime sidecar, `.supervision-armed`
  touched; `gleipnir-machine-lock.test.sh` ALL PASS (zombie, recycled,
  migration); compliance 10/10; harness-integration asset updated in the same
  change (the governed rule).

## 2026-09-14 — The Eindri→Brokk wake bridge (they can talk back now)

- **Ask:** the seated smiths' reports lived in their panes only; the Allfather
  wanted a feature that wakes Brokk when an Eindri reports, so the fleet's
  doings reach the primary's session — "we are in control, Brokk".
- **Built:** `bin/eindri-seen.sh` (condition — a report file landed or herdr
  shows the smith left `working`), `bin/eindri-acclaim.sh` (action — files the
  report durably under state/eindri-reports/, marks done under
  state/eindri-done/, appends the wake to state/.wake-queue for Sága's drain,
  sounds the desktop note), and `bin/eindri-watch.sh` (the control door —
  `arm | retire | list | reconcile`, one when-source per smith on the Norns'
  loom via fm-procevent-when.sh, action hash-bound, fires once on a stable
  true, terminal, re-armable).
- **Armed live:** when-odrerir (already fired — his report was filed) and
  when-sessrumnir-cloth (still working). `fm-procement.sh reconcile` started=2.
- **First report delivered through the wire:** odrerir's Óðrerir saga — deck
  green at :4322, 52 Chromium checks, commit 38a326b on yggdrasil/odrerir, main
  untouched, plus the hall.ymir.zerwiz.org server story (setup-hall.sh) and
  three asks awaiting the Allfather (go live, landing mobile wart, PLAN log).

## 2026-09-14 — Óðrerir forged (Eindri odrerir, pane w3:p7)

- The Live Hall carved on the landing per PLAN.md §14: dealt slate pile,
  choices + recommended marks, freeform, queue + limit guard, thread ledger,
  live tally, four empty states, fail-closed, keyboard, reveal, mobile (390px,
  zero overflow); cloth check green; §12 scan clean. Deployed plan for the
  public hall: hall.ymir.zerwiz.org via a second Caddy site :4322 (deploy/
  setup-hall.sh + tunnel-ingress.sh, idempotent, live provisioning untested).

## 2026-09-14 — The echo guard: no wake flood through Gná's door

- **Problem:** during a loud stretch (stale wake lines + the FM runner's
  durable queue holding ten old check-wakes), the watcher re-armed and
  re-signalled "signal: wake queue" across many generations; every actionable
  close queued one pi follow-up wake (`sendWake`, no dedup), which then
  dripped at the Allfather one per prompt — a long echo flood after the
  sources were drained.
- **Fix:** `gna-pi-watch.ts` `sendWake` is **echo-guarded**: an identical
  watcher message is delivered at most once per drained state — when both
  durable doors (`state/.wake-queue` and the FM runner's
  `.agents/state/.wake-queue`) are empty, a repeat carry is the same drained
  news and is skipped. Genuine new content (different message, or a door with
  a line) always delivers. Harness asset updated in the same change.
