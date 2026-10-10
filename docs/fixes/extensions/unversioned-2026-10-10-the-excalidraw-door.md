## extensions · unversioned · 2026-10-10 — the excalidraw door: an extension, and a stop that killed the stopper

### Why

**New:** `.pi/extensions/excalidraw/` — a door into the team's whiteboard fork
(`~/CodeP/excalidraw`, overridable with `EXCALIDRAW_ROOT`). Three tools:

- `excalidraw_tickets` — reads the fork's `tickets/` **from the files**, not over HTTP, so an
  agent can read a behaviour contract without anything running. `action=board` lists by column;
  `action=read` returns a ticket whole or as its contract sections.
- `excalidraw_servers` — `status` / `start` / `stop` for the fork's three services: the tickets
  board (`:4174`), the text-to-diagram bridge (`:4173`, which refuses to start without
  `TTD_MODEL_BASE_URL`), and the collaboration room server (`:3002`).
- `excalidraw_app` — raise and lower the desktop app.

Placement follows Rule 13: a directory with an `index.ts`, its own internals inside its own
directory (`paths.ts`, `tickets.ts`, `servers.ts`), one home in `.pi/extensions/`, nothing
started in the factory, `pi` taken as `any`.

**The defect this found.** The first `stop` implementation killed whatever `lsof -ti :PORT`
returned, and that list includes a **client** socket on that port — and `stop()` probes the port
immediately before, so the prober listed *itself*. `stop` therefore killed the process calling
it: the tool reported nothing, the board stayed up, and the run died mid-sequence. The fix is
one selector, `-sTCP:LISTEN`, so only the listener is reaped. The same bare `lsof` stood in the
fork's own `desktop/stop.sh`, which now carries the same selector.

### Verified

- The extension loads and registers all three tools with a stub `pi`; the `session_start`
  handler is wired. Node 26 strips the types, so the check ran against the real files.
- `excalidraw_tickets action=board` read the fork's live tickets by column; `action=read
  sections=true` returned the contract sections of `feature-0001`.
- A traversal attempt (`column: "../../RULES"`) was refused: *"'../../RULES' is not a ticket
  column"*, `isError: true`.
- `excalidraw_servers status` reported `collab` up on `:3002` with
  `{"ok":true,"rooms":1,"members":2}` and the other two down.
- `start` raised the board (`✔ board is up on :4174 — {"ok":true,"root":"…"}`), `stop` lowered
  it (`✔ board stopped (1 pid)`), and the harness process **survived** — the specific thing the
  bare `lsof` broke.
- `start` on the bridge without a model correctly failed: *"did not answer on :4173 within 6s"*.
- `bin/seat/valknut-load.sh --check` → **PASS** (one home, no duplicate load path, root record).

### Not done, deliberately

- The `--check` gate counts top-level `.ts`/`.js` files only, so a **directory** extension is
  not counted by it (the count stayed 16). Pi loads directories with an `index.ts`, so the
  extension works; the gate's blind spot is recorded here rather than papered over.
- No certificate, no TLS, no deploy of the fork's services to `zerwizserver` — that is the
  fork's `feature-0003` and needs the operator's route and word.

### Files

- `.pi/extensions/excalidraw/index.ts` — new: the three tools
- `.pi/extensions/excalidraw/paths.ts` — new: root resolution + the service table
- `.pi/extensions/excalidraw/tickets.ts` — new: reads `tickets/` from disk, incl. path refusal
- `.pi/extensions/excalidraw/servers.ts` — new: status/start/stop, with `-sTCP:LISTEN`
- `.pi/extensions/README.md` — the extension table gains its row
- `~/CodeP/excalidraw/desktop/stop.sh` — the same `-sTCP:LISTEN` fix in the fork
