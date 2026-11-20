# install · 2026-09-24 — the install itself guarantees the apps run, and are routed right

## Why
Wrong-app routing was real, and it was a class-name mismatch. `bin/seat/sessrumnir/desktop-place.sh`
declared `CLASS_sessrumnir="sessrumnir"` while the Electron app actually presents
`ymir-sessrumnir` (read live from `hyprctl clients`); so both the generated window
rule (`~/.config/hypr/ymir-desktops.lua`) and the entry's
`StartupWMClass=sessrumnir` in `apps/sessrumnir/resources/ymir-sessrumnir.desktop.in`
matched nothing. Net effect: every Ymir key appeared to open the same app, and
`SUPER+O` (Óðrerir, which has no runtime of its own) could never open.

And there was no hardware sense in the graphics dimension, no launch check, and
no watcher: `bin/host/omarchy-sense.sh` recorded monitors but was blind to GPUs;
`bin/agents/eir-doctor.sh`'s `shells` surface treated a missing runtime as healthy and
was never called automatically. The install "succeeded" while nothing opened.

## What
- **Routing proven, not assumed (P5)** — `CLASS_sessrumnir` → `ymir-sessrumnir` in
  `bin/seat/sessrumnir/desktop-place.sh`, `StartupWMClass=ymir-sessrumnir` in the desktop.in. The
  class NAME is now ONE source, `app_class` in `bin/seat/sessrumnir/app-lib.sh`, read by
  desktop-place, the verifier, and the test.
- **`bin/seat/sessrumnir/desktop-verify.sh` (new, P4)** — per surface (hlidskjalf · smidja ·
  odrerir · sessrumnir): the resolver yields an executable binary, it answers
  `--version`, with a compositor present a window of the expected class is held,
  AND the invariant that the `.desktop` StartupWMClass == generated window rule
  == installed launcher == the slug the app's source sets. Fails loudly, naming
  surface and resolved path. Called by the desktop step of `bin/engine/ymir-install.sh`
  (`--check` and real install) and used with `--live` after the raise.
- **Graphics sense (P6)** — `bin/host/omarchy-sense.sh`'s snapshot gains a `graphics`
  block (DRM cards + render nodes + drivers, display card, integrated/discrete/
  hybrid, version, effective GPU policy) from `bin/host/graphics-lib.sh`; status shows
  it. The installer consumes it.
- **Eir sees, and runs (P8)** — `bin/agents/eir-doctor.sh`'s `shells` uses the resolver;
  absence for an installed app is a FAILURE (only an uninstalled app is skipped);
  a `graphics` surface reports the sense block and policy. Eir is reached by the
  update path (`bin/agents/groa-update.sh`) and by a new Nornir job
  (`bin/time/nornir-job-doctor.sh`, `08:15` in `config/cron.yaml.example`).
- `bin/bridge/ymir-plan.sh`'s electron row and `bin/engine/ymir-install.sh`'s SPA check use the
  resolver too.

## Verified
- `bin/seat/sessrumnir/desktop-verify.sh --class-only` on heimdall first caught the stale rule
  (`no rule for ymir-sessrumnir`), then — after `bin/seat/sessrumnir/desktop-place.sh apply`
  regenerated the rules — all four surfaces agree
  (template · rule · launcher · app source).
- `.agents/tests/desktop-classes.test.sh` holds the invariant in the tree.
- `bin/host/omarchy-sense.sh observe` recorded `gpu_policy: software`,
  `classification: hybrid`, `card2 i915 renderD129 integrated`.
- `bin/agents/eir-doctor.sh check` reports shells red on a runtime-less tree and exits 1.

## Files
- `bin/seat/sessrumnir/desktop-verify.sh` (new) · `bin/seat/sessrumnir/app-lib.sh` · `bin/seat/sessrumnir/desktop-place.sh`
- `apps/sessrumnir/resources/ymir-sessrumnir.desktop.in`
- `bin/host/omarchy-sense.sh` · `bin/agents/eir-doctor.sh` · `bin/agents/groa-update.sh`
- `bin/time/nornir-job-doctor.sh` (new) · `config/cron.yaml.example`
- `bin/engine/ymir-install.sh` · `bin/bridge/ymir-plan.sh` · `.agents/tests/desktop-classes.test.sh`