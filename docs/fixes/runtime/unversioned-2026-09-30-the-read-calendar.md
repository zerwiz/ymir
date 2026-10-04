## runtime · unversioned · 2026-09-30 — the read calendar (Mánagandr, the one reader and the shell door)

### Why
- **There was no way for the house to know what the Allfather's day holds.** The
  Nornir jobs fire blind, the briefing cannot weight a day with meetings in it, and
  no agent can ask "when is he free?" before proposing a time. Plan 60 names the
  gap plainly: no Google Calendar OAuth grant exists anywhere in the vault, and
  `GOOGLE_API_KEY` alone identifies an application, not the man.
- **Mánagandr is the first half of that plan** — the reckoning itself, before the
  mesh door (`tools/calendar/server.mjs`), the gate API route and the Hlidskjalf
  grid, which are separate errands. One reader, so no second place ever talks to
  Google.

### Fix
- **`tools/calendar/reader.mjs` — the ONE reader.** Refreshes the OAuth grant from
  the vault key, fetches a bounded window (default `±6 weeks` — the month grid's
  neighbour weeks), normalises the events, writes ONE rolling cache at
  `<home>/hodd/state/calendar/cache.json` and returns the normalised set. Env-driven
  (PORT, `MANAGANDR_VAULT`, `MANAGANDR_OAUTH_KEY` and friends), zod-shaped, and the
  home resolves through the resolver's discipline, never a literal path. `--fixture`
  runs the whole path offline against a synthetic `events.list` response.
- **`bin/calendar-ask.sh` — the shell door.** `probe`, `busy`, `free`, `json`; exits
  **0 free**, **10 busy**, **20 unknown**, **2 usage**, so a cron job branches with
  no parsing and no jq. Dry-run flags (`--fixture`, `--now`, `--cache`) keep it
  provable offline.
- **Read-only is the capability being absent.** No create, update, delete, move or
  invite verb exists in either file — not a flag. The only write is the local cache.
- **UNKNOWN IS NOT EMPTY.** Every result carries an `as_of` and a `checked_at`; an
  absent grant returns `status:"unknown"` with `reason:"no_oauth_grant"` and the
  exact missing key named, never a silent empty day. A stale-but-readable cache is
  served with its `as_of`; only the genuinely unreadable is unknown.

### Proof
- `.agents/tests/managandr-reader.test.sh` — 16 assertions, all passing, entirely
  offline: `node --check`/`bash -n` clean; the window is `±6 weeks`; the normaliser
  maps an all-day event (midnight in the machine's zone), a multi-day span (56h), a
  timezone-offset event (its offset and instant preserved) and a cancelled event
  (not busy); the absent grant is a named `no_oauth_grant` error; the door returns
  10 / 0 / 20 for busy / free / unknown; `probe` prints no title while
  `probe --titles` honours an explicit request; and no write verb or jq exists.
- Fixture `.agents/tests/assets/managandr-google-events.json` carries synthetic
  times and invented titles only — no attendee, no location, no real data.
- `bash bin/gates/guards.sh` and
  `bash .agents/skills/galdr-ymirsystem/scripts/compliance-check.sh` both pass on
  the worktree.

### Wiring
- New code only; `apps/hlidskjalf/**`, `tools/calendar/server.mjs` and
  `config/cron.yaml` are untouched (parallel errands). The reader's `PORT` is
  reserved for the mesh door and is not bound here.
- Phase 0 (the Allfather's browser consent, which mints the refresh token into the
  vault) is still ahead; the reader is complete and provable without it, and says
  exactly which key it is missing.
