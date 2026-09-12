---
name: ymir
description: >-
  Operating the Ymir host itself. Load the asset a task needs: self-update
  (Brokk + every Eindri-home via /updateBrokk), Omarchy-native desktop operation
  (Hyprland, shell/bar, monitors, window rules, placement, GPU/Wayland, any
  ~/.config file), and the Þjazi terminal backend (herdr/tmux selection,
  protocol floors, panes, presentation spaces). One skill for the machine.
allowed-tools: read,write,bash,glob,grep
user-invocable: true
metadata:
  internal: true
---

# Ymir — operating the host

One skill for running the machine Ymir lives on. Read the row the task needs,
then the asset it points to.

```
assets[5]{path,load_when}:
  "assets/update.md","self-update Brokk + every Eindri-home (updateBrokk / /updateBrokk)"
  "assets/omarchy.md","Omarchy host: Hyprland, shell/bar, monitors, placement, GPU, ~/.config"
  "assets/thjazi.md","the terminal backend: herdr/tmux, protocol floors, panes, spaces"
  "assets/runbooks.md","operator runbooks: models · agents · Tailscale sync · updates/migrations · secrets/Hodd"
  "assets/desktop.md","the Electron desktop shell (Hlidskjalf/Smíðja): single instance, one window, auth, recovery"
```

A change that adds a host capability adds a row here, not a new skill.

Rule 06 (append-only) governs the memory: the Runes ledger, the
changelog, `docs/append-only-log.md` and the rules are appended to, never
rewritten — and a move must carry every one of them plus the hoard.
Law: `RULES/06-append-only.md`.
