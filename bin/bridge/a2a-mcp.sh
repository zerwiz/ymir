#!/usr/bin/env bash
# a2a-mcp.sh — install/verify the Ymir MCP servers into the harnesses so every
# agent can use the mesh, the memory well, and the control plane at once.
#
#   bin/bridge/a2a-mcp.sh install            # add a2abridge + the well door (+wayofteams if present) to pi + opencode
#   bin/bridge/a2a-mcp.sh install --project  # scoped: write the REPO's .pi/mcp-adapter.json + opencode.json, never ~/.pi
#   bin/bridge/a2a-mcp.sh show [--project]   # what is wired, in the chosen scope
#   bin/bridge/a2a-mcp.sh --version
#
# Scope: default writes Pi's GLOBAL MCP list (~/.pi/agent/mcp-adapter.json). `--project`
# keeps everything inside the repo (`.pi/mcp-adapter.json` + `opencode.json`) so a Pi used
# in other areas is left untouched — launch it with `pi --mcp-config .pi/mcp-adapter.json`
# to pick the repo up.
#
# The well (2026-11-10, the Allfather's law): engram is Kaia's engine only. The memory
# server wired here is the WELL DOOR — this body's gateway (`/mcp/well` on :8316), which
# journals every write and carries it to the heart — never a direct `engram-mcp --db`
# stdio server. An `engram` entry an older install wrote is removed on the next install
# (the file is backed up first). The other harnesses get the same set from
# bin/bridge/mcp-config.sh seat.
set -u
# The ONE resolver (Rule 07): env -> the recorded choice -> the one default.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yh="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  for _i in 1 2 3 4 5; do
    [ -n "$_yh" ] || break
    if [ -r "$_yh/bin/vault/hoard-lib.sh" ]; then . "$_yh/bin/vault/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1; break; fi
    if [ -r "$_yh/hoard-lib.sh" ]; then . "$_yh/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1; break; fi
    _yh="$(cd "$_yh/.." 2>/dev/null && pwd)"
  done
  unset _yh _i
fi
if [ -z "${YMIR_HOME:-}" ] && command -v ymir_home_root >/dev/null 2>&1; then
  ymir_home_root YMIR_HOME
fi

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"
OC="$ROOT/opencode.json"
A2AB="${A2ABRIDGE_BIN:-$HOME/.a2abridge/bin/a2abridge}"
DIR="${A2A_DIRECTORY:-http://127.0.0.1:7777}"
ADVERT="${A2A_ADVERTISE_HOST:-$(tailscale ip -4 2>/dev/null | head -1)}"
# A2A is a PEER service: the bridge must bind where PEERS can reach it, on a
# STABLE port, and advertise that same address. Bound to loopback on a random
# port (the old default) the card's URL is a lie — no peer can connect, and the
# port changes every run so a card cannot name it. Bind the tailnet address on a
# fixed port (A2A_PORT, default 8391); with no tailnet, fall back to loopback.
A2A_PORT="${A2A_PORT:-8391}"
A2A_BIND="${A2A_BIND:-${ADVERT:-127.0.0.1}:$A2A_PORT}"
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
if [ "$PROJECT" = 1 ]; then PI_MCP="$ROOT/.pi/mcp-adapter.json"; else PI_MCP="$HOME/.pi/agent/mcp-adapter.json"; fi

WOTES="$(command -v wayofteams-mcp 2>/dev/null || true)"
# The well door: this body's MCP gateway, never the engine (engram is Kaia's).
GATEWAY_PORT="${MCP_GATEWAY_PORT:-${YMIR_MCP_GATEWAY_PORT:-8316}}"
WELL_URL="http://127.0.0.1:$GATEWAY_PORT/mcp/well"

# The Teams plane (WayOfTeams) and Anchor memory are REMOTE MCP servers, named by
# URL. The URL is credential-ish, so it comes from the environment — never the
# tracked tree. Pi has no remote transport, so it reaches them through the
# `mcp-remote` stdio bridge; OpenCode speaks `type: remote` natively.
# The environment wins; else the private platform env, so no caller must export.
platform_env_val() {  # <KEY>
  local k=$1 f v
  for f in "${YMIR_HOARD:-$YMIR_HOME/hodd}/secrets/platform.env" "$YMIR_HOME/hodd/secrets/platform.env" "$YMIR_HOME/secrets/platform.env"; do
    [ -r "$f" ] || continue
    v="$(grep -E "^$k=" "$f" 2>/dev/null | tail -1 | cut -d= -f2-)"
    [ -n "$v" ] && { printf '%s' "$v"; return 0; }
  done
}
TEAMS_URL="${WAYOFTEAMS_MCP_URL:-}";  [ -n "$TEAMS_URL" ]  || TEAMS_URL="$(platform_env_val WAYOFTEAMS_MCP_URL)"
ANCHOR_URL="${ANCHOR_MCP_URL:-}";     [ -n "$ANCHOR_URL" ] || ANCHOR_URL="$(platform_env_val ANCHOR_MCP_URL)"

python3 - "$ROOT" "$PI_MCP" "$OC" "$A2AB" "$DIR" "$ADVERT" "$WOTES" "$ACTION" "$WELL_URL" "$TEAMS_URL" "$ANCHOR_URL" "$A2A_BIND" <<'PY'
import sys, os, json, shutil, datetime
(root, pi_path, oc_path, a2ab, durl, advert, wotes, action, well_url,
 teams_url, anchor_url, a2a_bind) = sys.argv[1:13]
stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")

def direct_engram(name, spec):
    """A harness-facing engram: the name, or any stdio that runs engram-mcp."""
    if name == "engram":
        return True
    if not isinstance(spec, dict):
        return False
    cmd = spec.get("command")
    parts = (cmd if isinstance(cmd, list) else [cmd or ""]) + list(spec.get("args") or [])
    return any(os.path.basename(str(p)).startswith("engram-mcp") for p in parts)

def backup(p):
    if os.path.exists(p):
        shutil.copy2(p, f"{p}.bak-{stamp}")

def load(p, default):
    try: return json.load(open(p))
    except Exception: return default

ones = {
    "a2abridge": {
        "pi":  {"command": a2ab, "args": ["bridge", "-bind", a2a_bind, "-advertise-host", advert],
                "env": {"A2A_DIRECTORY": durl, "A2A_ADVERTISE_HOST": advert}},
        "oc":  {"type": "local", "command": [a2ab, "bridge", "-bind", a2a_bind, "-advertise-host", advert],
                "environment": {"A2A_DIRECTORY": durl, "A2A_ADVERTISE_HOST": advert}},
    },
    "well": {
        "pi":  {"url": well_url},
        "oc":  {"type": "remote", "url": well_url},
    },
}
# The Teams plane: a URL (remote) wins over a local `wayofteams-mcp` binary.
if teams_url:
    ones["wayofteams"] = {
        "pi":  {"command": "npx", "args": ["-y", "mcp-remote", teams_url]},
        "oc":  {"type": "remote", "url": teams_url},
    }
elif wotes:
    ones["wayofteams"] = {
        "pi":  {"command": wotes, "args": ["--stdio"], "env": {"WOTEAMS_URL": os.environ.get("WOTEAMS_URL","")}},
        "oc":  {"type": "local", "command": [wotes, "--stdio"], "environment": {"WOTEAMS_URL": os.environ.get("WOTEAMS_URL","")}},
    }

# Anchor — the memory plane, remote by URL.
if anchor_url:
    ones["way-of-anchor-sse"] = {
        "pi":  {"command": "npx", "args": ["-y", "mcp-remote", anchor_url]},
        "oc":  {"type": "remote", "url": anchor_url},
    }

if action == "show":
    pi = load(pi_path, {}).get("mcpServers", {})
    oc = load(oc_path, {}).get("mcp", {})
    # Report what is ACTUALLY wired, not a fixed list: a key may come from an
    # earlier install, a hand edit, or a server this script does not itself add.
    names = sorted(set(ones) | set(pi) | set(oc))
    print(f"a2a-mcp[{len(names)}]{{server,in_pi,in_opencode}}:")
    for name in names:
        print(f'  "{name}","{"yes" if name in pi else "no"}","{"yes" if name in oc else "no"}"')
    if not wotes and not teams_url:
        print('help: set WAYOFTEAMS_MCP_URL (or install wayofteams-mcp) to enable the Teams plane')
    if not anchor_url:
        print('help: set ANCHOR_MCP_URL to enable the Anchor memory plane')
    sys.exit(0)

if action != "install":
    print("error: use install|show"); sys.exit(2)

# pi mcp-adapter.json
pid = load(pi_path, {"mcpServers": {}})
pid.setdefault("mcpServers", {})
dropped = [n for n, s in list(pid["mcpServers"].items()) if direct_engram(n, s)]
if dropped:
    backup(pi_path)
for n in dropped:
    del pid["mcpServers"][n]
for name, spec in ones.items():
    pid["mcpServers"][name] = spec["pi"]
os.makedirs(os.path.dirname(pi_path), exist_ok=True)
json.dump(pid, open(pi_path, "w"), indent=2)
# pi 1.3+ reads `mcp.json`; Ymir's tools name `mcp-adapter.json`. Write both so the
# servers are actually seen (a config pi never reads is a door that looks shut).
if pi_path.endswith("mcp-adapter.json"):
    alt = pi_path[:-len("mcp-adapter.json")] + "mcp.json"
    json.dump(pid, open(alt, "w"), indent=2)

# opencode.json mcp block
ocd = load(oc_path, {"mcp": {}})
ocd.setdefault("mcp", {})
oc_dropped = [n for n, s in list(ocd["mcp"].items()) if direct_engram(n, s)]
if oc_dropped:
    backup(oc_path)
for n in oc_dropped:
    del ocd["mcp"][n]
for name, spec in ones.items():
    entry = spec["oc"]; entry["enabled"] = True
    ocd["mcp"][name] = entry
json.dump(ocd, open(oc_path, "w"), indent=2); open(oc_path, "a").write("\n")

gone = sorted(set(dropped) | set(oc_dropped))
print(f'a2a-mcp[1]{{action,servers,dropped}}:\n  "install","{",".join(ones)}","{",".join(gone) or "-"}"')
PY
