## runtime · unversioned · 2026-09-16 — Omarchy-first, host-aware: Windows and macOS get a door

### Why
- **`bin/host-sense.sh`** — the one place that looks before anything acts. It
  reports THIS machine: distro and family, kernel, arch, platform (linux · wsl ·
  macos · windows), session (Wayland/X11), desktop, compositor, package manager,
  and what the desktop can actually *do* — `placement`, `launcher`, `tray`. No
  layer may assert a machine it is not standing on.
- **Omarchy stays first-class, and is now gated.** `bin/omarchy-sense.sh` opens
  by asserting *"Ymir runs on an Omarchy host"*; on any other host it now skips
  cleanly and points at `bin/host-sense.sh`, rather than recording the wrong
  machine. That is Rule 05's own rule: a layer is gated on its host.
- **Windows has a door:** `bin/bootstrap-windows.ps1` — enables WSL2, installs
  Ubuntu, then hands the work to `bin/ymir-install.sh` inside the distro. It is
  honest about needing elevation and about the one reboot a fresh machine needs.
- **macOS has a door:** `bin/bootstrap-macos.sh` — raises Ubuntu in a Lima VM and
  installs Ymir inside it, plus `packaging/macos/Ymir Installer.command`, a
  double-clickable launcher for an operator who should not need a terminal.
- **The installers themselves:** `packaging/build.sh --exe|--mac|--check`, the
  NSIS script `packaging/windows/ymir-setup.nsi` (→ `Ymir-Setup.exe`), and
  `.github/workflows/ymir-installers.yml`, which builds the exe on an Ubuntu
  runner (NSIS is 

### Files
- *(carried from the frozen CHANGELOG.md)*
