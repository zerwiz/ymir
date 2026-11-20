#!/usr/bin/env bash
# gladsheim.sh — the door to Gladsheim, the fleet room.
#
# Gladsheim is the council hall: the room where this operator's whole fleet speaks and
# the operator answers. This is the DOOR an agent uses to speak from the shell — so a
# seat's agent (named for itself, never a suffix) can post and read without a human in a
# browser. The window the operator reads is Element; this is the same room, the same log.
#
#   gladsheim.sh status          # is the engine up, which room, which agent, which shape
#   gladsheim.sh send "text"     # speak as this seat's agent
#   gladsheim.sh read [n]        # read the last n events (default 10)
#   gladsheim.sh who             # who this seat's token belongs to
#
# Configuration is NEVER hardcoded (Rule 07): the homeserver, server name, room id and the
# per-machine agent NAMES resolve from the operator's home —
#   $YMIR_HOME/config/room.yaml     (homeserver · server_name · room · agents{host: name})
#   $YMIR_HOME/hodd/secrets/room.env (ROOM_ACCESS_TOKEN=…, 0600 — a secret by reference)
# overridable with YMIR_ROOM_CONFIG / YMIR_ROOM_SECRETS.
#
# The shape (single machine | fleet) is asked of the ONE resolver, never re-derived here:
# bin/fleet/topology.sh (plan 76 — the shape law).
set -u

VERSION="0.1.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|help|"") sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; [ -n "${1-}" ] || exit 0; exit 0 ;;
esac

ACTION="${1-}"; shift || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -d .pi ] || [ ! -d RULES ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)}"

# The operator's home, per the ONE resolver (Rule 07).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/../../vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
fi
HOME_ROOT="${YMIR_HOME:-}"
command -v ymir_home_root >/dev/null 2>&1 && ymir_home_root HOME_ROOT
HOARD="${YMIR_HOARD:-}"
command -v hoard_root >/dev/null 2>&1 && hoard_root HOARD

CONFIG="${YMIR_ROOM_CONFIG:-$HOME_ROOT/config/room.yaml}"
SECRETS="${YMIR_ROOM_SECRETS:-${HOARD:-$HOME_ROOT/hodd}/secrets/room.env}"

die() { printf 'gladsheim: %s\n' "$*" >&2; exit 1; }

[ -r "$CONFIG" ] || die "not seated — no room config at $CONFIG (the room is not installed on this seat yet)"

# Read the config (YAML) — one small python, because bash is the wrong tool for YAML.
read_cfg() {  # <key>  — homeserver | server_name | room | agent (the name for THIS seat)
  python3 - "$CONFIG" "$1" "${YMIR_HOST:-$(hostname -s)}" <<'PY'
import sys
cfg_path, key, host = sys.argv[1:4]
try:
    import yaml
    doc = yaml.safe_load(open(cfg_path)) or {}
except Exception:
    # fail soft: a tiny parser for the flat keys this file uses
    doc = {}
    for line in open(cfg_path):
        line = line.split('#', 1)[0].rstrip()
        if not line.strip():
            continue
        if line.startswith(('  ', '\t')) and doc.get('_cur') == 'agents':
            k, _, v = line.strip().partition(':')
            doc.setdefault('agents', {})[k.strip()] = v.strip().strip('"')
            continue
        k, _, v = line.partition(':')
        k = k.strip()
        if k == 'agents':
            doc['_cur'] = 'agents'; doc['agents'] = {}; continue
        doc['_cur'] = None
        doc[k] = v.strip().strip('"')
if key == 'agent':
    print((doc.get('agents') or {}).get(host, ''))
else:
    print(doc.get(key, ''))
PY
}

HOMESERVER="$(read_cfg homeserver)"
SERVER_NAME="$(read_cfg server_name)"
ROOM="$(read_cfg room)"
AGENT="$(read_cfg agent)"
[ -n "$HOMESERVER" ] || die "no homeserver in $CONFIG"

TOKEN=""
[ -r "$SECRETS" ] && TOKEN="$(grep -oP '^ROOM_ACCESS_TOKEN=\K.*' "$SECRETS" 2>/dev/null | tail -1)"
[ -n "$TOKEN" ] || die "no token — expected ROOM_ACCESS_TOKEN in $SECRETS (0600, a secret by reference)"

API="$HOMESERVER/_matrix/client/v3"
auth() { printf 'Authorization: Bearer %s' "$TOKEN"; }

api_get() {  # <path>
  curl -s --max-time 8 "$API$1" -H "$(auth)"
}
api_put() {  # <path> <json>  — Matrix's send is PUT (idempotent per txnId)
  curl -s --max-time 10 -X PUT "$API$1" -H "$(auth)" -H 'Content-Type: application/json' -d "$2"
}

shape_line() {  # the shape law: ASK the one resolver
  local t="$ROOT/bin/fleet/topology.sh"
  [ -x "$t" ] || t="$SCRIPT_DIR/../fleet/topology.sh"
  [ -r "$t" ] || return 0
  timeout 10 bash "$t" 2>/dev/null | grep -E '"(shape|heart|link)"' | sed 's/^  //'
}

case "$ACTION" in
  status)
    if curl -s --max-time 5 "$HOMESERVER/_matrix/client/versions" >/dev/null 2>&1; then ENG="up"; else ENG="down"; fi
    ME="$(api_get /account/whoami | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("user_id",""))
except Exception: print("")' 2>/dev/null)"
    printf 'gladsheim[7]{fact,value}:\n'
    printf '  "engine","%s"\n' "$ENG"
    printf '  "homeserver","%s"\n' "$HOMESERVER"
    printf '  "server_name","%s"\n' "$SERVER_NAME"
    printf '  "room","%s"\n' "$ROOM"
    printf '  "agent","%s"\n' "${AGENT:-unnamed}"
    printf '  "speaks_as","%s"\n' "${ME:-unknown}"
    printf '  "config","%s"\n' "$CONFIG"
    shape_line
    ;;
  who)
    api_get /account/whoami | python3 -c 'import json,sys
d=json.load(sys.stdin); print("this seat speaks as %s" % d.get("user_id","?"))'
    ;;
  send)
    TEXT="${*:-}"; [ -n "$TEXT" ] || die "nothing to say — gladsheim.sh send \"text\""
    TXN="$(date +%s)$RANDOM"
    JSON="$(python3 -c 'import json,sys;print(json.dumps({"msgtype":"m.text","body":sys.argv[1]}))' "$TEXT")"
    RESP="$(api_put "/rooms/$ROOM/send/m.room.message/$TXN" "$JSON")"
    printf '%s' "$RESP" | python3 -c 'import json,sys
d=json.load(sys.stdin)
if d.get("event_id"): print("sent %s as %s" % (d["event_id"], sys.argv[1] if len(sys.argv)>1 else "?"))
else: print("refused: %s" % d.get("error","?")); sys.exit(1)' "${AGENT:-this seat}"
    ;;
  read)
    N="${1:-10}"
    api_get "/rooms/$ROOM/messages?dir=b&limit=$N" | python3 -c 'import json,sys
d=json.load(sys.stdin)
rows=[]
for e in d.get("chunk",[]):
    c=e.get("content",{})
    if c.get("body"):
        rows.append((e.get("sender","?"), c["body"]))
for s,b in reversed(rows):
    print("%s: %s" % (s,b))
print("-- %d message(s)" % len(rows))'
    ;;
  *) die "unknown action '${ACTION}' — status | send | read | who" ;;
esac
