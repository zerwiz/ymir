## hlidskjalf · unversioned · 2026-09-16 — one login for every app on the web; the gate fronts them all

### Why
- **Every app host is gated**, not just Smíðja. The gate now routes by host from
  an `APP_HOSTS` table and fronts each one: unauthenticated visitors get that
  app's own sign-in page, an API path gets 401, and the desktop seat (loopback +
  marker) walks straight in. Verified: `smidjadell…` → *Smíðja — Sign in*,
  `odrerirdell…` → *Óðrerir — Sign in*, API 401, desktop seat 200 (the hall).
- **Every public hostname points at the gate (:3889)** — never at an app's own
  port. That was a hole straight past the login: `gjallarhorn-expose.sh` had been
  exposing each app on its own port, so the app answered the world directly.
- **The gate learns the host map at start** (`state/gjallarhorn-hosts.env`,
  written by the expose script and sourced by `scripts/start.sh`), so routing is
  not an accident of whoever launched it last.
- **No guessed credentials.** The generated tunnel config wrote
  `credentials-file: …/ymir.json`; cloudflared names that file for the tunnel's
  UUID, so it refused to start and the world got 530. The line is gone —
  cloudflared resolves a named tunnel's own credentials.
- Verified through the tunnel: `https://ymirdell.zerwiz.org/` → 200. The app
  hostnames still answer 530: their DNS routes were made against an earlier
  tunnel and need re-creating (`cloudflared tunnel route dns ymir <host>`).

### Files
- *(carried from the frozen CHANGELOG.md)*
