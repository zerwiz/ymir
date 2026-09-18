## install · unversioned · 2026-09-11 — Desktop shell, tunnel, and temporary auth

### Why
- **Electron:** `apps/hlidskjalf/electron` + `scripts/electron.sh` open Hlidskjalf
  (and Smiðja) as a native window; raises the stack if down.
- **Tunnel:** `ymirdell.zerwiz.org` → `:3889` via `bin/gjallarhorn-tunnel.sh`
  (cloudflared config in `midgard/infrastructure/ingress/cloudflared-ymir.yml`).
- **Auth:** hardcoded HTTP Basic (`zerwiz:allfather`, `HLIDSKJALF_AUTH`) on the
  gate API, which now also serves the built SPA. Temporary — move to Heimdall +
  `.env.local`.
- **Mobile:** PWA manifest added; recommended APK = Capacitor over the tunnel.

### Files
- *(carried from the frozen CHANGELOG.md)*
