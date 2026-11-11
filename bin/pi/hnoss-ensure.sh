#!/usr/bin/env bash
# hnoss-ensure.sh — seat and check the Hnoss (OpenDesign) MCP bridge on a machine.
#
# WHAT IT SEATS (three things, all of them copies that used to be hand-made):
#   1. the pi MCP entry `hnoss` → this tree's `bin/pi/hnoss-mcp-launch.sh`
#      (merged into ~/.pi/agent/mcp.json + mcp-adapter.json, every other server kept);
#   2. a compatibility shim at any OLD path a config still names (the launcher used to be
#      hand-placed outside the tree), so that config keeps working; the old path is read
#      from the config itself, never hardcoded;
#   3. the model door itself: the launcher resolves pi's provider through the Bifrost
#      bridge (`bin/bridge/bifrost-bridge.sh`), which carries the `x-opencode-session`
#      header the Zen gateway demands and the BYOK client cannot add.
#
# WHY: on 2026-11-10 the launcher was a hand-file placed outside the tree, it did not
# resolve a pi BUILT-IN provider, and every design generation silently paired the local
# rail with `deepseek-v4.1-flash` — a door and a model that cannot answer each other. A
# door that only exists as a hand-copy is a door no install seats and no update mends.
#
# Usage:
#   hnoss-ensure.sh status            # is the door seated, and does it resolve?
#   hnoss-ensure.sh ensure [--install]
#   hnoss-ensure.sh --version
#
# Exit: 0 seated (or made seated), 1 not seated, 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"
LAUNCHER="$ROOT/bin/pi/hnoss-mcp-launch.sh"
PI_DIR="${PI_AGENT_DIR:-${PI_DIR:-$HOME/.pi/agent}}"
CONFIGS=(mcp.json mcp-adapter.json)

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
CMD="${1-}"; shift || true
case "$CMD" in status|ensure) ;; *) printf 'error: unknown command %s\nhelp: bin/pi/hnoss-ensure.sh [status|ensure [--install]]\n' "$CMD" >&2; exit 2 ;; esac
DO_INSTALL=0
for a in "$@"; do [ "$a" = "--install" ] && DO_INSTALL=1; done

mcp_command() {  # the command the pi MCP config names for `hnoss`, if any
  python3 - "$PI_DIR" "${CONFIGS[@]}" <<'PY' 2>/dev/null || true
import json, os, sys
pdir = sys.argv[1]
for name in sys.argv[2:]:
    try:
        d = json.load(open(os.path.join(pdir, name)))
    except Exception:
        continue
    e = (d.get("mcpServers") or {}).get("hnoss") or {}
    if e.get("command"):
        print(e["command"])
        raise SystemExit
PY
}

# A config may still name the OLD hand-placed path. It is read from the config, never
# hardcoded: the shim goes wherever that path was, and only while something names it.
write_shim() {  # <old-path>
  local old="$1"
  [ -n "$old" ] || return 0
  case "$old" in */hnoss-mcp-launch.sh) ;; *) return 0 ;; esac
  [ -d "$(dirname "$old")" ] && [ -w "$(dirname "$old")" ] || return 0
  printf '#!/bin/sh\n# Seated by bin/pi/hnoss-ensure.sh — the shipped launcher is the source\n# of truth; this path exists only so an older config keeps working.\nexec "%s" "$@"\n' "$LAUNCHER" >"$old" \
    && chmod 755 "$old" && printf 'hnoss: shim → %s\n' "$old"
}

daemon_state() {
  if curl -fsS -m 2 "${OD_DAEMON_URL:-http://127.0.0.1:7456}/api/health" >/dev/null 2>&1; then
    printf 'up'
  else
    printf 'down'
  fi
}

have_server() { command -v open-design-mcp >/dev/null 2>&1; }

# The engine is ADOPTED, never forced (open-source first): a machine that has no design
# studio owes no bridge, and a clean skip with its reason is a pass (RULES/25). A machine
# that HAS the studio but has lost the bridge server is a real fault.
studio_present() {
  command -v od >/dev/null 2>&1 && return 0
  [ -d "${OD_DEPLOY_DIR:-$HOME/opendesign/deploy}" ] && return 0
  command -v docker >/dev/null 2>&1 && docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q 'open-design'
}

report() { printf 'hnoss[7]{item,state,detail}:\n'; }

case "$CMD" in
  status)
    bad=0
    report
    if have_server; then printf '  "mcp server","present","open-design-mcp on PATH"\n'
    elif ! studio_present; then
      # No design engine on this machine: nothing is owed, and saying so is the pass.
      printf '  "mcp server","skipped","no design studio on this machine (od / open-design container absent)"\n'
      printf '  "launcher","skipped","seated with the studio: bin/pi/hnoss-ensure.sh ensure --install"\n'
      exit 0
    else printf '  "mcp server","ABSENT","npm i -g open-design-mcp"\n'; bad=1; fi
    if [ -x "$LAUNCHER" ]; then printf '  "launcher","present","bin/pi/hnoss-mcp-launch.sh"\n'
    else printf '  "launcher","ABSENT","%s"\n' "$LAUNCHER"; bad=1; fi
    seat="$(mcp_command)"
    # Any Ymir tree's copy of the SAME shipped script is a lawful seat (a worktree
    # answers as itself); a different script — the old hand-file — is not.
    case "$seat" in
      */bin/pi/hnoss-mcp-launch.sh) printf '  "pi mcp entry","seated","hnoss → %s"\n' "$seat" ;;
      *) printf '  "pi mcp entry","NOT SEATED","names "%s""\n' "${seat:-nothing}"; bad=1 ;;
    esac
    # A STATUS check resolves only: it never raises the bridge, and it needs no network.
    if door="$("$LAUNCHER" --resolve 2>&1)"; then
      provider="$(printf '%s' "$door" | sed -n 's/^  "\([^"]*\)".*/\1/p' | head -1)"
      model="$(printf '%s' "$door" | sed -n 's/^  "[^"]*","\([^"]*\)".*/\1/p' | head -1)"
      url="$(printf '%s' "$door" | sed -n 's/^  "[^"]*","[^"]*","\([^"]*\)".*/\1/p' | head -1)"
      printf '  "model door","resolves","%s · %s · %s"\n' "$provider" "$model" "$url"
    else
      printf '  "model door","REFUSED","%s"\n' "$(printf '%s' "$door" | tr '\n' ' ' | cut -c1-160)"; bad=1
    fi
    printf '  "studio daemon","%s","bin/pi/open-design.sh status · open-design-mcp tools read it"\n' "$(daemon_state)"
    [ "$bad" = 0 ]
    ;;

  ensure)
    [ -x "$LAUNCHER" ] || { printf 'hnoss: the shipped launcher is missing: %s\n' "$LAUNCHER" >&2; exit 1; }
    # The bridge server itself — installed by npm when the machine has a studio to serve.
    if ! have_server; then
      if ! studio_present; then
        printf 'hnoss: skipped — no design studio on this machine (nothing to seat)\n'
        exit 0
      fi
      if [ "${DO_INSTALL:-0}" = 1 ] && command -v npm >/dev/null 2>&1; then
        npm install -g open-design-mcp >/dev/null 2>&1 \
          && printf 'hnoss: installed open-design-mcp (npm -g)\n' \
          || { printf 'hnoss: open-design-mcp could not be installed (npm -g)\n' >&2; exit 1; }
      else
        printf 'hnoss: open-design-mcp is missing — npm i -g open-design-mcp (or re-run with --install)\n' >&2
        exit 1
      fi
    fi
    # 1. the pi MCP entry — merged, never rewritten (every other server survives). The
    # path the config ALREADY names is remembered first, so a config that still points at
    # the old hand-placed launcher keeps working through a shim at that same path.
    old_seat="$(mcp_command)"
    python3 - "$PI_DIR" "$LAUNCHER" <<'PY'
import json, os, shutil, sys, time
pdir, launcher = sys.argv[1], sys.argv[2]
entry = {"command": launcher, "args": []}
os.makedirs(pdir, exist_ok=True)
seed = {}
for name in ("mcp-adapter.json", "mcp.json"):
    try:
        seed = json.load(open(os.path.join(pdir, name)))
        break
    except Exception:
        continue
for name in ("mcp.json", "mcp-adapter.json"):
    path = os.path.join(pdir, name)
    doc = {}
    if os.path.exists(path):
        try:
            doc = json.load(open(path))
        except Exception:
            doc = {}
    else:
        doc = json.loads(json.dumps(seed))          # a new file inherits the other's servers
    servers = doc.setdefault("mcpServers", {})
    if servers.get("hnoss") == entry:
        continue
    if os.path.exists(path):
        shutil.copyfile(path, path + ".bak-" + time.strftime("%Y%m%dT%H%M%SZ"))
    servers["hnoss"] = entry
    with open(path, "w") as f:
        json.dump(doc, f, indent=2)
        f.write("\n")
    print(f"hnoss: {name} — hnoss → {launcher}")
PY
    # 2. the compatibility shim, at whatever path a config used to name.
    write_shim "$old_seat"
    # 3. the model door: resolve it now, so a refused provider is reported here rather
    #    than in a generation that dies minutes later.
    # A STATUS check resolves only: it never raises the bridge, and it needs no network.
    if door="$("$LAUNCHER" --resolve 2>&1)"; then
      printf '%s\n' "$door" | grep -E '^\[hnoss\]' >&2 || true
    else
      printf 'hnoss: NOT mended — the model door refuses:\n%s\n' "$door" >&2
      exit 1
    fi
    ;;
esac
