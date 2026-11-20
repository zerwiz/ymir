#!/usr/bin/env bash
# 0002-a2a-mcp — install the A2A MCP servers (a2abridge + wayofteams) into the
# harnesses for homes that predate the wiring. Idempotent. Also drops the
# a2a-sdk server into the runtime so any home can serve an Eindri over A2A.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# 0. Ensure the engine binary + directory daemon exist BEFORE wiring MCP, so
#    no harness ever points at a dangling path.
if [ -x "$ROOT/bin/a2abridge-ensure.sh" ]; then
  "$ROOT/bin/a2abridge-ensure.sh" ensure --install >/dev/null 2>&1 \
    && echo "  a2abridge: engine present + directory up" \
    || echo "  a2abridge: SKIP (offline? re-run bin/a2abridge-ensure.sh ensure --install)"
fi

# 1. Wire the MCP servers into pi + opencode (a2abridge; wayofteams if present).
if [ -x "$ROOT/bin/a2a-mcp.sh" ]; then
  "$ROOT/bin/a2a-mcp.sh" install >/dev/null 2>&1 && echo "  a2a-mcp: wired"
fi

# 2. Ensure the a2a-sdk server can run (best effort; skip cleanly if offline).
python3 -c "import a2a, uvicorn, starlette" >/dev/null 2>&1 \
  || python3 -m pip install --user --break-system-packages 'a2a-sdk[fastapi]' uvicorn >/dev/null 2>&1 \
  || echo "  a2a-sdk: SKIP (install later: pip install 'a2a-sdk[fastapi]' uvicorn)"

echo "0002-a2a-mcp: done"
