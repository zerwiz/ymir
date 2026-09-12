#!/usr/bin/env bash
# a2a-mcp.sh — install/verify the two A2A MCP servers into the harnesses so
# every agent can use the mesh AND the control plane at once.
#
#   bin/a2a-mcp.sh install     # add a2abridge (+wayofteams if present) to pi + opencode
#   bin/a2a-mcp.sh show        # what is wired
#   bin/a2a-mcp.sh --version
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PI_MCP="$HOME/.pi/agent/mcp.json"
OC="$ROOT/opencode.json"
A2AB="${A2ABRIDGE_BIN:-$HOME/.a2abridge/bin/a2abridge}"
DIR="${A2A_DIRECTORY:-http://127.0.0.1:7777}"
ADVERT="${A2A_ADVERTISE_HOST:-$(tailscale ip -4 2>/dev/null | head -1)}"
[ -n "$ADVERT" ] || ADVERT="127.0.0.1"

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1:-show}"

WOTES="$(command -v wayofteams-mcp 2>/dev/null || true)"

python3 - "$ROOT" "$PI_MCP" "$OC" "$A2AB" "$DIR" "$ADVERT" "$WOTES" "$ACTION" <<'PY'
import sys, os, json
root, pi_path, oc_path, a2ab, durl, advert, wotes, action = sys.argv[1:9]

def load(p, default):
    try: return json.load(open(p))
    except Exception: return default

ones = {
    "a2abridge": {
        "pi":  {"command": a2ab, "args": ["bridge"],
                "env": {"A2A_DIRECTORY": durl, "A2A_ADVERTISE_HOST": advert}},
        "oc":  {"type": "local", "command": [a2ab, "bridge"],
                "environment": {"A2A_DIRECTORY": durl, "A2A_ADVERTISE_HOST": advert}},
    }
}
if wotes:
    ones["wayofteams"] = {
        "pi":  {"command": wotes, "args": ["--stdio"], "env": {"WOTEAMS_URL": os.environ.get("WOTEAMS_URL","")}},
        "oc":  {"type": "local", "command": [wotes, "--stdio"], "environment": {"WOTEAMS_URL": os.environ.get("WOTEAMS_URL","")}},
    }

if action == "show":
    pi = load(pi_path, {}).get("mcpServers", {})
    oc = load(oc_path, {}).get("mcp", {})
    print("a2a-mcp[2]{server,in_pi,in_opencode}:")
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
