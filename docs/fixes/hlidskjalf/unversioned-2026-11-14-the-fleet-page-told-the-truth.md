## hlidskjalf · unversioned · 2026-11-14 — the fleet page told the truth (graph, stream, tasks, cards, doors)

Plan 275 items 16, 17, 18 and 19, at the Allfather's word: *"the agents are stacking, i dont
see their names"* · *"the a2a task stream also should show the herdr communication between
agents"* · *"i dont see the herdr tasks here either"* · *"are all agent cards true … cant we
show more information about them"* · *"we need to have devtools attached to all agents
harnesses"*.

### Why

Measured on heimdall at 03:20 (plan 275): the graph placed nodes by **percentage inside a fixed
340 px box**, so thirty-six agents in five rows got a ~31 px row pitch under 46 px rings and every
row was drawn on top of the one above it; `/api/stream` tailed **only** the Runes ledger, so
nothing ever recorded an `eindri-send` and the panel said "no live events"; `/api/tasks` was built
**only** from Forge orders, so nine errands in herdr panes left every column empty; `card()` in
`server/hlidskjalf-agents.sh` mapped `working|idle → nominal` and gave every roster card
`domain="ymirlabs"`, `signed: False` and an empty model, so all 24 role cards read NOMINAL while
nine agents lived; and a DevTools port existed only when a human exported `YMIR_DEVTOOLS_PORT`
before launching, so in practice there was no door at all.

### What changed

1. **The graph (item 16).** `src/gates/Fleet.tsx` lays out in **pixels**: a node owns a cell
   strictly larger than itself (`NODE_W 118 × NODE_H 88`, 16/14 px gaps), the canvas grows and
   scrolls, and a `ResizeObserver` decides how many columns the measured panel holds. Living
   seats come first, the roster after. Edges are drawn only to **living** seats — an edge to an
   unseated figure was decoration pretending to be a hop. Proved in a real window: **42 nodes, 0
   overlapping rects, 0 invisible, all 42 names on screen** (was: five stacked columns).

2. **The stream (item 17a).** `bin/agents/msg-log.sh` (new) appends one JSON row per send —
   `ts, epoch, from, to, pane, machine, text (first line, bounded 240)` — to
   `$YMIR_STATE_DIR/fleet/messages.jsonl`, 0600, `O_APPEND`. `bin/agents/eindri-send.sh` records
   the word after a successful send, taking `from` **from the stamp it just wrote** so the log and
   the pane can never disagree. `/api/stream` now tails **two** ledgers (Runes and the message log)
   and `/api/a2a/messages` serves the history; the Fleet page shows who → whom · first line.
   Proved live: a recorded message reached the SSE footer within one 2 s tick.
   Also fixed there: the tail sliced a **JS string by a byte offset**, which lost every line after
   the first multibyte rune (`Hœnir`, `Smíðja`) — it now slices bytes.

3. **The Tasks board (item 17b).** `tasks()` reads the **errand records** — `<id>.meta`
   (`window`, `herdr_pane_id`, `harness`, `model`, `kind`, `mode`, `launched`) and `<id>.status`
   (the agent's own last claim) — maps the claim's first word to a lifecycle state, and keeps the
   Forge orders after them. Proved: **60 errands on the board, states from the records**
   (`COMPLETED 44 · FAILED 13 · WORKING 3`), where every column was empty before.

4. **The cards (item 18).** `server/hlidskjalf-agents.sh` v2.0.0: **NOMINAL means ALIVE** — a pane
   really holds the agent, and an unseated figure is `down`; the model is the one its launch
   recorded, else the one the operator configured (`config/agents.yaml`), else empty, and it says
   **where** that came from; harness, pane, machine, seat, errand and the errand's last claim are
   emitted; `paneLabel` is `<agent> · <errand>`, never the terminal title; the last message sent
   **to** the agent is attached from the fleet log. `AgentCard.tsx` no longer prints the invented
   organisation name, the empty model or `UNSIGNED`; an unseated figure has **no** harness
   (nothing runs it). Proved: 42 rows, 18 alive / 24 down, each down card reading `DOWN · not
   seated · heimdall · no errand`.

5. **The doors (item 19).** `bin/desktop/app-lib.sh` grew the one table —
   `app_devtools_port` — and `bin/desktop/hlidskjalf-doors.sh` (new) lists every app's CDP door and
   every agent's pane door, probing each port rather than assuming it. `/api/doors` serves it and
   the Fleet page shows `N/6 app doors · N agent doors`. `scripts/electron.sh` now defaults to the
   table instead of requiring the variable.

### Files

`apps/hlidskjalf/src/gates/Fleet.tsx` · `src/components/AgentCard.tsx` · `src/gates/Tasks.tsx`
(consumer) · `src/state/store.ts` · `src/services/api.ts` · `src/types.ts` · `src/app/App.tsx` ·
`src/app/BottomStream.tsx` · `src/styles/components.css` · `server/index.ts` ·
`bin/desktop/hlidskjalf-agents.sh` · `bin/desktop/hlidskjalf-doors.sh` (new) ·
`bin/desktop/app-lib.sh` · `bin/agents/msg-log.sh` (new) · `bin/agents/eindri-send.sh` ·
`scripts/electron.sh` · `docs/features/inspect-any-app-and-agent.md` (new).

### Proof

Real window on heimdall through Chrome DevTools (CDP `:9420`, Playwright over the same browser),
gate on `:3901` from this worktree, SPA built from it: 42 graph nodes with **zero overlapping
rects**, the doors panel listing 6 app ports and 18 agent doors, the stream showing 11 recorded
messages, cards reading `DOWN` for the unseated, `tsc --noEmit` clean, no console errors.
**Not proved:** a second machine. The second machine's ssh road timed out at 04:10, and the
release-flip pass needs the merge this branch does not perform.

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #757
