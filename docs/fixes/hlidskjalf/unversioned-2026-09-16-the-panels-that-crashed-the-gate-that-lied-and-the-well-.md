## hlidskjalf · unversioned · 2026-09-16 — the panels that crashed, the gate that lied, and the well that would not open

### Why
- **Statistics now reports the HARNESSES** (pi + opencode), not the smithy's runs.
  `bin/hlidskjalf-usage.sh` aggregates opencode's SQLite token store and both pi
  stores, and emits the numbers under the names the gate renders (`gate{}`):
  totals, usage, providers local/online with per_model, by_chain, by_model.
  Verified: 21,497 runs (opencode 21,422 · pi 75) · 331.5M tokens ·
  local 239,623 / online 331,289,420 · cache-hit 91.5%.
- **A failed fetch no longer takes the hall down.** Endpoints answering `{error}`
  were handed to panels as data — Rail read `.filter` on an object, Stats read
  `.totals` on a string, and both crashed. The store now runs every bootstrap
  answer through `ok()`: an error keeps the last good value.
- **`/api/usage` was answering with a traceback** while the script passed by hand:
  the gate process had been started before the fix and caches a failure for 60s.
  Restarted; the endpoint serves the harness numbers.
- **The engram MCP (`-32000: Connection closed`) is mended.** Not config, not the
  engram package: `python3.12 -c "import mcp"` failed because the system
  `python3-rpds-py` ships without its compiled `rpds.rpds` module, which
  `jsonschema` (inside `mcp` 1.x) imports. Mended with
  `python3.12 -m pip install --user --break-system-packages --force-reinstall rpds-py`
  (plus `mcp<2` under python3.12). The server now starts and waits on s

### Files
- *(carried from the frozen CHANGELOG.md)*
