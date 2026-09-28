## hlidskjalf · 2026-09-27 · 2026-09-27 — the iOS shell is scaffolded beside the Android one

### Why
The Hlidskjalf SPA already ships a PWA manifest and a Capacitor Android shell; iOS was the missing native wrapper. Added @capacitor/ios and scaffolded the Xcode project at apps/hlidskjalf/ios so it can be opened and built on a Mac. The shell reuses the same web app and reads YMR_SERVER_URL (default http://127.0.0.1:3888), so an operator points it at their HTTPS host (Tailscale serve or the tunnel) with no code change.

### Files
- `apps/hlidskjalf/package.json`
- `apps/hlidskjalf/ios`