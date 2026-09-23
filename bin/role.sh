#!/usr/bin/env bash
# role.sh — declare, read, and validate a machine's ROLE (plan 51, Phase 1).
#
# Role is the one fact every surface derives from — install, update, MCP config,
# the cron set, the model rail, and dispatch (plan 51 law 2). It is recorded ONCE
# in the fleet registry, per host, and read by hostname. This is the writer and
# the validator for that registry.
#
#   role.sh show               # this machine's roles + the whole roster (TOON)
#   role.sh show <host>        # one host's roles
#   role.sh set <host> <r>[,<r>]   # set a host's roles (heart,forge,dev,hand)
#   role.sh rm <host>          # remove a host row
#   role.sh validate           # every role in the roster is known (exit 1 if not)
#   role.sh --version
set -u

VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/hoard-lib.sh" "$(dirname "$SCRIPT_DIR")/bin/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
YMIR_HOME_ROOT=""
if command -v ymir_home_root >/dev/null 2>&1; then ymir_home_root YMIR_HOME_ROOT 2>/dev/null; fi
YMIR_HOME_ROOT="${YMIR_HOME_ROOT:-${YMIR_HOME:-$HOME/Documents/ymirhome}}"
REGISTRY="${YMIR_FLEET_REGISTRY:-$YMIR_HOME_ROOT/hodd/data/fleet.json}"
HOST="${YMIR_HOST:-$(hostname -s 2>/dev/null | tr 'A-Z' 'a-z')}"
KNOWN="heart forge dev hand"

usage() { printf 'error: %s\nhelp: role.sh show [host] | set <host> <roles> | rm <host> | validate\n' "$1" >&2; exit 2; }

case "${1-show}" in
  show)
    TARGET="${2:-}"
    python3 - "$REGISTRY" "$TARGET" "$HOST" <<'PY'
import json, sys
reg, target, me = sys.argv[1], sys.argv[2], sys.argv[3]
try: doc = json.load(open(reg))
except Exception: doc = {}
hosts = doc.get("hosts") or {}
heart = doc.get("heart") or "-"
name = target or me
roles = ",".join((hosts.get(name) or {}).get("roles") or []) or "unassigned"
print("role[3]{host,roles,heart}:")
print(f'  "{name}","{roles}","{heart}"')
print("roster[%d]{host,roles}:" % len(hosts))
for h in sorted(hosts):
    print(f'  "{h}","{",".join((hosts[h] or {}).get("roles") or []) or "unassigned"}"')
PY
    ;;
  set)
    [ -n "${2-}" ] && [ -n "${3-}" ] || usage "set needs <host> <roles>"
    _h="$2"; _r="$3"
    for _one in ${_r//,/ }; do
      case " $KNOWN " in *" $_one "*) ;; *) printf 'error: unknown role %s (known: %s)\n' "$_one" "$KNOWN" >&2; exit 2 ;; esac
    done
    python3 - "$REGISTRY" "$_h" "$_r" <<'PY'
import json, os, sys
reg, host, roles = sys.argv[1], sys.argv[2], sys.argv[3]
try: doc = json.load(open(reg))
except Exception: doc = {}
doc.setdefault("hosts", {})
doc["hosts"].setdefault(host, {})
doc["hosts"][host]["roles"] = [r for r in roles.split(",") if r]
doc.setdefault("heart", doc.get("heart") or "")
os.makedirs(os.path.dirname(reg), exist_ok=True)
tmp = reg + ".tmp"
with open(tmp, "w") as h: json.dump(doc, h, indent=2); h.write("\n")
os.replace(tmp, reg)
print(f'role: {host} -> {",".join(doc["hosts"][host]["roles"])}')
PY
    ;;
  rm)
    [ -n "${2-}" ] || usage "rm needs <host>"
    python3 - "$REGISTRY" "$2" <<'PY'
import json, os, sys
reg, host = sys.argv[1], sys.argv[2]
try: doc = json.load(open(reg))
except Exception: doc = {}
doc.get("hosts", {}).pop(host, None)
tmp = reg + ".tmp"
with open(tmp, "w") as h: json.dump(doc, h, indent=2); h.write("\n")
os.replace(tmp, reg)
print(f"role: removed {host}")
PY
    ;;
  validate)
    python3 - "$REGISTRY" "$KNOWN" <<'PY'
import json, sys
reg, known = sys.argv[1], set(sys.argv[2].split())
try: doc = json.load(open(reg))
except Exception: print("role: no registry (valid)"); raise SystemExit
bad = []
for h, v in (doc.get("hosts") or {}).items():
    for r in (v or {}).get("roles") or []:
        if r not in known: bad.append(f"{h}:{r}")
heart = doc.get("heart")
if heart and heart not in (doc.get("hosts") or {}): print(f"role: heart {heart} is not a host row")
if bad:
    print("role: UNKNOWN roles -> " + ", ".join(bad)); raise SystemExit(1)
print("role: all roles known")
PY
    ;;
  *) usage "unknown action ${1}" ;;
esac
