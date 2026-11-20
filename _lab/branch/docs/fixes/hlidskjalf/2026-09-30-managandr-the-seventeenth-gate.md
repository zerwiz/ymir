# hlidskjalf · 2026-09-30 — Mánagandr, the seventeenth gate: the read calendar

## Why
Plan 60 sealed a **read** calendar for Hlidskjalf ("A grid — a real calendar
view"), and its amendment fixed the shape: a month grid with week columns and
hour rows, a now line, lane toggles, and the Nornir collision hairline. The gate
is the third door onto the one reader (`tools/calendar/reader.mjs`, its own
errand); it must compose the lanes the house already serves rather than build a
second data path. Two faults were folded into the same change:

1. `assets/hlidskjalf-ui.md` still claimed the app lived in its **own repo**
   (`zerwiz/hlidskjalf`) that the monorepo never tracks. That is false — the app
   has hundreds of tracked files here and the registry points it at
   `repo: apps/hlidskjalf`, posture `direct-PR`.
2. There was no read route onto the reader's cache, and no gate to draw it.

## What
- **`apps/hlidskjalf/server/index.ts`** — one new read-only route,
  `GET /api/calendar`, under the same `/api/*` auth (401 without a session). It
  reads `$YMIR_HOME/hodd/state/calendar/cache.json` (`MANAGANDR_CACHE` overrides
  the path, `MANAGANDR_CALENDAR_TTL_SECONDS` the freshness window) and answers
  exactly `{ as_of, state: "ok"|"unknown"|"absent", events: Event[] }`, with
  `Event = { id, title, start, end|null, allDay, cancelled, calendarId }` plus
  `attendees` when the cache carries it. The normaliser accepts `as_of`/`asOf`/
  `generated_at`, `events`/`items`, `allDay`/`all_day`, `cancelled`/`status:
  cancelled`, a bare-date all-day, and a timezone-offset start. `state` is the
  honest word: `absent` (no cache — Phase 0 not granted), `unknown` (cache exists,
  freshness unprovable: no readable `as_of` or older than the TTL), `ok` (fresh).
  `/api/mimir/health` gained `superseded_dates` — the DAYS a fact was superseded,
  read straight from the engrim store, timestamps only, never a fact's text.
- **`apps/hlidskjalf/src/gates/Managandr.tsx`** + its `GATES` row (id
  `managandr`, label `Mánagandr`, glyph `ᛅ` — checked free among the other
  sixteen) + `GATE_META`. A month grid of week day-columns and 24 hour rows, an
  hour gutter in **the machine's timezone** (`Date` local methods — no hardcoded
  offset or zone), a now line on today's column, `‹ ›` and `⟨ Today ⟩`, and four
  lane toggles. Lanes compose from what is already served: reckoning from
  `/api/calendar`; Nornir from `/api/cron` + `/api/cron/seats` (the collision
  hairline — hollow planned, filled ran, blood missed; run-state is provable only
  for a job this seat runs, so every other firing stays planned, not falsely
  missed); Smíðja from `/api/smidja/sessions` + each session's phases (a rail per
  run, a block per phase, a blood edge on a refused gate); well from `/api/well`
  (density — one tick per episode, brightness by `score`) with supersede rules
  from the new `mimir.superseded_dates`. Selecting an event opens a READ modal
  (title · span · attendee count when carried · source id · Open in Google
  Calendar). No write verb exists anywhere in the gate.
- **`src/types.ts` · `src/data/realms.ts` · `src/data/metadata.ts` ·
  `src/app/Shell.tsx` · `src/services/api.ts` · `src/state/store.ts` ·
  `src/main.tsx` · `src/styles/managandr.css`** — the `managandr` gate id, the
  registry row and page metadata, the route, the typed `CalendarInfo` client and
  a `refreshCalendar` track (the reckoning loads on its own beat, so a slow
  reviews/usage leg cannot blank the grid — the same isolation Smíðja has), and
  the gate's stylesheet (tokens only, no raw hex).
- **`.agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md`** — the stale
  repo sentence corrected, the gate and its route recorded, and the Mánagandr
  section written (the governed-asset law). The `tyr-check` mirror is a
  working-tree hardlink of the same file, so it moved with it.

## Verified
- `npm run typecheck` — clean (tsc --noEmit, no output).
- `npm run build` — green (`vite v6.4.3`, 343 modules, `✓ built`).
- `/api/calendar` against the real cache: `{"as_of":"2026-09-30T17:30:37.299Z",
  "state":"ok","events":[ … 5 events … ]}`; with `MANAGANDR_CACHE` unset in a
  fresh tree it answers `{"as_of":null,"state":"absent","events":[]}`. A
  throwaway fixture (never the hoard cache) proved the `ok` shape — all-day
  `end:null`, `cancelled:true`, an attendees count, an offset start — and the
  `unknown` shape for a missing `as_of` and for unparseable JSON.
- Auth: with `HLIDSKJALF_AUTH` set, `GET /api/calendar` without a session →
  `401 {"error":"unauthorized"}`; after `POST /api/login` → `200`.
- **Headless Chromium, `#/managandr` (desktop seat), 0 console errors.** The real
  cache (October events) with the month advanced: 35 day columns, 120 gutter
  hours, **6 event blocks**, 1 all-day chip, **22 Nornir collision hairlines**,
  21 well ticks, 4 lanes, and the read modal opened on select:
  `Invented All-Day Gathering · read-only — this reckoning has no edit · When ·
  Sat, Oct 10 · all-day · Attendees · 0 · Source · primary · ev-all-day ·
  Open in Google Calendar`. September (the default month, no events in it) draws
  the honest note — *"The cache is fresh; no events fall in September 2026 — it
  carries 5 across the wider window."* — never a blank grid.
- `bash bin/gates/guards.sh` and `bash .agents/skills/galdr-ymirsystem/scripts/compliance-check.sh`
  pass on the worktree.

## Files
- `apps/hlidskjalf/server/index.ts` · `apps/hlidskjalf/src/gates/Managandr.tsx`
- `apps/hlidskjalf/src/styles/managandr.css` · `apps/hlidskjalf/src/types.ts`
- `apps/hlidskjalf/src/data/realms.ts` · `apps/hlidskjalf/src/data/metadata.ts`
- `apps/hlidskjalf/src/app/Shell.tsx` · `apps/hlidskjalf/src/main.tsx`
- `apps/hlidskjalf/src/services/api.ts` · `apps/hlidskjalf/src/state/store.ts`
- `.agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md`

## Note (for the report, not this note)
The parallel reader wrote the real cache mid-errand, so the headless proof above
runs against real reader output; the cache was never written by this errand.
