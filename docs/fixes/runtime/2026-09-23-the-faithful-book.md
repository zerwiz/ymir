# runtime · 2026-09-23 — the faithful book (the WayOf anatomy, in the cloth)

## Why
The hall's tickets and plans went through five wrong shapes before the source
spoke: the reference's /tickets is a filterable, sortable TABLE with bulk
power and a +New door; its detail carries a counter-strip, the review march,
the assignee's pick and the comments thread; /plans is its own house.

## What
- `apps/odrerir/src/pages/tickets.astro` — the faithful table: ID/title/
  status-badges/pri/who, filter-drops (status/priority/assignee), bulk-select
  + status-apply, the +New cutter (namespace/status/priority drops, label
  chips — click-only, never typing); the press opens the ticket's detail with
  the stat-strip (Backlog queue · Active · Review · Changes · Done), the
  review-march buttons, the holder's dropdown, and the comments thread.
- `apps/odrerir/src/pages/plans.astro` — its own page: the roadmap rows press
  open the plan; the namespace drop, the book's tickets as a pick-list.
- `apps/odrerir/src/pages/lore.astro` — the saga at home (no cloud door).
- `apps/odrerir/src/index.html` + `livehall.css` — the hall's nav (the lore,
  the book, the plans), the charted disclosure, the detail's cloth.
- `tools/tickets-mcp/server.mjs` — the comments store + comments/list,
  comments/post, plans/get, the create's status, the CORS expose-headers
  (the browser couldn't read the session id — the page died silent), and the
  statuses' vocabulary with the review march (Backlog -> Done, the human gate
  at Submitted for Review, Changes Requested's loop).
- `bin/hall-snapshot.sh` — the scribe reads the smiths true (terminal_title).

## Walls slain along the way
- the server's list rows led with `#` and the parser swallowed it — every
  press died at the hash; the strip now cleans ids at birth
- stacked detail panes; the astro cache "completing" in 47 ms of memory,
  never touching the wire — clean builds (rm -rf dist .astro) on the glass

## Files
- `apps/odrerir/src/pages/{tickets,plans,lore}.astro` · `apps/odrerir/src/index.html`
- `apps/odrerir/src/styles/livehall.css` · `tools/tickets-mcp/server.mjs`
- `bin/hall-snapshot.sh`
