## extensions · unversioned · 2026-10-10 — the excalidraw door gains a diagram writer, and honours each service's own .env

### Why

**New tool `excalidraw_diagram`.** The fork can do far more than plumbing, and the biggest
untapped piece needed no model at all: **a scene is just JSON**. This tool writes a real,
editable `.excalidraw` file from a plain spec —
`{title?, nodes:[{id,label?,shape?}], edges:[{from,to}]}` — with no model, no browser and no
DOM. `action=create` writes; `action=describe` reads a scene back and reports what is in it.
Output is deterministic, so a diff means the spec changed.

It shells out to `server/diagram/write.mjs`, which is the fork's documented door rather than a
second implementation.

**Each service's own `.env` is now honoured.** `excalidraw_servers start` prefers a service's
`start.sh` when it exists, because that script sources the service's `.env`. That is how one
install raises the bridge against *its own* model and ports while another raises a different
one, with nothing passed in and nothing hardcoded. The text-to-diagram bridge gained
`server/ttd-bridge/.env.example` (tracked) and `.env` (gitignored).

### Verified

- The extension loads and registers **four** tools (`excalidraw_tickets`,
  `excalidraw_servers`, `excalidraw_diagram`, `excalidraw_app`) with a stub `pi`.
- `excalidraw_diagram create` wrote a 9-element scene (`text 4, rectangle 1, diamond 1,
  ellipse 1, arrow 2`) whose labels read back correctly; `describe` reported the same; a spec
  with no `nodes` was **refused** with `isError: true` rather than writing an empty file.
- **The app itself accepts the scene**: mounting it through the fork's own test harness showed
  `window.h` holding all 12 elements with the right types (proved in the fork's suite).
- `excalidraw_servers status` reported the bridge up with
  `{"ok":true,"model":"qwen3.6-35b-a3b-3050@iq2_xxs","upstream":"http://127.0.0.1:8080/v1"}`;
  `stop` then `start` re-raised it **through `start.sh`**, and it came back with the *same
  install's* model — the point of the change.
- `bin/seat/valknut-load.sh --check` → **PASS**.

### Files

- `.pi/extensions/excalidraw/index.ts` — the `excalidraw_diagram` tool, the `run` helper
- `.pi/extensions/excalidraw/paths.ts` — `startScript` on the service table, `modelDefaults()`
- `.pi/extensions/excalidraw/servers.ts` — prefer the service's `start.sh` when it exists
