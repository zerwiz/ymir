## gimle · 2026-11-02 — read_scene wired behind a consented share store

### What

- **`bin/gimle/mcp-read.py`** — `read_scene` is no longer an honest `isError`. It now reads from a
  consented shared-scenes store (`<data>/shared-scenes/<subject>/<scene>.json`, or a globally shared
  `<data>/shared-scenes/<scene>.json`), returning elements, owner, shared_at and appState. A scene that has
  not been shared answers `isError` with "scene not shared with the house — consent required". New
  `--scenes` flag (default: next to the data file).
- **`bin/gimle/share-scene.py`** — new: the consented share door. `POST /share` stores a snapshot under
  the owner's subject tree (Authelia `Remote-User` or a Gimlé Bearer token); `DELETE /share/<scene>`
  revokes it. Every call is audited to `access.jsonl`. CORS-enabled so the whiteboard panel can call it.
- **`docs/features/gimle-the-hall.md`** — updated to describe the consented share.

### Why

Plan 157 step 1: Brokk cannot work with a user on their whiteboard unless he can see the board, and the
collab server relays opaque encrypted bytes with the room key in the URL fragment. The share store is the
one place the E2E boundary is crossed, and only by explicit consent.

### Verified (on `zerwizserver`)

- `gimle-mcp.service` and `gimle-share.service` both live; a shared test scene returned its elements via
  `read_scene` with `isError: false`, and an unshared scene returned the consent-required refusal.
  Test artifact removed; store left clean.
EOF