# Installation & First Setup — stand the whole system up

> **Purpose:** Everything Galdr must know to install, provision, and repair
> Ymir for an operator who does not have it. The code is authoritative; this
> page is the map.

One command sets up the whole system for the user; it self-heals what it can and
reports what it cannot. It **asks for consent first** (accept the plan, or pass
`--yes` for non-interactive use), and it **validates at the end** that what it
claims is actually running.

```
bin/ymir-install.sh               # the first setup (idempotent; asks to proceed)
bin/ymir-install.sh --check       # report only, no writes, no prompt
bin/ymir-install.sh --yes         # non-interactive (accept the plan)
bin/ymir-install.sh --skip-engines --skip-services
bin/ymir-install.sh --no-desktop  # don't open the desktop apps at the end
bin/ymir-install.sh --status      # alias of --check
```

## The steps

```
install[16]{step,what,self-heals}:
  "prereqs","git python3 bun docker gh · mcp<2","bin/prereq-ensure.sh installs bun+uv+mcp in user space; engram is an honest optional SKIP"
  "memory-well","the engram engine (Mimirsbrunn)","optional; reported with the exact next command, never a fake fix"
  "tree","workspace/{work,personal}/<domains>, companies/, workspaces.yaml, projects.yaml","creates if missing"
  "engines","treehouse · sandcastle · no-mistakes","installs treehouse + no-mistakes from their installers"
  "hermes","the Nous Research agent runtime","installs via bin/hermes-ensure.sh when absent"
  "backend","Þjazi — herdr (protocol 14+) or tmux","bin/herdr-ensure.sh detects/tests version, installs via the pinned installer or falls back to tmux"
  "omarchy","the host machine (Omarchy)","bin/omarchy-sense.sh learns the setup; bin/omarchy-hook-install.sh adds the post-update hook"
  "sandbox","utgard-runner:latest image","builds via bin/utgard.sh build; distinguishes docker-group permission from build failure"
  "memory","engram store + harness MCP registrations","raises the bridge; reports MCP coverage"
  "smidja","smidja/smidja_data/smidja.db","bin/smidja-bootstrap.sh creates it from the tracer schema + a bootstrap session"
  "visualizer","the Smíðja visualizer UI (Vue, served on :8437)","builds ./dist with bun when absent — the API serves the UI from dist, and without it the API answers but shows no interface"
  "loaders","agents/skills into the harnesses","runs bin/valknut-load.sh"
  "register","workspace/INSTALL.md","writes the record"
  "services","gate API, SPA, Nornir, bridges, visualizer","raises via scripts/start.sh (which builds the visualizer UI when ./dist is absent)"
  "desktop","Hlidskjalf + Smíðja desktop apps","bin/desktop-place.sh puts each on its OWN numbered desktop (preferring EMPTY ones); scripts/electron.sh start --both self-heals the Electron binary"
  "validate","the running system","bin/ymir-validate.sh — live port/store/process checks"
```

A real run prints **16** rows. `--check` prints **13** — it skips the
runtime-only steps (`services`, `desktop`, `validate`), which have nothing to
report when the runtime is not raised. (`memory-well` is emitted by the
`prereqs` step, so the row count exceeds the step count.)

## The visualizer UI

The Smíðja visualizer **API** runs on `:8437` and serves its **UI** from
`apps/visualizer/dist`. A fresh clone has no `dist`, so the API answers but shows
"No ./dist build found" — an install gap. The installer (and `scripts/start.sh`)
now build it when absent:

```bash
(cd .agents/skills/smidja/apps/visualizer && bun run build)   # vue-tsc + vite
```

`bin/ymir-validate.sh` reports `visualizer` FAIL when `./dist` is missing, so the
gap cannot silently return.

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
`HERDR_ENV=1` → else tmux. Full reference: the `ymir-thjazi` skill.

## Consent

A real install prints its plan and waits for `[y/N]`. Declining changes nothing
(exit 3). `--check` never prompts. A non-interactive caller without `--yes` is
refused rather than silently proceeding.

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

## Per-workspace provisioning

```
bin/workspace-provision.sh <name> --kind work|personal [--domains a,b,c] [--company wayof]
```

Creates `workspace/<name>/<domains>/`, registers it in `workspaces.yaml`, and
for a **work** workspace attaches it to the company container
`svartalfaheim/<company>/`.

## Verify

```
bin/ymir-install.sh --check          # all steps OK/WARN
bin/ymir-validate.sh                 # the running system actually works
bin/herdr-ensure.sh status           # the Þjazi backend and its protocol floor
bin/omarchy-sense.sh status          # what Ymir has learnt about this host
bin/saga-session-start.sh            # the session digest
bash .agents/skills/galdr/scripts/compliance-check.sh
```

On an **Omarchy** host the installer also learns the machine
(`bin/omarchy-sense.sh`) and installs a `post-update` hook so Ymir re-learns it
every time Omarchy updates. On a non-Omarchy host that step is a clean SKIP.

Rule: the installer is **idempotent** — running it again changes nothing but
fills gaps. It never overwrites real user data.
