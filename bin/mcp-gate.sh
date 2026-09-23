#!/usr/bin/env bash
# mcp-gate.sh — arm/disarm an on-call MCP server in the seat's pi mcp.json.
# An on-call server is AVAILABLE but not raised at every boot: its tool
# schemas leave the boot context (the lean answer to the seat's MCP budget —
# chrome-devtools is the first citizen, a big schema a boot rarely needs).
#
# Usage:   mcp-gate.sh <arm|disarm> <server>
#          mcp-gate.sh status                 what the seat's boot table holds
# Env:     PI_MCP_JSON — the config (default ~/.pi/agent/mcp.json)
set -u

CFG="${PI_MCP_JSON:-$HOME/.pi/agent/mcp.json}"
ACTION="${1-}"; SERVER="${2-}"

chrome_spec() { python3 - "$CFG" <<'PY'
import json, sys, os
p = sys.argv[1]; d = {}
try: d = json.load(open(p))
except Exception: pass
d.setdefault("mcpServers", {})
d["mcpServers"]["chrome-devtools"] = {
  "command": os.path.expanduser("~/.local/share/mise/installs/node/26.8.1/bin/chrome-devtools-mcp"),
  "args": ["--executablePath", "/usr/bin/chromium", "--no-page-id-routing"]
}
json.dump(d, open(p, "w"), indent=2)
PY
}

arm() {
  case "$SERVER" in
    chrome-devtools) chrome_spec ;;
    *) printf 'error: unknown on-call server %s (seated: chrome-devtools)\n' "$SERVER" >&2; exit 2 ;;
  esac
  printf 'armed %s (the next session raises it on call, not at boot)\n' "$SERVER"
}

disarm() {
  python3 - "$CFG" "$SERVER" <<'PY'
import json, sys
p, s = sys.argv[1], sys.argv[2]
try: d = json.load(open(p))
except Exception: d = {}
if "mcpServers" in d and s in d["mcpServers"]:
    del d["mcpServers"][s]
    json.dump(d, open(p, "w"), indent=2)
    print(f"disarmed {s} - available on call, out of the boot")
else:
    print(f"{s} not in the boot table")
PY
}

status() {
  python3 - "$CFG" <<'PY'
import json, sys
try: d = json.load(open(sys.argv[1]))
except Exception: d = {}
print("boot table:", ", ".join(d.get("mcpServers", {}).keys()) or "(empty)")
PY
}

case "$ACTION" in
  arm|disarm) "$ACTION" ;;
  status|"") status ;;
  *) printf 'usage: mcp-gate.sh <arm|disarm|status> [server]\n' >&2; exit 2 ;;
esac