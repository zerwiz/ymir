## gimle · unversioned · 2026-10-22 — the hall, the desk, and one MCP for the suite

### What

- **`bin/gimle/desk.py`** — the page behind the door: due this week · last decisions · questions waiting on
  me · the places. Reads a projected JSON (`meetings.json`), trusts `Remote-User` from Authelia, renders in
  the cloth, never writes.
- **`bin/gimle/mcp-read.py`** — one MCP server (JSON-RPC over `POST /mcp`) exposing eight read tools across
  the suite: `who_am_i`, `list_places`, `my_tasks`, `place_board`, `meeting_record`, `who_owes_what`,
  `find_doc`, `read_scene`. Bearer-token auth (one token per subject), and **every call appended to
  `access.jsonl`** — a call without a token is refused *and recorded*.

### Why

The suite had a door and no desk, and no way for an agent to read the work. Plan 105 sets the shape: one
door, a desk that answers "what is mine", and one MCP rather than three APIs.

### Verified (on `zerwizserver`)

- desk live on `127.0.0.1:8487`; with `Remote-User: craig` it renders the title, all three sections and the tiles.
- MCP live on `127.0.0.1:8489`; `tools/list` returns the eight tools; `initialize` answers protocol
  `2025-06-18`; `who_am_i` returns the subject and the places.
- no token → **401**, and the refusal is written to `access.jsonl` as `anonymous · ? · refused`.

### Not verified

- The desk is **not yet published** behind `/desk` on the hall (Caddy rule pending) — it answers on loopback.
- `find_doc` and `read_scene` are **not wired** to AFFiNE or Excalidraw; they refuse with the reason.
- `my_tasks` reads the **meeting record**, not Plane: no Plane API token exists yet.
- No write tools; that is phase 2 by design.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: a person the house meets · the fleet's always-on heart. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).
