#!/usr/bin/env bash
# fleet-ensure.sh — the federation's service surfaces (plan 42, the heart's
# services): well-mcp (the served well) · ratatoskr-node (A2A :8301) ·
# the mill worker (grinds) · the embedding stone · the cards root — installed
# from tools/ to the seat, raised as user units, and the seat's harness MCP
# pointed at the served well URL.
#
# Usage:
#   fleet-ensure.sh status            # what is raised
#   fleet-ensure.sh ensure            # install + raise (best-effort, never fails)
#   fleet-ensure.sh --well-url <url>  # the served well URL to write into mcp.json
# Env: BROKK_HOME (default the home), the seat's user units via XDG_RUNTIME_DIR
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
HOME_ROOT="${BROKK_HOME:-$HOME/Documents/ymirhome}"
DST="$HOME/.fleet"
WELL_URL="${FLEET_WELL_URL:-http://127.0.0.1:8317/mcp}"
PORT_BASE="${FLEET_PORT_BASE:-8317}"

say() { printf '%s\n' "$*"; }

units() { printf 'well-mcp\nratatoskr\nmill-worker\nembed\ncards\n'; }

status() {
  local n=0
  for u in $(units); do
    if systemctl --user is-active "$u.service" >/dev/null 2>&1; then n=$((n+1)); say "$u: active"
    else say "$u: inactive"; fi
  done
  say "fleet[1]{raised,units}:"
  say "  \"$n\",\"5\""
}

ensure() {
  mkdir -p "$DST" "$HOME/.config/systemd/user"
  # 1) the tools from the repo
  cp -r "$ROOT/tools/well-mcp/server.ts" "$DST/well-mcp-server.ts" 2>/dev/null || true
  cp -r "$ROOT/tools/ratatoskr-node/server.ts" "$DST/ratatoskr-server.ts" 2>/dev/null || true
  cp -r "$ROOT/tools/mill/worker.sh" "$DST/mill-worker.sh" 2>/dev/null || true
  # 2) the units, templated to this seat
  for u in $(units); do
    src="$ROOT/tools/mill/systemd/$u.service"
    [ -f "$src" ] || continue
    tgt="$HOME/.config/systemd/user/$u.service"
    # substitute the seat's absolute paths
    sed -e "s|/home/whynot|$HOME|g" "$src" > "$tgt"
  done
  # the served well URL into the seat's pi mcp.json (best-effort)
  mkdir -p "$HOME/.pi/agent"
  if [ -f "$HOME/.pi/agent/mcp.json" ]; then
    python3 - "$WELL_URL" <<'PY'
import json, sys
p=__import__("os").path.expanduser("~/.pi/agent/mcp.json")
try: d=json.load(open(p))
except Exception: d={}
d.setdefault("mcpServers",{})["well"]={"url":sys.argv[1]}
json.dump(d, open(p,"w"), indent=2)
PY
  else
    printf '{"mcpServers":{"well":{"url":"%s"}}}\n' "$WELL_URL" > "$HOME/.pi/agent/mcp.json"
  fi
  # 3) raise (best-effort, never fails the install)
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  for u in well-mcp ratatoskr mill-worker embed cards; do
    systemctl --user enable --now "$u.service" >/dev/null 2>&1 || say "$u: could not raise (warn)"
  done
  status
}

case "${1-}" in
  -h|--help|"") sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//' ;;
  status) status ;;
  ensure) ensure ;;
  --well-url) WELL_URL="${2-}"; ensure ;;
  *) say "error: unknown command (status|ensure)" >&2; exit 2 ;;
esac