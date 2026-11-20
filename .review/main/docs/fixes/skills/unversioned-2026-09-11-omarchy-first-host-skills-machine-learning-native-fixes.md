## skills · unversioned · 2026-09-11 — Omarchy-first: host skills, machine learning, native fixes

### Why
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
  `amdgpu: Not e

### Files
- *(carried from the frozen CHANGELOG.md)*
