# Installation & First Setup — stand the whole system up

> **Purpose:** Everything Galdr must know to install, provision, and repair
> Ymir for an operator who does not have it. The code is authoritative; this
> page is the map.

One command sets up the whole system for the user; it self-heals what it can and
reports what it cannot. It **asks for consent first** — with a plan it computes on
this host, not a recited paragraph — and it **validates at the end** that what it
claims is actually running.

```
bin/ymir-install.sh               # the first setup (idempotent; asks to proceed)
bin/ymir-install.sh --plan        # the plan, probed — changes nothing (--json too)
bin/ymir-install.sh --check       # report only, no writes, no prompt
bin/ymir-install.sh --yes         # non-interactive (accept the plan)
bin/ymir-install.sh --skip-engines --skip-services
bin/ymir-install.sh --no-desktop  # don't open the desktop apps at the end
bin/ymir-install.sh --status      # alias of --check
```

## The plan comes first — `bin/ymir-plan.sh`

The consent a real install asks for is a **computed plan**, one row per step, each
carrying its state and the reason for it. A hardcoded paragraph cannot know the
host: the old one named an Omarchy version on a Mac, promised a workspace tree that
already stood, and never mentioned that no application had been installed at all.

```
bin/ymir-plan.sh              # the plan (TOON)
bin/ymir-plan.sh --json       # the same, for automation
bin/ymir-plan.sh --phase 5    # one phase
bin/ymir-plan.sh --blocked    # only what cannot proceed, and why
```

```
plan_states[5]{state,means}:
  "DO","a change will be made"
  "SKIP","already satisfied — nothing to do"
  "INFO","a fact about this host, discovered; no change implied"
  "BLOCKED","cannot run — the reason names what is missing"
  "CONSENT","needs the operator's word (a credential, an invite, the shells)"
```

```
plan_phases[9]{n,name,gate}:
  "0","resolve","this host, the container engine, the code root, and the home"
  "1","code","the tree is intact — and holds nothing of the operator's"
  "2","home","the operator's world, outside the tree"
  "3","runtimes","git/python3 · bun/uv/mcp<2> · pi · hermes · the terminal backend"
  "4","engines","treehouse · no-mistakes · sandcastle · the Utgard image"
  "5","apps","hlidskjalf · odrerir · sessrumnir · smidja — web build required, shell gated"
  "6","wire","the way in (auth · invite) and the launcher entries"
  "7","raise","every port listening, then the desktop apps"
  "8","verify","what stands, honestly"
```

`ymir-install.sh` prints the plan at the consent prompt; `--plan`/`--dry-run` prints
it and exits without writing. The plan is recomputed on every run, so it cannot
drift behind the code the way a paragraph did. `bin/ymir-plan.sh` is the ward for
the law below: its phase-1 `purity` row names any of the operator's things found in
the code tree.

## Where things live — the package is code, the home is the operator's

**Law (Rule 04):** the package carries the **core systems** — everything needed to
run the programs. Everything the **operator** owns goes to `$YMIR_HOME`: their
info, their records, their documents, their settings, their state, their
credentials. A packaged install (npm) treats its tree as read-only; the next
upgrade replaces it, so anything of theirs kept there is kept at its peril.

```
roots[5]{root,resolves_from,holds}:
  "ymir_home_root","$YMIR_HOME → the choice recorded at installation → one documented default","everything private the operator owns"
  "hoard_root","$YMIR_HOARD → <home>/hodd","docs · secrets · identity · tenants · memory"
  "hoard_data_dir","$YMIR_DATA_DIR → <hoard>/data","this machine's records: operator, fleet, machines, the host profile"
  "hoard_state_dir","$YMIR_STATE_DIR → <home>/state","runtime state: pids, logs, locks, caches"
  "hoard_settings_dir","$YMIR_SETTINGS_DIR → <home>/config","settings: agents.yaml, cron.yaml, tailscale-sync, the wedge channel"
```

Plus `hoard_local_env` → `$YMIR_HOME/.env.local`: the operator's **credentials**
(`HLIDSKJALF_AUTH`, OAuth keys, tokens), never in the tree.

**The home is chosen, not assumed.** A real interactive install asks once
(`step_home`), records the answer as machine state under `~/.config/ymir/home`
(the same place `engram-python` and `accounts.json` live), and every later script
resolves it through `bin/hoard-lib.sh`. `--check` never writes; `--yes` takes what
is recorded, else the documented default.

```bash
bin/hoard-lib.sh                     # the lib (source-safe; functions only)
ymir_home_root   HOME                # → the home
hoard_settings_dir SETTINGS          # → <home>/config
hoard_local_env  ENVFILE             # → <home>/.env.local
```

**Rule for new code:** never write `$ROOT/data`, `$ROOT/state`, `$ROOT/config`,
`$ROOT/.env.local` or `$ROOT/workspace`. Resolve the root through the lib. A script
that points an operator's thing into the tree is the bug the `purity` row exists to
catch.

### Carrying an existing tree home — migration 0005

Every *writer* resolves the home now, but an installation made before this change
still holds the operator's things in the tree. `.agents/migrations/0005-roots-out-of-tree.sh`
carries them:

```
what moves           from                    to
------------------   ---------------------   ----------------------------
this machine's       data/                   <hoard>/data
  records
runtime state        state/                  <home>/state
  (pids · logs ·     (including the          (running services keep their open
   locks · the        applied-migrations      fds across the move — `mv` keeps
   applied-marker)    marker)                 the inode)
credentials          the local env file      $YMIR_HOME/.env.local (0600)
settings             .agents/config/*        <home>/config
                     that git does NOT track
```

One name, two files — the migration decides by evidence, never by assumption:

```
collision[3]{case,what_happens,nothing_lost}:
  "identical content","the tree's copy is removed","the content is provably at home already"
  "different content","the home's keeps the name; the tree's is carried beside it as <name>.stale-<UTC>","both are real, so both are kept — never merged, never discarded"
  "not a plain file","left in place and reported","a directory is not silently swallowed"
```

Templates and defaults never move: `*.example` (and `*.example.*`), `.gitkeep`, and
any settings file **git tracks** — that is the distro's shipped default, not the
operator's. The plan's `purity` row applies the same rule, asking git about the
real path (the tree's `config` is a symlink into `.agents/config`, and git tracks
what the index holds, not the link). Idempotent: a second run changes nothing.

```bash
bin/ymir-migrate.sh status            # pending / applied
bin/ymir-migrate.sh apply --dry-run   # name the migration, touch nothing
bin/ymir-migrate.sh apply             # carry it
```

Stop the runtime first if you want no stale pid files; nothing is lost either way.

## Operating it afterwards — the doors, the cloth, and the shapes

### The doors (the CLI), named for the figure who does the work

`npm install -g @zerwiz/ymir` puts **two** commands on PATH: `ymir` (the front
door) and `ymir-install` (the bare installer). Everything else the operator
needs is a door on `ymir` — never a script path inside `node_modules`.

```
doors[14]{verb,door,what}:
  "ymir","first setup (a bare call installs)","the plan, then consent, then the work"
  "ymir install [...]","bin/ymir-install.sh","the same, said out loud"
  "ymir plan","bin/ymir-plan.sh","what an install would do here — writes nothing"
  "ymir raise / lower","scripts/start.sh · stop.sh","lift the hall, or lay it down"
  "ymir eir","bin/eir-doctor.sh","what stands, and mend what does not (the healer)"
  "ymir groa","bin/groa-update.sh","take the latest, then mend this home forward"
  "ymir groa migrate","bin/ymir-migrate.sh","heal this home's structure"
  "ymir heimdall","bin/ymir-setup-auth.sh","the way in — status · set · github (the guardian)"
  "ymir invite","bin/ymir-invite.sh","let someone else in — mint · list · revoke"
  "ymir smidja","bin/smidja-board.sh","the smithy's board on :8437 — build · start · stop · status"
  "ymir hlidskjalf","scripts/electron.sh start --view hlidskjalf","the high seat's window"
  "ymir sessrumnir","scripts/electron.sh start --view sessrumnir","the seat-hall's window"
  "ymir mimir","bin/mimir.sh","the memory well"
  "ymir sense","bin/host-sense.sh","what THIS machine is"
```

A name the law has not given a home is still answered, once, with the name that
has it: `ymir doctor` → *the door is named `ymir eir` now*. Colour appears only
where a human watches.

### The cloth — `bin/ymir-style.sh`

Ymir had correct output and no design. The cloth is cut from the same stone as
the halls (`midgard/design-system/tokens.css`): **bone** `#cfc3a9` for words,
**bronze** `#c9973f` for what acts, **steel** `#96a0a8` for what stands, **blood**
`#c2584a` for what is wrong, and a mark per state (`◆` do · `·` already · `—`
fact · `✕` blocked · `?` needs your word · `✓` proved).

```
cloth_rules[4]{rule,why}:
  "colour and marks only when stderr is a terminal and NO_COLOR is unset","a pipeline never parses a decoration"
  "data on stdout, the human rendering on stderr","the TOON row is the data; the coloured line is for the eye"
  "the words are never conditional — only the colour is","hiding information to save colour is the wrong trade"
  "no banner over four lines, no rule longer than its text","density first (Monoline TUI · cli-guidelines)"
```

`bin/ymir-plan.sh --colour` renders the plan in the cloth on stderr while the
TOON stays on stdout. The installer prints it at the consent, and ends with the
next steps — *a reaction for every action, a next step for every ending*.

### A clone and a package are one tree — `bin/app-lib.sh`

The apps are the only thing that differs between the two shapes, and only in
where they live:

```
surface            a clone                  an npm install
---------------    ----------------------   ------------------------------------
hlidskjalf         apps/hlidskjalf          node_modules/@zerwiz/hlidskjalf
hlidskjalf-mobile  apps/hlidskjalf-mobile   node_modules/@zerwiz/hlidskjalf-mobile
odrerir            apps/odrerir             node_modules/@zerwiz/odrerir
sessrumnir         apps/sessrumnir          node_modules/@zerwiz/sessrumnir
smidja             apps/smidja-factory      node_modules/@zerwiz/smidja-factory
```

`bin/app-lib.sh` answers for both — `app_dir <surface> <var>`, `app_pkg
<surface>` — and **eighteen files** were converted to it: the raise path
(`scripts/start.sh`), the windows (`scripts/electron.sh`), the invite door, the
seat-hall trio, Eir, the icon mint, the desktop placement, the hall snapshot, and
the installer's own SPA and shell steps. `bin/smidja-lib.sh` delegates to it, so
there is **one** truth about where things live.

**The trap that named itself.** `printf -v <name>` writes to the *function's*
scope. A helper whose scratch variable shares the caller's requested name
swallows the answer — `app_dir hlidskjalf c` returned nothing because the
helper's own `local c` held the path. Every scratch name in the resolvers is
function-prefixed (`_apd_c`, `_smd_c`, `_apr_root`) for exactly that reason, and a
new resolver must follow the rule.

**Why it matters beyond tidiness:** a packaged install shipped with eighteen
scripts looking in `apps/`, so `ymir raise` died on
`cd …/apps/hlidskjalf: No such file or directory` while every package had in fact
arrived. A shape assumption is a bug that only shows itself on the *other* shape.

### The hall answers on the port it was given

`scripts/start.sh` raises the SPA, and the SPA must listen on
`$HLIDSKJALF_PORT` (3888 by default) — every other door looks for it there. Two
rules came out of a packaged install where it listened nowhere:

```
spa_serving[2]{shape,how}:
  "a packaged install","serves its built ./dist with `vite preview --port $PORT --strictPort`"
  "a clone","serves the dev server, but STILL on $PORT — `npm run dev -- --port $PORT --strictPort`"
```

A bare `npm run dev` lets Vite take 5173 and the hall silently answers on the
wrong port; the raise now prints the log's last lines when the port stays silent
rather than claiming success. Óðrerir resolves through `bin/app-lib.sh` like every
other surface (it read as `missing apps/odrerir` on a packaged install).

### The marks land on any desktop — not only Omarchy's

`bin/desktop-place.sh` holds **two kinds of thing**, and they were behind one gate:

```
desktop_halves[2]{half,who_reads_it}:
  "the window rules (numbered desktops, the Lua rule)","Hyprland / Omarchy only"
  "the launcher entries and the rune icons","the freedesktop standard — GNOME, KDE, Hyprland alike"
```

A GNOME operator gets entries and icons and no window rules, which is the correct
answer — and the reason a packaged install on GNOME placed *nothing* while the
clone's marks already existed. `bin/desktop-place.sh entries` is the launcher half
alone (any Linux desktop), the installer's `marks` step calls it, and both the
desktop database and the icon cache are refreshed after.

### Every notice can be silenced — `ymir config`

Some lines are information the first time and noise the tenth. A user must be able
to say **not again**, once, and be believed. The preferences live in the operator's
settings (`<home>/config/notices.conf`, one `key=on|off` per name) and the door is:

```
ymir config                          # what is shown, and what is not
ymir config notice version off       # silence one; `on` restores it
judgment[4]{key,what}:
  "version","the line that says which version moved to which"
  "patience","the long-hour words before a slow install or build"
  "next","the where-to-go-from-here block at the end"
  "hints","the one-line helpers that say how to hide a notice"
```

Every notice that can be silenced **says so once**, in the cloth's faint voice —
`(not again: ymir config notice version off)` — so the way out is discoverable
without a manual. Absent means on; a preference is honoured by the shell cloth
(`notice_wanted`, `notice_hint`) and by the CLI alike. `ymir-install.sh`'s marks
and the raise path honour it too.

### Four surfaces, one raise

`ymir raise` lifts the whole hall — the SPA (`:3888`), Óðrerir (`:4322`), the
board (`:8437`), and the commit-hall Sessrúmnir rises in the same motion (it is an
Electron app of its own, not a browser surface). `ymir-install.sh`'s desktop step
opens **one window per surface** rather than a single "both".

### What a user went from, and to

`npm install -g` prints *"changed 266 packages"* and no versions. The CLI records
the version it last ran in the home's state (`state/version`) and says the
transition **once**, on the first run after an update:

```
  the tree moved  0.1.7 → 0.1.9
  run `ymir eir` to see what stands, `ymir raise` to lift the hall
```

### The patience words — `style_patience`

A long hour must say what it is doing. `bin/ymir-style.sh` carries the line, and
the installer's long chain and the raise path's build open with it:

```
◆ much moves   the halls are being stood up for the first time
      this hour is long, and nothing of yours is lost in it —
      roots come home, shapes are re-cut, names are set true again.
      Your patience is noted, and it is earned.
```

Written in the house voice, kept under four lines (density), and shown on stderr
with everything else the cloth renders.

### Two libs the packaged tree needs

```
libs[2]{path,resolves}:
  "bin/smidja-lib.sh","the smithy: apps/smidja-factory in a clone, node_modules/@zerwiz/smidja-factory in a package — `smidja_factory_dir`, `smidja_visualizer_dir`"
  "bin/electron-lib.sh","whether a shell's runtime VERIFIES: `electron_runtime_state` (ok · partial · absent) and the exact remedy"
```

**Why they exist.** A packaged tree has no `apps/`: the smithy arrives as a
dependency and the skill symlink dangles. Four call sites assumed the clone's
layout, so the visualizer read as unbuildable in a package. They resolve through
`bin/smidja-lib.sh` now.

**And a shell is never declared ready on a directory's presence.** npm gates
install scripts; a skipped Electron postinstall leaves `dist/` partial and
`path.txt` unwritten, so the web app builds, every check passes, and the window
never opens. `electron_runtime_state` verifies, and the plan's `electron` row
says *the runtime is PARTIAL* with the command that mends it.

## The app packages — how the four surfaces arrive

The distro depends on the surfaces as their own npm packages, so one
`npm install -g @zerwiz/ymir` fetches them into the tree:

```
app_packages[4]{package,repo,what}:
  "@zerwiz/hlidskjalf","zerwiz/hlidskjalf","the control plane — dist/ ships built, served on :3888"
  "@zerwiz/odrerir","zerwiz/odrerir","the live hall — dist/ ships built"
  "@zerwiz/sessrumnir","zerwiz/sessrumnir","the seat-hall desktop — out/ ships built (a fork of pi-desktop)"
  "@zerwiz/smidja-factory","zerwiz/smidja","the smithy and its visualizer — the factory plus the UI's source, built at install"
```

They are **optionalDependencies**, deliberately: a broken app package must never
stop the CORE from installing, and a package not yet on the registry is skipped by
npm and starts arriving the moment it is published. The plan's phase-5 rows report
each surface separately — installed, declared-but-not-fetched, or no package at all
— so a silent skip cannot hide.

A global install nests them under the distro's own `node_modules`
(`<prefix>/lib/node_modules/@zerwiz/ymir/node_modules/@zerwiz/<app>`); a local one
hoists them to `node_modules/@zerwiz/<app>`. The plan checks both shapes.

```
bin/npm-publish.sh                       # the platform only
bin/npm-publish.sh --all                 # the platform + every app package
bin/npm-publish.sh --dry-run --all       # what would go out, and from where
bin/npm-publish.sh --unpublish @zerwiz/ymir@0.1.5   # take ONE version back
```

**A version can be taken back, and the window is short.** npm permits unpublishing
**one version for 72 hours** after it was published; past that it is npm support's
door. So `--unpublish` demands a spec that names the version — never a bare name —
and the row says where the CDN may still serve the tarball for a while afterwards.
Publishing a newer version is the other half of the repair: it moves the `latest`
tag off the bad build at once, even before the removal propagates.

**A `files[]` entry that names a directory overrides `.gitignore`.** This is how
`@zerwiz/ymir@0.1.5` shipped the memory well: `files: [".agents/"]` packed that
subtree *including* the gitignored stores, and the repo stayed clean while the
artefact did not. Name what ships, exclude what must not, and prove it with
`npm pack --dry-run` — the repo's cleanliness says nothing about the tarball.

The app repos are cloned into `apps/` by the install's `apps` step (from the
registry's `repo: apps/<path>` blocks), which is where `--all` reads their
manifests. The token comes from the hoard, never from `~/.npmrc`.

## The steps

```
install[23]{step,what,self-heals}:
  "panes","the run shown in a herdr pane","bin/herdr-run.sh sits a pane beside the caller when inside herdr; inline otherwise — a pane that cannot be raised never loses the work"
  "prereqs","git python3 bun docker|podman gh · mcp<2","bin/prereq-ensure.sh installs bun+uv+mcp in user space; engram is an honest optional SKIP"
  "memory-well","the engram engine (Mimirsbrunn)","optional; reported with the exact next command, never a fake fix"
  "home","the home the operator CHOOSES, recorded under ~/.config/ymir/home","asks once, records the answer; --check never writes, --yes takes what is recorded, else the documented default"
  "tree","workspace/{work,personal}/<domains>, companies/, workspaces.yaml, projects.yaml, and the hoard OUTSIDE the repo (secrets/ · docs/ · identity/ · tenants/ at the hoard root under the chosen home)","creates if missing; hoard_root resolves through bin/hoard-lib.sh so no script can point the hoard inside the checkout (Rule 04), and an empty secrets/platform.env (0600) is seeded so bin/hodd.sh emit resolves"
  "apps","the app repos (the app split) — hlidskjalf · hlidskjalf-mobile · odrerir · sessrumnir · smidja","reads $HOARD/identity/projects.yaml (never guesses a remote); clones a missing apps/<path> from its registered git{} block, fast-forwards a present one, and stamps the smithy engine (apps/smidja) from the cloned factory's templates"
  "engines","treehouse · sandcastle · no-mistakes","installs treehouse + no-mistakes from their installers"
  "hermes","the Nous Research agent runtime","installs via bin/hermes-ensure.sh when absent"
  "sessrumnir","the Sessrúmnir desktop GUI (its own repo; lands via the `apps` step at apps/sessrumnir)","bin/sessrumnir-ensure.sh installs deps + builds on first run (deps are never committed); launch via bin/sessrumnir.sh"
  "backend","Þjazi — herdr (protocol 14+) or tmux","bin/herdr-ensure.sh detects/tests version, installs via the pinned installer or falls back to tmux"
  "host","this machine — sensed on EVERY host","bin/host-sense.sh senses the setup on ANY host (Rule 05); the Omarchy layer then RECORDS it (bin/omarchy-sense.sh observe), places the apps (bin/desktop-place.sh), installs the post-update hook and the wedge-alarm channel, and (on Omarchy) offers the suggested shell plugins — listed, never installed unbidden; seeds the private config/agents.yaml from its example"
  "sandbox","utgard-runner:latest image","builds via bin/utgard.sh build on Docker or rootless Podman; distinguishes an unreachable engine from a build failure"
  "memory","engram store + harness MCP registrations","raises the bridge; reports MCP coverage — the store is ONE well in the hoard ($YMIR_HOME/hodd/memory/kaia.engram), resolved via hoard-lib or ENGRAM_DB"
  "smidja","smidja/smidja_data/smidja.db","bin/smidja-bootstrap.sh creates it from the tracer schema + a bootstrap session"
  "visualizer","the Smíðja visualizer UI (Vue, served on :8437)","builds ./dist with bun when absent — the API serves the UI from dist, and without it the API answers but shows no interface"
  "loaders","agents/skills into the harnesses","runs bin/valknut-load.sh"
  "gates","the git delivery gates — secret-guard (pre-commit), branch-guard + changelog-guard (pre-push)","bin/secret-guard.sh --install and bin/changelog-guard.sh --install seat the versioned guards into .git/hooks, so the gate is live from the first commit of a fresh clone; idempotent"
  "marks","each app's rune icon + .desktop entry into the operator's own desktop, and the Ymir contract into pi's agent home","bin/design-icon.sh mint --all + install writes to $HOME/.local/share (never a session sandbox), so every app is dockable and pinnable; the contract symlink means every pi session, in ANY folder, loads Brokk"
  "invite","the way in for anyone else — an invite code","bin/ymir-invite.sh ensure mints one only when nothing is live, so the step is idempotent; the code is printed at the end of the run and again in workspace/INSTALL.md"
  "register","workspace/INSTALL.md","writes the record"
  "services","gate API, SPA, Nornir, bridges, visualizer","raises via scripts/start.sh (which builds the visualizer UI when ./dist is absent)"
  "desktop","Hlidskjalf + Smíðja desktop apps","bin/desktop-place.sh puts each on its OWN numbered desktop (preferring EMPTY ones); scripts/electron.sh start --both self-heals the Electron binary"
  "validate","the running system","bin/ymir-validate.sh — live port/store/process checks"
```

**25** `step_*` functions are defined (`home` asks, `tree` builds). A step is not a row: one step may emit
several. `prereqs` also emits `memory-well`, `host` also emits `agents-config`,
`smidja` also emits `visualizer`, and `spa` also emits `hlidskjalf`. `--check`
skips the runtime-only steps (`services`, `desktop`, `validate`), which have
nothing to report when the runtime is not raised, so a real run prints those
three in addition. The exact set is whatever the host honestly has — never
assume the count:

```bash
bash bin/ymir-install.sh --check | grep -cE '^  "'   # the honest count, on your host
```

## Configuration is never hardcoded (Rule 07)

Every port, host, endpoint, path, and credential is resolved from env/config with
**one documented default** — never a literal in shipped runtime. Ports read
`HLIDSKJALF_PORT` / `HLIDSKJALF_API_PORT` / `SMIDJA_VIZ_API_PORT`, the SPA bind
host reads `HLIDSKJALF_HOST`, and a deployment overrides them in its env file
(Quadlet/Compose), never by patching the core. Law: `RULES/07-config.md`.

## Container engine: Docker **or** rootless Podman

The core never assumes an engine binary. `bin/ymir-platform.sh` resolves whichever
this host can reach (`YMIR_CONTAINER_ENGINE` forces one) and exposes:

- `ymir_container_engine` / `ymir_container_engine_name` — `docker` or `podman`.
- `ymir_engine_is_podman` — true even when a `docker` binary fronts Podman (the
  podman-docker shim).
- `ymir_volume_suffix` — `:Z` whenever SELinux is enforcing (Docker and Podman
  both need the relabel), else empty.
- `ymir_rootless_podman` — rootless Podman needs `--userns=keep-id` so a bind
  mount lands owned by the invoking user.

`bin/utgard.sh`, `bin/einherjar-spawn.sh`, `bin/valhalla.sh`, `bin/ymir-validate.sh`,
this installer, and `bin/prereq-ensure.sh` all use these; none names an engine
directly. **Quadlet**-managed containers (Podman + systemd) surface as
`systemd --user` units, which the process hall lists. A host-managed deployment
layer (Quadlet, compose, bare) sits **over** this agnostic core — never inside it.

## The visualizer UI

The Smíðja visualizer **API** runs on `:8437` and serves its **UI** from
`apps/visualizer/dist`. A fresh clone has no `dist`, so the API answers but shows
"No ./dist build found" — an install gap. The installer (and `scripts/start.sh`)
now build it when absent:

```bash
(cd .agents/skills/smidja-factory/apps/visualizer && bun run build)   # vue-tsc + vite
```

`bin/ymir-validate.sh` reports `visualizer` FAIL when `./dist` is missing **and**
when the build exists but nothing is listening on `:8437`. A PASS means the UI is
built *and* the API is up — so a built-but-dead visualizer (a bad `CMD_DB`, a
crashed API) can no longer read as green.

## Desktop placement (Omarchy desktops, not monitors)

On Omarchy the numbered **desktops** (1 2 3 4 5 …) are the "screens" an operator
switches between. `bin/desktop-place.sh` gives each Ymir app its **own** desktop,
**preferring an empty one**, so the apps open separated and reachable with
`Super+<n>` rather than stacking on the active desktop.

```
bin/desktop-place.sh plan            # which desktop each app would take
bin/desktop-place.sh apply           # write the rules + hyprctl reload
bin/desktop-place.sh status          # what is installed
```

It writes `~/.config/hypr/ymir-desktops.lua` using Omarchy's own idiom —
`o.window({ class = "^ymir-hlidskjalf$" }, { workspace = "2" })` — and adds one
`require("hypr.ymir-desktops")` line to the user's `hyprland.lua`. It **never**
touches `/usr/share/omarchy/`. Verify with `hyprctl configerrors` (must be empty).
On a non-Omarchy host the step is a clean SKIP.

## The Þjazi backend (herdr-first)

Ymir spawns agents into terminal panes, so a terminal backend must exist. Ymir is
**herdr-first**: `herdr` (Þjazi) is preferred, `tmux` is the accepted reference
backend, and a missing backend is reported — never a silent fallback.

```
backend_priority[3]{rank,backend,note}:
  "1","herdr","preferred; protocol 14+ for panes, 0.8.0+ for presentation spaces"
  "2","tmux","verified reference backend; always acceptable"
  "3","none","spawn is refused with a plain reason"
```

```
bin/herdr-ensure.sh status            # what is present, and does it meet the floor
bin/herdr-ensure.sh ensure --install  # install via the pinned, SHA-verified installer
```

`ensure` installs through `.agents/backend/fm-install-herdr.sh` (exact version +
protocol check), and falls back to reporting `tmux` when herdr cannot be fetched.
Selection order for the running system: `config/backend` → `BROKK_BACKEND` →
`HERDR_ENV=1` → else tmux. Full reference: the `ymir` skill, `assets/thjazi.md`.

## Suggested Omarchy plugins (offered, never forced)

Omarchy's shell is plugin-shaped, and a few registry plugins are Ymir's own organs
rendered on the desktop. `bin/omarchy-plugins.sh` suggests them and installs only
what the Allfather accepts.

```
bin/omarchy-plugins.sh list        # what Ymir suggests, and why
bin/omarchy-plugins.sh installed   # reads omarchy's own plugin list
bin/omarchy-plugins.sh suggest     # the offer (no install)
bin/omarchy-plugins.sh add <id>    # install one, with consent
```

The core three are Ymir's organs: **Herdr Watch** (Þjazi in the bar), **Hermes
Deck** (our worker runtime), **Skill Manager** (the Galdr family across harnesses).
Installation uses Omarchy's own verb — `omarchy plugin add <repo> --enable` — never
a raw clone.

**These run unsandboxed inside the shell.** The registry "validates listings, not
plugin security", so nothing installs without an explicit yes (`--yes` for
non-interactive callers; without it a non-interactive `add` refuses with exit 3).
The installer only *offers*.

## Consent
A real install prints **the plan it computed** (`bin/ymir-plan.sh`) and waits for
`[y/N]`. Declining changes nothing (exit 3). `--check` and `--plan` never prompt.
A non-interactive caller without `--yes` is refused rather than silently
proceeding.

The plan names every step with its state and the reason for it — including the
home the operator is asked to choose, the four app surfaces and whether each can
be installed at all, the terminal backend, and what will be skipped and why. The
state vocabulary is `DO · SKIP · INFO · BLOCKED · CONSENT`.

`--check` writes nothing — and that includes the migrations. `bin/ymir-migrate.sh
apply` **moves private data**, so the step chain runs it only on a real run;
a preview leaves the home exactly as it found it. (It used to apply them even
under `--check`, which moved a home during a "report only" pass.)

`--check` writes nothing — and that includes the migrations. `bin/ymir-migrate.sh
apply` **moves private data**, so the step chain runs it only on a real run;
a preview leaves the home exactly as it found it. (It used to apply them even
under `--check`, which moved a home during a "report only" pass.)

## The operator's way in (auth) — `bin/ymir-setup-auth.sh`

A fresh checkout seeds **no credential**, so the gate has no way in until the
operator sets one. `step_auth` (interactive install prompts; `--yes`/non-tty
defers) covers two doors:

```bash
bin/ymir-setup-auth.sh status            # which door (if any) is configured
bin/ymir-setup-auth.sh set [--user U]    # a local password -> HLIDSKJALF_AUTH in .env.local
bin/ymir-setup-auth.sh github            # GitHub sign-in -> GITHUB_CLIENT_ID + GITHUB_CLIENT_SECRET
```

Both write `.env.local` (0600, gitignored); a secret is never printed or put in a
child process's argv. The gate reads `HLIDSKJALF_AUTH` (`user:pass`) and the
GitHub OAuth keys (`/api/auth/github`; sign-in names a login but never grants
access on its own — an account/invite is still required). Restart the gate after
setting a credential. One login is meant to cover every surface — see the shared
session below.

## Letting someone else in (invites)

One operator owns the instance. The installer mints an **invite code**
(`step_invite`) and prints it at the end of the run; share that code and someone
else can create their own account at the gate login screen. Registration is
closed unless a live code exists, so an instance is never accidentally open.

```bash
bin/ymir-invite.sh mint [--limit N]   # a new code (default ceiling 5 accounts)
bin/ymir-invite.sh list               # every code, what is spent, who is in
bin/ymir-invite.sh revoke <CODE>      # take one back, now
bin/ymir-invite.sh where              # where the accounts live on this machine
```

Accounts are stored in `~/.config/ymir/accounts.json` (mode `0600`), machine
state that never enters the repo, with argon2id hashes only. The operator's own
credentials stay `HLIDSKJALF_AUTH` in `.env.local` — invites are for everyone
*else*. Full surface: the galdr `hlidskjalf-ui.md` asset.

## Validation

After the runtime is up, `bin/ymir-validate.sh` observes the result: prerequisites,
the Utgard image, the gate API (`:3889`), the SPA (`:3888`), Bifrost (`:4603`),
Nornir cron, `smidja.db`, the desktop apps, the well (`:4602`), and the audit
ledger. A FAIL means the install is not usable; a WARN means a documented-optional
part is off. `--json` for machine consumption.

## What the system adopts (engines)

| Engine | Norse shell | Role |
|---|---|---|
| **treehouse** (`kunchenguid/treehouse`) | Yggdrasil | reusable worktree pool |
| **sandcastle** (`mattpocock/sandcastle`) | Utgard | Docker/Podman/Vercel sandboxes |
| **no-mistakes** (`kunchenguid/no-mistakes`) | Mjollnir · Glitnir | clean-PR validation gate |
| **Hermes** (`NousResearch/hermes-agent`, MIT) | — (product name) | worker agent runtime: own brain, memory, skills, subagents, sandbox backends |
| **pi-desktop** (`FaqFirebase/pi-desktop`, Apache-2.0) | **Sessrúmnir** (cloned from its own repo to `apps/sessrumnir` at install) | desktop GUI for the Pi/OMP coding agents — the seat-hall, themed with the Ymir way-of palette |

## Missing dependencies

- **Fixable in user space** (no sudo): `bun`, `uv`, `mcp<2>` — via
  `bin/prereq-ensure.sh`. `treehouse`, `no-mistakes`, **Hermes**, and the **Þjazi
  backend** (herdr, or tmux) are installed by their own ensure/steps.
- **Needs a system package** (reported with the exact command): `git`,
  `python3`, `docker`, `gh`.
- **Optional, honest SKIP:** the `engram` memory engine. The published PyPI
  `engram` is **not** Ymir's engine (it is an unrelated scientific package), so
  the installer reports the well as off rather than installing the wrong thing.
- **Offline:** engine/Hermes/herdr installers fail gracefully and are reported;
  re-run when the network returns.

## Hermes specifically (`bin/hermes-ensure.sh`)

```
hermes-ensure.sh status           # hermes[1]{installed,version,path,method}
hermes-ensure.sh ensure --install # install if absent, then report
hermes-ensure.sh install          # curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
```

A user who lacks Hermes gets it at setup (`hermes` step). Config/identity
(`hermes setup`, auth) stays the user's own; Ymir guarantees only the runtime.

## Sessrúmnir specifically (`bin/sessrumnir-ensure.sh`, `bin/sessrumnir.sh`)

```
sessrumnir-ensure.sh status           # sessrumnir[1]{dir,deps,built,electron}
sessrumnir-ensure.sh ensure --install # install deps + build when absent, then report
sessrumnir-ensure.sh install          # npm install + electron-binary heal + npm run build
sessrumnir.sh start [path]            # launch the seat-hall (deps installed on first run)
sessrumnir.sh status | stop
```

Deps are never committed; the ensure step installs them on first run, exactly as
`scripts/electron.sh` does for the other desktop apps. The external engine keeps
its product name `pi-desktop`; the GUI the user sees is Sessrúmnir, themed with
Ymir's deep-navy palette. The Omarchy launcher entry is rendered from
`apps/sessrumnir/resources/ymir-sessrumnir.desktop.in` by `bin/desktop-place.sh`
(placement + `SUPER+B`).

## Neutral tenant defaults — a fresh Ymir is a distro, not the company

A fresh install ships **no company of its own**. `bin/ymir-install.sh` seeds one
`personal` workspace and an **empty** projects registry (a commented example
only); it never writes a company slug, a company remote, or a `work (company: …)`
line. The runtime resolves the active realm **neutrally** through
`bin/realm-lib.sh` (`ymir_active_realm`): `data/realm.md` (first line) → the first
non-example tenant under `svartalfaheim/` → `default`. **No script may fall back
to a company slug.** The reference tenant the distro was built for lives at
`svartalfaheim/examples/wayof/` — an example to copy, never the default. A `work`
workspace must name its own company: `workspace-provision.sh` requires
`--company <slug>`.

## Per-workspace provisioning

```
bin/workspace-provision.sh <name> --kind work|personal [--domains a,b,c] [--company <slug>]
```

Creates `workspace/<name>/<domains>/`, registers it in `workspaces.yaml`, and
for a **work** workspace attaches it to the tenant container
`svartalfaheim/<company>/`. `--company` is required for a work workspace — the
company is the operator's to name; Ymir ships no default.

## Verify

```
bin/ymir-install.sh --check          # all steps OK/WARN
bin/ymir-validate.sh                 # the running system actually works
bin/herdr-ensure.sh status           # the Þjazi backend and its protocol floor
bin/host-sense.sh                    # sense THIS machine (any host)
bin/omarchy-sense.sh status          # the Omarchy recording (Omarchy hosts)
bin/saga-session-start.sh            # the session digest
bash .agents/skills/galdr-ymirsystem/scripts/compliance-check.sh
```

On **every** host the installer senses the machine with `bin/host-sense.sh`. On
an **Omarchy** host the layer also *records* it (`bin/omarchy-sense.sh observe`)
and installs a `post-update` hook so Ymir re-learns it every time Omarchy
updates. On a non-Omarchy host that layer step is a clean SKIP.

Rule: the installer is **idempotent** — running it again changes nothing but
fills gaps. It never overwrites real user data.

## Node dependencies in a fresh clone — the postinstall trap

A clone never carries `node_modules`. Two components need them, and each has its
own package manager:

```bash
# Hlidskjalf (npm + package-lock.json) — what scripts/start.sh runs
cd apps/hlidskjalf && npm install --no-audit --no-fund
npm run typecheck && npm run build          # dist/ is what the SPA serves

# Smiðja visualizer (bun + bun.lock)
cd .agents/skills/smidja-factory/apps/visualizer && bun install && bun run build
```

The visualizer's `dist/` is not optional: its API serves the UI from `./dist`,
and without a build it answers the API but prints *"No ./dist build found"*.

### The trap: install scripts can be skipped silently

Newer npm versions gate package install scripts (`allowScripts`). When a script
is not approved the install still reports success, so you get a **half-broken
tree that passes its own build**:

```
2 packages have install scripts not yet covered by allowScripts:
  electron@33.4.11 (postinstall: node install.js)
  esbuild@0.25.12  (postinstall: node install.js)
```

- `esbuild` survives it (its binary arrives through the platform-specific
  package), so `npm run build` succeeds and everything looks healthy.
- **`electron` does not.** Its postinstall downloads the ~100 MB runtime; without
  it `node_modules/electron/dist/` is left partial and `path.txt` is never
  written, so the desktop shell cannot start — while the web app builds perfectly.

Detect it:

```bash
npm install-scripts ls                                        # what is unapproved
node_modules/electron/dist/electron --version                  # fails if skipped
cat node_modules/electron/path.txt                             # absent if skipped
```

Fix it:

```bash
npm install-scripts approve electron esbuild
npm rebuild electron
```

If the rebuild still exits **silently** and `dist/` stays partial, the download
is cached but was not re-extracted — complete it by hand, which is all the
package's own installer does:

```bash
ZIP=$(ls ~/.cache/electron/*/electron-v*-linux-x64.zip | head -1)
rm -rf node_modules/electron/dist && mkdir -p node_modules/electron/dist
unzip -q -o "$ZIP" -d node_modules/electron/dist
printf 'electron' > node_modules/electron/path.txt     # the linux binary name
chmod +x node_modules/electron/dist/electron
```

**Verify the install as a whole**, not just that a build passed: the electron and
esbuild binaries report versions, both `dist/` directories exist, and
`bin/ymir-install.sh --check` reports the visualizer and smidja green.

## Platform support — Linux, macOS, Windows

Ymir runs on Linux (native), macOS (native) and Windows (through **WSL2**, with
MSYS/Git Bash as best-effort). The runtime is bash, so Windows means a POSIX
shell: WSL2 is the supported path, and it is also the only one where the Linux
GPU and service paths behave normally.

### One place knows the difference

`bin/ymir-platform.sh` is the portability layer. It defines functions only and is
sourced, never executed:

```bash
. "$ROOT/bin/ymir-platform.sh"     # scripts already do this via the shim block
```

| Need | Function | Why it exists |
|---|---|---|
| Which OS | `ymir_os` → `linux` \| `macos` \| `wsl` \| `msys` | branching, once |
| CPU count | `ymir_nproc` | `nproc` is GNU; macOS uses `sysctl -n hw.ncpu` |
| Resolve a path | `ymir_readlink_f` | BSD `readlink` has no `-f`; mirrors GNU semantics including the "parent must exist" rule |
| File facts | `ymir_stat_mtime`, `ymir_stat_size`, `ymir_stat_id`, `ymir_stat_birth`, `ymir_stat_mode` | GNU `stat -c` vs BSD `stat -f`, and birth time exists on both but differently |
| Timing | `ymir_epoch_ns` | BSD `date` has no `%N` |
| A pid's command line | `ymir_pid_cmdline`, `ymir_pid_matches` | `/proc` is Linux-only; falls back to `ps -o command=` |
| Signal a process by pattern | `ymir_kill_matching` | `pkill` is absent on some MSYS/WSL images; falls back to `ps` + `kill` |
| Detach a process | `ymir_detach` | `setsid` is absent on macOS; falls back to `nohup` |
| Exclusive lock | `ymir_lock` | `flock` is Linux; falls back to an atomic `mkdir` lock |
| Services | `ymir_service_backend`, `ymir_service_active` | `systemd` on Linux, `launchd` on macOS, neither elsewhere |
| GPUs | `ymir_gpu_name`, `ymir_gpu_mem_used` | never assume NVIDIA: `nvidia-smi`, then `rocm-smi`, then Apple's unified memory |
| Paths | `ymir_tmp`, `ymir_expand_tilde` | `TMPDIR`/`TEMP` vary; a leading `~` must be expanded explicitly |

Scripts that need any of these carry a short shim block near the top that finds
and sources the library, then marks it loaded so a second source is a no-op:

```bash
if [ -z "${YMIR_PLATFORM_LOADED:-}" ]; then
  _ymir_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  for _ymir_c in "$_ymir_dir/ymir-platform.sh" "$(dirname "$_ymir_dir")/bin/ymir-platform.sh"; do
    [ -r "$_ymir_c" ] && { . "$_ymir_c"; YMIR_PLATFORM_LOADED=1; break; }
  done
  unset _ymir_dir _ymir_c
fi
```

### Rules for new code

1. **Never call `readlink -f`, `stat -c`, `nproc`, `setsid`, `flock`, `date +%N`
   or read `/proc` directly.** Use the shim.
2. **Never assume NVIDIA.** Ask the shim; a machine may be AMD, Intel or Apple.
3. **Never hardcode a home directory.** Use `$HOME`, or `ymir_expand_tilde` for a
   user-supplied path, and keep machine-specific values in generated config
   rather than in the tree.
4. **Never assume a desktop.** `.desktop` files, `systemctl` and window managers
   are Linux-shaped; a launcher must be generated for the host, not shipped as
   one file for all.
5. **Test the fallback, not just the happy path.** Most of these functions exist
   because the Linux path already worked; the risk is the other branch.

Standalone tools that ship outside a Ymir checkout (for example
`.agents/skills/galdr-ymirsystem/scripts/bench-one.sh`) carry their own small portable
helpers instead of sourcing the library, so they run anywhere on their own.

### Machine config is rendered, never shipped

Two files must contain **absolute** paths (the engram MCP server's binary and its
database), so a tracked copy would hand every operator the previous one's home —
exactly what `/home/<user>/...` did in this tree. They follow the `.env.example`
pattern instead:

| Shipped (tracked) | Rendered (gitignored) |
|---|---|
| `opencode.json.example` | `opencode.json` |
| `.pi/mcp.json.example` | `.pi/mcp.json` |

Placeholders `__YMIR_HOME__` and `__YMIR_ROOT__` are substituted with `$HOME` and
the checkout root by `bin/valknut-load.sh` (its `render_config`, run for both
`--pi` and `--opencode`). It is idempotent: identical content is left alone and
reported as `unchanged`.

Rule: **if a config must hold an absolute path, it is generated from an
`.example`, not committed.** The same applies to launchers — a `.desktop` file
is one OS's answer and must be produced for the host, not shipped for all.

## Omarchy-first: the core is portable, the desktop is Omarchy's

Ymir is an **Omarchy-first** system. That is a design statement, not a
restriction — it says which desktop integration is first-class, not which
machines may run the runtime.

**Two layers, deliberately separate:**

| Layer | Runs on | What it owns |
|---|---|---|
| **Portable core** | Linux, macOS, Windows (WSL2; MSYS best-effort) | the runtime — session digest, lock, watch, cron, skills — the installer's user-space prerequisites, the capability shim, generated machine config |
| **Omarchy layer** | Omarchy only | recording the host (`omarchy-sense observe`), placing each app on its own numbered Hyprland desktop (`desktop-place`), the launcher entries (`.desktop`), the suggested shell plugins, the post-update hook |

The core never grows a Hyprland branch, and the Omarchy layer is never stretched
into pretending it is portable. An Omarchy-specific step is gated on the host and
reports a clean skip anywhere else:

```bash
[ -d /usr/share/omarchy ] && ... || add host OK "... (not an Omarchy host)"
```

That is why the only Omarchy branches left in the core installer are the ones
that call the layer (`step_omarchy`) and desktop placement (`step_desktop`):
`step_host` senses the host portably with `host-sense`, and everywhere else the
same code path runs on any host.

The **consent preamble** the installer prints before it acts says the same thing —
*"learn this machine (OS, desktop, packages, configs, monitors, scale — Omarchy
hosts recorded first-class)"* — so the operator is told what will happen in the
portable terms the code now uses, not the Omarchy-only terms it used before.

### What the Omarchy layer installs

```bash
bin/omarchy-sense.sh observe          # learn packages, configs, Omarchy version
bin/omarchy-plugins.sh add            # the suggested shell plugins (never forced)
bin/omarchy-hook-install.sh install   # re-learn after every `omarchy update`
bin/desktop-place.sh apply            # Hyprland desktops + launcher entries
```

`desktop-place.sh apply` does both halves of the desktop integration: it writes
the Hyprland window rules that give each Ymir app its own numbered desktop, and
it renders the launcher templates into `~/.local/share/applications/`. The
templates (`apps/hlidskjalf/electron/*.desktop.in`) carry `__YMIR_ROOT__` rather
than an absolute path, because where the checkout lives is a fact about the
machine, not about Ymir.

**Rule:** `RULES/05-platforms.md` — a core change updates every
platform layer in the same change.

**Rule for a new desktop feature:** if it is Omarchy-specific, it belongs in the
Omarchy layer and is gated; if it is core, it must work on every platform. Do not
blur the two — a branch of Hyprland logic inside a core script is how a portable
runtime stops being portable.

### A move must carry the memory, not just the code

Rule 06 makes this explicit, because a home swap here dropped
`docs/append-only-log.md`, `docs/masterplan.md`, `docs/plans/` and the private
business set: the backup carried `state`, `.env.local`, `data`, the realm and
`workspace` — but not `docs/` or `assets/`. The code arrived; the memory did not.

Before and after any migration, re-clone or swap, check the sets **by name**:

```bash
for f in CHANGELOG.md docs/append-only-log.md workspace/memory/runes_audit.md; do
  [ -e "$f" ] || echo "MISSING append-only artifact: $f"
done
ls "$YMIR_HOARD/docs" "$YMIR_HOARD/identity" 2>/dev/null    # the private set
```

A backup is only as good as its file list. If a directory is not named in the
backup, it is not carried.

### The memory engine is provisioned, not hinted (2026-09-12)

`bin/ymir-install.sh` used to *check* for the well engine and, failing, print
`SKIP "optional — install engine then run bin/mimir-bridge.sh"`. A SKIP never
blocks, so the well was silently down on every install — and the hint named the
wrong package, so following it made things worse.

Now the installer provisions it: `bin/prereq-ensure.sh engram` installs
**`engdbram`** (the distribution; the *module* is `engram`) into an interpreter
that can run it (>=3.11; uv supplies 3.12 when the distro's Python is unsuitable),
and records that interpreter in `~/.config/ymir/engram-python`. `bin/mimir-bridge.sh`
reads the same file, so the installer and the bridge always agree.

```bash
bin/prereq-ensure.sh engram        # install and record the interpreter
bin/mimir-bridge.sh --start        # the :4602 face over the engine
curl -s 127.0.0.1:4602/health      # {"status": "up", "store": ".agents/memory/kaia.engram"}
```

**Never `pip install engram`.** PyPI's `engram` is an unrelated rendering library
(mitsuba/drjit/torch) whose install pulls gigabytes of CUDA wheels and still
leaves Ymir with no engine. The prerequisite target exists so nobody has to know
that: `bin/prereq-ensure.sh engram`.

### The rename sweep broke governed paths, not just prose (2026-09-12)

The `smidja` → `smidja-factory` rename left `smidja-factory-factory` behind in
**seven** places — `scripts/start.sh` (`VIZ_DIR`), `bin/ymir-validate.sh`,
`bin/ymir-install.sh` (twice: the dist probe and the build dir),
`bin/saga-session-start.sh` (the governed-path TOON row), `AGENTS.md` (the
`governed[]` table, twice) and the guard's own `asset_for` pattern.

The damage was not cosmetic: a governed path that does not exist makes the
pretool guard stop matching, so the smidja rule protected nothing while every
check still passed. A `governed` check now exists in
`compliance-check.sh` for exactly this class (see `runtime-compliance.md` §G13);
it reports `all 25 governed paths exist`.

`bin/ymir-install.sh` and `bin/ymir-validate.sh` are the two files of this asset
that the sweep corrected. The visualizer path is
`.agents/skills/smidja-factory/apps/visualizer` — **not** a doubled
`smidja-factory-factory`, and not the abandoned `.agents/skills/smidja/` tree
(stale build output, moved aside).
