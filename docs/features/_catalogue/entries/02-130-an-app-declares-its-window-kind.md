---
section: agents-work-collaboration
---
| Apps | An app declares its window's kind — Electron or Tauri | `kind:` in the app's own `app.yaml` (one value, or per platform) and `launch: tauri: <platform>:` tell `ymir-app` which window to open; the same door and the same launcher icon open either, and `YMIR_APP_KIND_<APP>=tauri` tries the Tauri window once without editing anything | [docs/features/apps-install-and-update.md](docs/features/apps-install-and-update.md) |
