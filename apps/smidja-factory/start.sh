#!/usr/bin/env bash
# start.sh — raise the viewer (API + UI) alone, on loopback, against the one trace the runner resolves.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! command -v bun >/dev/null 2>&1 && [ -x "$HOME/.bun/bin/bun" ]; then PATH="$HOME/.bun/bin:$PATH"; fi
db="$(python3 "$HERE/scripts/smidja" where --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["db"])')"
cd "$HERE/apps/visualizer"
exec env CMD_DB="$db" HOST=127.0.0.1 PORT="${SMIDJA_VIZ_API_PORT:-8437}" bun run server/index.ts
