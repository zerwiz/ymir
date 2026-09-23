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
SKILLS_URL="${FLEET_SKILLS_URL:-http://127.0.0.1:8319/mcp}"
SKULD_URL="${FLEET_SKULD_URL:-http://127.0.0.1:8320/mcp}"
PORT_BASE="${FLEET_PORT_BASE:-8317}"

say() { printf '%s\n' "$*"; }

units() { printf 'well-mcp\nratatoskr\nmill-worker\nembed\ncards\nskills-mcp\nskuld\n'; }

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
  # 1) the tools from the repo into the seat's fleet dir
  cp -r "$ROOT/tools/well-mcp/server.ts" "$DST/well-mcp-server.ts" 2>/dev/null || true
  cp -r "$ROOT/tools/ratatoskr-node/server.ts" "$DST/ratatoskr-server.ts" 2>/dev/null || true
  cp -r "$ROOT/tools/mill/worker.sh" "$DST/mill-worker.sh" 2>/dev/null || true
  cp -r "$ROOT/tools/skills-mcp/server.mjs" "$DST/skills-mcp-server.mjs" 2>/dev/null || true
  cp -r "$ROOT/tools/tickets-mcp/server.mjs" "$DST/tickets-mcp-server.mjs" 2>/dev/null || true
  # the skills mirror — the master .agents/skills tree, refreshed each ensure
  if [ -d "$ROOT/.agents/skills" ]; then
    rm -rf "$DST/skills" && cp -r "$ROOT/.agents/skills" "$DST/skills" 2>/dev/null || true
  fi
  # 2) the units (the templates are %h-native — every seat materializes the
  #    same shapes; no /home/whynot assumptions, no sed substitution)
  for u in $(units); do
    src="$ROOT/tools/mill/systemd/$u.service"
    [ -f "$src" ] || continue
    cp "$src" "$HOME/.config/systemd/user/$u.service"
  done
  # 3) the well venv (mcp-proxy wrapping engram-mcp) — materialized HERE, so a
  #    seat never inherits the heart's hand-built venv path
  VENV="$DST/well-venv"
  if [ ! -x "$VENV/bin/mcp-proxy" ]; then
    if command -v python3 >/dev/null 2>&1; then
      python3 -m venv "$VENV" 2>/dev/null && "$VENV/bin/pip" -q install mcp-proxy "mcp<2" engram-mcp >/dev/null 2>&1
    fi
  fi
  # 4) the cards root — the seat's own agent card under /.well-known
  CROOT="$DST/cards-root"
  mkdir -p "$CROOT/.well-known"
  if [ ! -f "$CROOT/.well-known/agent-card.json" ]; then
    cat > "$CROOT/.well-known/agent-card.json" <<CARD
{
  "name": "$(hostname -s 2>/dev/null || echo seat)",
  "description": "Ymir body seat — A2A node (:8301) · cards (:8318)",
  "url": "http://$(hostname -I 2>/dev/null | awk '{print $1}'):8301",
  "version": "1.0"
}
CARD
  fi
  [ -f "$CROOT/index.html" ] || printf '<h1>Fleet cards — %s</h1>\n' "$(hostname -s)" > "$CROOT/index.html"
  # 5) the served well + skills URLs into the seat's pi mcp.json (best-effort)
  mkdir -p "$HOME/.pi/agent"
  if [ -f "$HOME/.pi/agent/mcp.json" ]; then
    python3 - "$WELL_URL" "$SKILLS_URL" "$SKULD_URL" <<'PY'
import json, sys, os
p=os.path.expanduser("~/.pi/agent/mcp.json")
try: d=json.load(open(p))
except Exception: d={}
d.setdefault("mcpServers",{})["well"]={"url":sys.argv[1]}
d["mcpServers"]["bolthorn"]={"url":sys.argv[2]}
d.setdefault("mcpServers",{})["skuld"]={"url":sys.argv[3]}
json.dump(d, open(p,"w"), indent=2)
PY
  else
    printf '{"mcpServers":{"well":{"url":"%s"},"bolthorn":{"url":"%s"}}}\n' "$WELL_URL" "$SKILLS_URL" > "$HOME/.pi/agent/mcp.json"
  fi
  # 6) raise (best-effort, never fails the install) — embed is heart-gated:
  #    only seats that have the model file host the stone
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  for u in well-mcp ratatoskr mill-worker cards skuld; do
    systemctl --user enable --now "$u.service" >/dev/null 2>&1 || say "$u: could not raise (warn)"
  done
  if [ -x "$VENV/bin/mcp-proxy" ] && [ -f "$DST/skills-mcp-server.mjs" ] && [ -d "$DST/skills" ]; then
    systemctl --user enable --now skills-mcp.service >/dev/null 2>&1 || say "skills-mcp: could not raise (warn)"
  else
    say "skills-mcp: skipped (needs mcp-proxy + a skills mirror)"
  fi
  if [ -f "$HOME/Models/embed/nomic-embed-text-v1.5.Q4_K_M.gguf" ]; then
    systemctl --user enable --now embed.service >/dev/null 2>&1 || say "embed: could not raise (warn)"
  else
    say "embed: skipped (the model file is not on this seat)"
  fi
  status
}

case "${1-}" in
  -h|--help|"") sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//' ;;
  status) status ;;
  ensure) ensure ;;
  --well-url) WELL_URL="${2-}"; ensure ;;
  *) say "error: unknown command (status|ensure)" >&2; exit 2 ;;
esac