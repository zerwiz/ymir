## install · unversioned · 2026-09-16 — the desktop never dials out: Cloudflare stays outside Electron

### Why
The Allfather's rule: **"electron should never have anything with cloudflare to
do."** It was not quite true — three doors stood open:

- **Sessrúmnir's "To the Hall"** preferred the local hall and, when it did not
  answer, fell back to `https://hall.ymir.zerwiz.org`. A desktop seat that
  reaches for a public hostname when its own machine is quiet is a seat that
  leaves the building to do its errands. It is now **local only** — when the hall
  is not running, the seat says so.
- **Hlidskjalf's shell** took `HLIDSKJALF_URL` and `SMIDJA_URL` from the
  environment, and **Óðrerir's** took `HALL_URL` — each able to point a desktop
  window at a tunnel with one exported variable.
- Both now pass their URL through a **loopback guard**: anything that is not
  `127.0.0.1`, `localhost` or `::1` is refused with a warning and replaced by the
  local default. The shell loads the machine, never the internet.

**Why this is the same fight as the bridge:** a desktop app that dials out is a
desktop app whose failures belong to somebody else's edge. The bridge disguised a
cloud endpoint as `127.0.0.1` and cost a night; these three would have disguised a
tunnel as a local seat.

### Files
- *(carried from the frozen CHANGELOG.md)*
