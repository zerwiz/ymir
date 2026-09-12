---
name: ymir-omarchy
description: >-
  Omarchy-native operation for Ymir. REQUIRED whenever the task touches the host
  desktop: Hyprland, the Omarchy shell/bar, themes, monitors, window rules,
  keybindings, idle/lock, night light, screenshots, reminders, or any file under
  ~/.config/hypr/ or ~/.config/omarchy/. Also use when placing the Ymir desktop
  apps (Hlidskjalf / Smíðja) on a screen, when a native crash involves the GPU or
  Wayland, and to help the Allfather set up or tune the Omarchy machine Ymir runs
  on. Load this before editing any ~/.config/ file on an Omarchy host.
allowed-tools: read,write,bash,glob,grep
---

# Ymir on Omarchy

Ymir runs *on* Omarchy — an opinionated Arch Linux + Hyprland distribution. On an
Omarchy host, the desktop is not a detail: it decides where our windows land, how
they render, and whether the GPU process survives. This skill is how Ymir is a
good citizen of that machine.

**Router:** `.agents/skills/galdr/SKILL.md`. **Upstream skill (authoritative for
Omarchy itself):** `/usr/share/omarchy/default/agents/skills/omarchy/SKILL.md` and
`~/.pi/agent/skills/omarchy/`. Read that one for pure Omarchy work; this one adds
the Ymir integration and the hard-won facts below.

## The two laws

```
omarchy_laws[2]{id,law}:
  "1","Never edit anything under /usr/share/omarchy/ — it is package-owned and overwritten on update. Reading it is safe and encouraged. Edit ~/.config/ instead."
  "2","Hyprland owns window placement, not the app. Let the compositor place windows; the app must not fight it."
```

## Detecting the host

```bash
# Are we on Omarchy at all? (never assume)
[ -d /usr/share/omarchy ] && echo "Omarchy host"
omarchy version 2>/dev/null || true
hyprctl monitors -j 2>/dev/null | head -c 200
```

Ymir must work on a non-Omarchy host too. Every Omarchy-specific behaviour is
gated on `[ -d /usr/share/omarchy ]`; nothing here may break a plain Arch box.

## Monitors, scale, and the coordinate trap

**The fact that costs the most time:** on Omarchy the panel may run at a
fractional scale (e.g. a 1920×1200 panel at `scale 1.5` is a **1280×800 logical**
desktop). An app that computes window geometry from *physical* pixels will be
wrong by the scale factor and will fill the whole screen.

```bash
hyprctl monitors -j        # name, id, width, height, scale, focused, x, y
```

- `hyprctl` reports **physical** width/height **and** `scale`.
- Electron's `screen` API reports **logical** (already-scaled) bounds.
- Logical = physical / scale. Never mix the two.

### Placing the Ymir desktop apps

Hlidskjalf and Smíðja are dashboards the Allfather keeps *beside* his work, so
they belong on a **non-primary** display when one is attached, and on the primary
when it is not (the laptop case). Two rules:

1. **Prefer a secondary display**, never the focused/primary one, when
   `screen.getAllDisplays().length > 1`.
2. **Clamp to the display's work area** in *logical* units, and center there. A
   window wider than the logical desktop must be shrunk, not pushed off-screen.

Identity of a display is its `id`; `screen.getPrimaryDisplay()` is the one to
avoid. If only one display exists, do nothing clever — center it and move on.

## The GPU / Wayland crash (amdgpu)

Observed on this class of machine (AMD Cezanne iGPU with a **512 MB** VRAM
carve-out, plus a discrete NVIDIA card):

```
kernel: amdgpu 0000:08:00.0: [drm] *ERROR* Not enough memory for command submission!
electron[PID]: segfault at 0 error 4 in electron
```

Electron's `--type=gpu-process` dies with `SIGSEGV` when the iGPU cannot satisfy a
command submission. It is **not** an Electron bug in our code and **not** an OOM
(it happens with plenty of system RAM). Diagnose it properly:

```bash
coredumpctl list | grep electron          # a pattern, or a one-off?
journalctl --since "<t-1min>" --until "<t+1min>" | grep -i 'amdgpu\|drm\|segfault'
cat /sys/class/drm/card*/device/mem_info_vram_used   # VRAM actually in use
```

**Mitigation for dashboards** (they are not 3D apps):

```bash
YMIR_DESKTOP_DISABLE_GPU=1 scripts/electron.sh start --both   # software rendering
```

`scripts/electron.sh` reads that variable and adds `--disable-gpu
--disable-gpu-compositing`. Use it on a small-VRAM iGPU; leave GPU on where the
discrete card drives the display.

## Starting the Ymir apps

```bash
scripts/electron.sh start --both        # Hlidskjalf + Smíðja, separate apps
scripts/electron.sh status              # is each one REALLY running?
scripts/electron.sh stop
```

**Do not track an Electron app by the pid returned from `.bin/electron`** — that
is a node shim which *spawns* the real binary, so the pid is wrong and a second
launch will stack on the first. Track it by its own command line (the per-view
`--user-data-dir` is the stable identity), which is what `electron.sh` does.

## Safe customisation (the short version)

| Want | Do |
|---|---|
| Bar / widgets / idle | edit `~/.config/omarchy/shell.json`, then `omarchy restart shell` |
| Keybindings, gaps, monitors | edit `~/.config/hypr/*.lua`, then `hyprctl reload` + `hyprctl configerrors` |
| Theme | `omarchy theme set <name>`; customise in `~/.config/omarchy/themes/<name>/` |
| Reminder | `omarchy reminder <minutes> "text"` |
| Screenshot / record | `omarchy capture screenshot` · `omarchy screenrecord --fullscreen` |
| Night light | `omarchy toggle nightlight` |
| Lock after idle | `idle.lock` in `~/.config/omarchy/shell.json` |
| Install a package | `omarchy pkg add <pkg>` (AUR: `omarchy pkg aur add <pkg>`) |
| Debug | `omarchy debug --no-sudo --print` (always these flags) |

Always back up a config before editing it: `cp f f.bak.$(date +%s)`.

## Discovery

```bash
omarchy commands                 # every documented command
omarchy <group> --help           # omarchy theme|refresh|restart|toggle|bar|...
omarchy commands --json          # machine-readable
cat $(which omarchy-theme-set)   # read a command's source (safe)
```

## Being useful to an Omarchy user

When the Allfather wants his machine set up or tuned, Ymir should *help* rather
than merely not-break: report the monitor layout and scale, propose a sane window
placement for the dashboards, offer the GPU mitigation when the iGPU is small,
and use `omarchy` commands rather than raw edits wherever one exists. Offer a
backup before every config change, and never run `omarchy refresh <x>` (which
resets config) without explicit confirmation.

## The editor (Pi's `/edit`)

Pi ships a user-facing **Open Editor** extension (`.pi/extensions/open-editor.ts`) that
opens files from the working directory in the Allfather's own editor. It is
**strictly his** — no LLM tool is registered, because agents already have `read`
and `edit`. Know it, name it when he would reach for it, and never try to drive it
yourself.

```
editor_surface[2]{key,what}:
  "/edit [path]","slash command with tab-completion over cwd files; no path opens the directory itself"
  "ctrl+shift+e","file picker over cwd"
```

**How the editor resolves:** `$VISUAL` → `$EDITOR` → **the first editor that
actually exists** on the host, tried in this order: `code cursor zed subl nvim vim
hx helix nano micro emacs vi`. A **terminal** editor (nvim, vim, helix, nano,
emacs) blocks Pi while open — the TUI suspends and resumes on exit. A **GUI**
editor (code, cursor, zed, subl) launches detached, so Pi stays interactive.

**Why the existence check matters off Omarchy:** the old fallback was a bare `vi`,
and `vi` is **absent on this very machine** — as it is on many minimal hosts. A
configured editor that is not installed no longer poisons the chain: the extension
probes `$PATH` and falls through to one that is real. So `/edit` works on a plain
Arch box, a Debian box, or anything else where Omarchy's launcher does not exist.

### Choosing the editor (Omarchy forces its own)

Omarchy **hard-sets** `EDITOR` twice — `${EDITOR:-omarchy-launch-editor --inline}`
in `default/bash/envs`, and a forced value in `default/uwsm/default`. A user
override therefore goes in the uwsm user dir, which is sourced **after** the
defaults:

```
~/.config/uwsm/env.d/10-ymir-editor:
  export EDITOR="code"       # a GUI editor, so no --wait: it launches detached
  export VISUAL="code"
```

(`--wait` is wrong for a GUI editor — VS Code hands the file to the running
instance and exits, so waiting holds nothing.) Changes need a session restart.

### The editor gets its own desktop

The editor must not open on the desktop the Allfather is reading. Hyprland applies
window rules **at map time**, so the window never appears there at all:

```
bin/editor-place.sh plan      # which desktop it would take
bin/editor-place.sh apply     # write the rule + hyprctl reload
```

It writes into the SAME `~/.config/hypr/ymir-desktops.lua` the apps use (so one
file owns every Ymir window placement) and re-derives the app rules rather than
clobbering them:

```lua
o.window({ class = "^code$" }, { workspace = "7", no_focus = true })
```

**`no_focus = true` is the load-bearing half.** Without it the window is placed on
the right desktop but **the focus follows it** — the Allfather is dragged off his
own desk. Omarchy's own `default/hypr/windows.lua` uses the same idiom. Always
verify with `hyprctl configerrors` (must be empty) after a reload.

**The dispatch road does NOT work here.** This Hyprland (0.56) replaced the classic
dispatch interface with a Lua API: `hyprctl dispatch movetoworkspacesilent
5,class:...` fails outright, and `keyword` reports "can't work with non-legacy
parsers — use eval". The map-time rule file is the road that holds.

When the Allfather wants to *look at* a file rather than have it read aloud, the
answer is `/edit <path>` — say so plainly instead of pasting its contents.

## Ymir speaks on the desktop

Ymir works for hours unwatched, so when something is worth knowing it says so
where the Allfather already is. `bin/ymir-say.sh` is the **single owner** of that
manner — anything with news calls it, so the voice cannot drift.

```
bin/ymir-say.sh "<headline>" ["<body>"]            # a plain note
bin/ymir-say.sh --mark-done  "<what>" ["<detail>"] # a job finished (low urgency)
bin/ymir-say.sh --mark-alarm "<what>" ["<detail>"] # needs his word (critical)
bin/ymir-say.sh --mark-fail  "<what>" ["<detail>"] # something broke (critical)
bin/ymir-say.sh status                              # what has been said
```

It speaks through Omarchy's own notifier (`omarchy-notification-send`) when
present, else `notify-send`, and always records the line in
`state/ymir-said.log` — so a popup missed is a line still found. On a host with
neither, the line is recorded and it says "record only"; a silent host is never a
lost message.

**Who speaks through it:** the wedge alarm (`bin/wedge-notify.sh`, when an
escalation cannot reach a wedged pane) and the crash watcher (`bin/crash-sense.sh`, a
new `coredumpctl` entry). Both route to `ymir-say.sh` so urgency, glyph, and app
identity stay one voice.

## Maintaining this

- **Owner:** Brokk. **Router:** `.agents/skills/galdr/SKILL.md`.
- Upstream Omarchy skill is authoritative for Omarchy itself; keep only Ymir's
  integration facts and this machine's hard-won lessons here.
- When the desktop behaviour changes, update this asset and
  `assets/hlidskjalf-ui.md` together.

## Platform layers (Rule 05)

Ymir is **Omarchy-first**, not Omarchy-only. The core is portable; Omarchy is the
first-class installation layer on top of it. Anything below that assumes Hyprland
or `/usr/share/omarchy` is this layer's business and is gated on the host — on a
Mac or on WSL those steps report a clean skip and the core still runs.

When a core feature changes, this layer is updated in the same change
(`RULES/05-platforms.md`). Details: `galdr/assets/installation.md`.

### Electron GPU-process crashes on the shared-memory iGPU

Both dashboards can look healthy while `coredumpctl` fills with SIGSEGV cores
from `electron --type=gpu-process` and the kernel logs `amdgpu … Not enough
memory for command submission`. Only the GPU process dies, so the failure is
easy to miss.

The iGPU backs its graphics memory with system RAM (GTT), and a local model
served on that same iGPU holds several GiB of it — after which the driver fails
the desktop's command submissions. `scripts/electron.sh` now detects a small VRAM
carve-out (`igpu_vram_small()`, threshold `YMIR_IGPU_VRAM_SMALL_MIB`, default
2048) and runs the dashboards on software rendering; `YMIR_DESKTOP_DISABLE_GPU`
forces either path. Detail and the evidence: `galdr/assets/hlidskjalf-ui.md`.
