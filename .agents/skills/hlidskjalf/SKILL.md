---
name: hlidskjalf
description: >-
  Hlidskjalf — the control plane UI (Odin's high seat). Load when working on or
  debugging the web control plane, the gate API, login/session auth, the Fleet of
  agents, the Electron desktop shell, or the Cloudflare tunnel. Not for the
  terminal backend (that is the herdr skill) or the smithy (the smidja skill).
allowed-tools: read,write,bash,glob,grep
---

# hlidskjalf — the control plane UI: SPA · gate API · auth · desktop · tunnel

The single control plane: a React SPA + a Bun gate API, opened in the browser or
the Electron desktop shell. Odin sees all realms from here.

## Surfaces

```
surfaces[5]{part,where,note}:
  "SPA",":3888 (vite) / built dist served by the gate",React app; gates: Fleet, Chat, Runes, …
  "gate API",":3889 (bun apps/hlidskjalf/server/index.ts)","auth + /api/* + serves dist/; static types + caching"
  "login","in-app modal → /api/login → session cookie","user/pass from .env.local HLIDSKJALF_AUTH; Heimdall (oauth2-proxy) is the target"
  "desktop","apps/hlidskjalf/electron/main.cjs + scripts/electron.sh","single instance + one window (never stack); see the ymir skill assets/desktop.md"
  "tunnel","gjallarhorn → ymirdell.zerwiz.org → :3889","outbound only; `bin/gjallarhorn-tunnel.sh`"
```

## Rules

- **One login, one window** — no GitHub hop before Heimdall; auth stays in-window.
- **Gate API protects `/api/*`** and serves the SPA; 401 → `ymir:unauthorized`.
- **No secrets inline** — `HLIDSKJALF_AUTH` from `.env.local`.
- **Electron:** single-instance lock; `openWindow` reuses the live window.
- Raise/repair: `scripts/start.sh`; if the window is gone but ports answer, the
  shell must be restarted (backend ≠ window).

Full reference: `.agents/skills/galdr/assets/hlidskjalf-ui.md` and the private
plan `hodd/docs/electron-auth.md`.
