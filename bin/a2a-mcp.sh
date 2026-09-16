#!/usr/bin/env bash
# a2a-mcp.sh — install/verify the Ymir MCP servers into the harnesses so every
# agent can use the mesh, the memory well, and the control plane at once.
#
#   bin/a2a-mcp.sh install            # add a2abridge + engram (+wayofteams if present) to pi + opencode
#   bin/a2a-mcp.sh install --project  # scoped: write the REPO's .pi/mcp.json + opencode.json, never ~/.pi
#   bin/a2a-mcp.sh show [--project]   # what is wired, in the chosen scope
#   bin/a2a-mcp.sh --version
#
# Scope: default writes Pi's GLOBAL MCP list (~/.pi/agent/mcp.json). `--project`
# keeps everything inside the repo (`.pi/mcp.json` + `opencode.json`) so a Pi used
# in other areas is left untouched — launch it with `pi --mcp-config .pi/mcp.json`
# to pick the repo up.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OC="$ROOT/opencode.json"
A2AB="${A2ABRIDGE_BIN:-$HOME/.a2abridge/bin/a2abridge}"
DIR="${A2A_DIRECTORY:-http://127.0.0.1:7777}"
ADVERT="${A2A_ADVERTISE_HOST:-$(tailscale ip -4 2>/dev/null | head -1)}"
[ -n "$ADVERT" ] || ADVERT="127.0.0.1"

PROJECT=0; ACTION="show"
while [ $# -gt 0 ]; do
  case "$1" in
    --project) PROJECT=1 ;;
    -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) ACTION="$1" ;;
  esac
  shift
done
if [ "$PROJECT" = 1 ]; then PI_MCP="$ROOT/.pi/mcp.json"; else PI_MCP="$HOME/.pi/agent/mcp.json"; fi

WOTES="$(command -v wayofteams-mcp 2>/dev/null || true)"
ENGRAM_BIN="${ENGRAM_BIN:-$HOME/.local/bin/engram-mcp}"
ENGRAM_DB="${ENGRAM_DB:-$ROOT/.agents/memory/kaia.engram}"

python3 - "$ROOT" "$PI_MCP" "$OC" "$A2AB" "$DIR" "$ADVERT" "$WOTES" "$ACTION" "$ENGRAM_BIN" "$ENGRAM_DB" <<'PY'
import sys, os, json
root, pi_path, oc_path, a2ab, durl, advert, wotes, action, engram_bin, engram_db = sys.argv[1:11]

def load(p, default):
    try: return json.load(open(p))
    except Exception: return default

ones = {
    "a2abridge": {
        "pi":  {"command": a2ab, "args": ["bridge"],
                "env": {"A2A_DIRECTORY": durl, "A2A_ADVERTISE_HOST": advert}},
        "oc":  {"type": "local", "command": [a2ab, "bridge"],
                "environment": {"A2A_DIRECTORY": durl, "A2A_ADVERTISE_HOST": advert}},
    },
    "engram": {
        "pi":  {"command": engram_bin, "args": ["--db", engram_db]},
        "oc":  {"type": "local", "command": [engram_bin, "--db", engram_db], "environment": {}},
    },
}
if wotes:
    ones["wayofteams"] = {
        "pi":  {"command": wotes, "args": ["--stdio"], "env": {"WOTEAMS_URL": os.environ.get("WOTEAMS_URL","")}},
        "oc":  {"type": "local", "command": [wotes, "--stdio"], "environment": {"WOTEAMS_URL": os.environ.get("WOTEAMS_URL","")}},
    }

if action == "show":
    pi = load(pi_path, {}).get("mcpServers", {})
    oc = load(oc_path, {}).get("mcp", {})
    print(f"a2a-mcp[{len(ones)}]{{server,in_pi,in_opencode}}:")
    for name in ones:
        print(f'  "{name}","{"yes" if name in pi else "no"}","{"yes" if name in oc else "no"}"')
    if not wotes:
        print('help: wayofteams-mcp not on PATH — install it to enable the Teams plane')
    sys.exit(0)

if action != "install":
    print("error: use install|show"); sys.exit(2)

# pi mcp.json
pid = load(pi_path, {"mcpServers": {}})
pid.setdefault("mcpServers", {})
for name, spec in ones.items():
    pid["mcpServers"][name] = spec["pi"]
os.makedirs(os.path.dirname(pi_path), exist_ok=True)
json.dump(pid, open(pi_path, "w"), indent=2)

# opencode.json mcp block
ocd = load(oc_path, {"mcp": {}})
ocd.setdefault("mcp", {})
for name, spec in ones.items():
    entry = spec["oc"]; entry["enabled"] = True
    ocd["mcp"][name] = entry
json.dump(ocd, open(oc_path, "w"), indent=2); open(oc_path, "a").write("\n")

print(f'a2a-mcp[1]{{action,servers}}:\n  "install","{",".join(ones)}"')
PY
