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

## Maintaining this

- **Owner:** Brokk. **Router:** `.agents/skills/galdr/SKILL.md`.
- Upstream Omarchy skill is authoritative for Omarchy itself; keep only Ymir's
  integration facts and this machine's hard-won lessons here.
- When the desktop behaviour changes, update this asset and
  `assets/hlidskjalf-ui.md` together.
