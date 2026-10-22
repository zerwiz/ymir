## gimle · unversioned · 2026-10-22 — the desk is behind the door, and it fails closed

### What

- **`/desk` is served through the gate.** Caddy's portal vhost carries a `handle /desk*` with
  `forward_auth` against Authelia: an unauthenticated request is redirected to the door with a `rd=` back to
  the desk, and an authenticated one is proxied to `bin/gimle/desk.py` with `Remote-User` set.
- **The login lands on the desk.** The hall page's default target after `firstfactor` is now `/desk`, so a
  person signs in once and arrives at their work instead of the login again.
- **The desk fails closed (plan 105, H3).** It reads `places.json` beside the record
  (`{"person": ["place", …]}`). The operator — named by `GIMLE_OPERATOR`, set in a systemd drop-in — sees
  every place; a person named in the map sees only theirs; **a person not named sees nothing at all**, and a
  missing map means nobody but the operator sees anything.

### Verified

- unauthenticated `https://gimle.zerwiz.org/desk` → **302** to
  `https://auth.zerwiz.org/?rd=https%3A%2F%2Fgimle.zerwiz.org%2Fdesk`
- with a real session (login as `zerwiz` through `/api/firstfactor`), `/desk` renders its sections — **2 of 2**
  matched in the body.
- `places_for('zerwiz', …)` → `None` (every place); `places_for('craig', …)` with no map → `[]` (nothing).
- `caddy validate` → **Valid configuration**.

### Not verified / not done

- **`places.json` is not written yet** — until it is, only the operator sees anything, which is the safe
  default but not the finished flow.
- **The dashboard (D1–D4 in plan 105) is not built**: the hall is still a login page that forwards to the
  desk, not a dashboard with tiles.
- An earlier Caddyfile written with a one-line `transport http { … }` block was invalid and took the door
  down for ~2 minutes; the portal was restored from a validated multi-line config. The lesson is in the fix:
  **validate before restart.**
