## install · unversioned · 2026-09-11 — Desktop shell, tunnel, and temporary auth

### Why
- **Electron:** `apps/hlidskjalf/electron` + `scripts/electron.sh` open Hlidskjalf
  (and Smiðja) as a native window; raises the stack if down.
- **Tunnel:** `<host>.example.org` → `:3889` via `bin/forge/gjallarhorn-tunnel.sh` a163825d (guard: personal data is not only secrets — evict identity, widen the ward)
  (cloudflared config in `midgard/infrastructure/ingress/cloudflared-ymir.yml`).
- **Auth:** hardcoded HTTP Basic (`zerwiz:allfather`, `HLIDSKJALF_AUTH`) on the
  gate API, which now also serves the built SPA. Temporary — move to Heimdall +
  `.env.local`.
- **Mobile:** PWA manifest added; recommended APK = Capacitor over the tunnel.

### Files
- *(carried from the frozen CHANGELOG.md)*
