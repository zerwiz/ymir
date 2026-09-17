## 2026-09-17 — the editor stops being banished to its own desktop

- **`bin/editor-place.sh` pinned the editor to its own desktop with
  `no_focus = true`** — VS Code mapped onto a different workspace than the one
  the Allfather worked on and never took focus, so nothing inside it was
  clickable. The rule was written by Ymir itself into
  `~/.config/hypr/ymir-desktops.lua`.
- **The editor is now UNMANAGED by default**: it opens on the active desktop,
  focused and clickable, like any other app. The old pin remains reachable
  explicitly with `YMIR_EDITOR_PIN=1 bin/editor-place.sh apply`.
- Live desk healed: the `code` windowrule was removed from
  `~/.config/hypr/ymir-desktops.lua` (backup kept alongside), Hyprland reloaded
  with no config errors, and the stranded VS Code windows were moved to the
  active desktop and focused.
