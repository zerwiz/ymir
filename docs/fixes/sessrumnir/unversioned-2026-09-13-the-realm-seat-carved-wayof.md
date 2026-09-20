## sessrumnir · unversioned · 2026-09-13 — The realm seat, carved (wayof)

### Why
- **Problem:** the realm tree was bare (only the shipped example), no tenant
  was seated, and the session digest resolved the Allfather's realm to
  `default` — his company and private holdings unreachable by the map.
- **Seat:** `svartalfaheim/wayof/` carved from the example — `.env.realm`,
  `SECRETS.md`, `AGENTS.md` (persona), `domains/`, `projects/`, the five
  workspace branches, and the 9 company cards seeded from the identity hoard
  (askr · brokkforge · dvalin · mannheim · muninn · runestone · utgard · wayof ·
  ymirlabs), realm field unified to `wayof`, repo paths corrected to this
  machine. `data/realm.md` now pins `wayof` (was drifting between `way-of`,
  `wayof`, and `default`; hoard cards + persona updated to match).
- **Hood:** `svartalfaheim/wayof/HOOD.md` is the map of the hoard and the
  seat; `bin/saga-session-start.sh` stage 6 (context digest) now prints
  `--- hood ---` whole from the realm seat, so a session opens knowing the
  operator's holdings. Living overviews: `workspace/company/wayof-overview.md`
  and `workspace/company/aigf.md` (hodd stays the private store; the realm
  points at it).
- **Verified:** `bash -n` green; realm-lib resolves `wayof`; `realm env:
  present`.

### Files
- *(carried from the frozen CHANGELOG.md)*
