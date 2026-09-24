# odrerir · 2026-09-24 — the boards' MCP is aligned, the connection is VISIBLE, and the smoke proves it

## Why
The Allfather asked: verify the UI and the MCP are aligned, what is missing in
the UI, and how the user knows whether he is connected. Three real findings:

1. **The tool names were wrong — on both the old hall AND the new port.** Skuld
   serves its tools as `tickets_list`, `plans_list`, `comments_list`, … (the
   harness prettifies them to `skuld_*`). Every board — the old Astro pages and
   the first React port — called `tickets/list` with slashes: a name the server
   never had, so the boards rang a dead door in silence.
2. **Skuld answers tools/call as an SSE stream** (`event: message` + a `data:`
   JSON frame) even when JSON would do — the client's `r.json()` threw, so the
   book read empty (or an unparseable answer).
3. **The user could not see the door.** A dead Skuld door looked identical to an
   empty book: no connection state anywhere.

## What
- **Names aligned**: every board call (and the smoke) uses the server's true
  names (`tickets_list` / `tickets_get` / `tickets_update` /
  `tickets_create` / `comments_list` / `comments_post` / `plans_list` /
  `plans_get` / `plans_create`).
- **SSE-proof client**: `src/skuld.ts` parses the last `data:` frame when the
  answer is a stream, plain JSON otherwise.
- **The connection is visible**: `src/skuld.ts` publishes a status
  (idle · connecting · connected · error) on every init/call; each board wears
  the `SkuldStatusChip` (dot + "book connected / ringing / NOT connected —
  <cause>" + a retry that rings again and reloads the board). The empty-sentence
  law: only `|`-shaped lines are rows — a "no plans" sentence is the empty
  state, never a bogus row.
- **The real smoke, in the house test**: `bin/odrerir-mcp-smoke.sh` walks the
  same wire the browser walks (initialize → tickets/list → plans/list →
  tickets/get → comments/list → plans/get) and asserts the ALIGNMENT: every
  tool the boards call must exist on the server (`tools/list`), so a rename can
  never silently orphan the UI again. Wired into
  `.agents/skills/lifecycle/smoke_test.sh` as the `boards` row.

## Verified
- `bin/odrerir-mcp-smoke.sh` live: tickets 13 rows (ymir/13 "The numbered book
  is live"), plans honest-empty, tickets/get 11 fields, comments answered,
  `alignment: ok — every tool the boards call exists on the server`.
- `.agents/skills/lifecycle/smoke_test.sh`: `hall OK` + `boards OK`, exit 0.
- `tsc --noEmit` + `vite build` green.

## Files
- `bin/odrerir-mcp-smoke.sh` (new) · `.agents/skills/lifecycle/smoke_test.sh`
- `apps/odrerir/src/skuld.ts` (SSE + status) · `src/components/SkuldStatus.tsx` (new)
- `apps/odrerir/src/components/{TicketsBoard,PlansBoard}.tsx` · `src/hall.css`
- `.agents/skills/galdr-ymirsystem/assets/odrerir-hall.md` (appended)