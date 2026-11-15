# Desktop settings per user — `desktop.env`

## What it is

One file in your home that tells every desktop app how to draw itself: whether to use the
GPU, which surface to open on, and where a window lands. It is yours, per user and per
machine, and no app hardcodes the answer.

The house already knew this for the *machine*: `bin/host/graphics-lib.sh` decides whether a
hybrid graphics card can render safely. This file is the *person's* answer, and it wins.

## What you need

- A Ymir home (`$YMIR_HOME`, by default `~/Documents/ymirhome`).
- Nothing else. If the file is absent every app behaves exactly as before.

## The commands

```bash
cp ~/ymir/.agents/config/desktop.env.example "$YMIR_HOME/config/desktop.env"
$EDITOR "$YMIR_HOME/config/desktop.env"
```

Restart the app that should pick it up:

```bash
bin/desktop/sessrumnir-launch.sh start     # Sessrúmnir
scripts/electron.sh start --view hlidskjalf
```

See what will be used, before you launch anything:

```bash
bash -c '. bin/host/graphics-lib.sh; desktop_env_load; echo "gpu=$YMIR_DESKTOP_DISABLE_GPU ozone=$YMIR_DESKTOP_OZONE_PLATFORM policy=$(graphics_policy)"'
```

## The keys

| Key | Values | What it does |
|---|---|---|
| `YMIR_DESKTOP_DISABLE_GPU` | `auto` · `1` · `0` | `auto` asks the machine; `1` renders in software; `0` uses the card |
| `YMIR_DESKTOP_OZONE_PLATFORM` | `auto` · `wayland` · `x11` | which surface the window opens on |
| `YMIR_DESKTOP_PIN` | `1` · `0` | `1` opens every app on the desktop you started it from |

An environment variable you set yourself always beats the file, so a single launch can be
tested without editing anything:

```bash
YMIR_DESKTOP_OZONE_PLATFORM=wayland bin/desktop/sessrumnir-launch.sh start
```

## Limits

- The file is read **at launch**; an app that is already open keeps its settings.
- `auto` for the ozone platform means: on a Wayland session with the GPU off, the window
  opens through XWayland. Measured on heimdall 2026-11-14: a GPU-less Electron window does
  not map on Wayland at all, so an app looked like it "started over and over" while a
  window existed that nobody could see.
- The file lives in the private home. Never commit it to the public tree.

## If it does not work

- Nothing changed: check the path — `bash -c '. bin/host/graphics-lib.sh; desktop_env_path'`
  prints the exact file the launchers read.
- An app still refuses to open a window: set `YMIR_DESKTOP_OZONE_PLATFORM=x11` and relaunch.
- A hybrid machine crashes in the GPU process: leave `YMIR_DESKTOP_DISABLE_GPU=auto`.

## CHANGE LOG

- **2026-11-14** — written with the desktop door: one file in the home answers for the person, every launcher reads it, an exported variable still wins.
