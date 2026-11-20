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
#   role.sh resolve [--host h] # the roles to install with, strongest source first
#   role.sh resolve --why      # the same, plus which source answered (tab-separated)
#   role.sh --version
#
# `resolve` is the READ road the installer gates its component set on: an
# explicit $YMIR_ROLE wins, then this registry by hostname, then the machine's
# own card row in hodd/data/machines.md, and a host in none of them resolves to
# NOTHING (the caller asks, or records the documented safe body) — it never
# invents a role and never installs every role's parts.
set -u

VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)}"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/../../vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
YMIR_HOME_ROOT=""
if command -v ymir_home_root >/dev/null 2>&1; then ymir_home_root YMIR_HOME_ROOT 2>/dev/null; fi
YMIR_HOME_ROOT="${YMIR_HOME_ROOT:-${YMIR_HOME}}"
REGISTRY="${YMIR_FLEET_REGISTRY:-$YMIR_HOME_ROOT/hodd/data/fleet.json}"
HOST="${YMIR_HOST:-$(hostname -s 2>/dev/null | tr 'A-Z' 'a-z')}"
KNOWN="heart forge dev hand"

usage() { printf 'error: %s\nhelp: role.sh show [host] | set <host> <roles> | rm <host> | validate | resolve [--host h] [--why]\n' "$1" >&2; exit 2; }

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
  resolve)
    # The roles to INSTALL with (plan 51 P1). Precedence, strongest first:
    #   env      $YMIR_ROLE (what the operator named for this run)
    #   registry the fleet registry, by hostname (this script's own store)
    #   card     the machine's card row in hodd/data/machines.md, by hostname
    #   none     nothing declared — the caller asks or records the safe body
    R_WANT_SRC=0; R_HOST=""
    shift
    while [ $# -gt 0 ]; do
      case "$1" in
        --why) R_WANT_SRC=1; shift ;;
        --host) R_HOST="${2-}"; shift 2 ;;
        *) usage "resolve: unknown flag $1" ;;
      esac
    done
    R_HOST="${R_HOST:-$HOST}"
    MACHINES="${YMIR_MACHINES_MD:-$YMIR_HOME_ROOT/hodd/data/machines.md}"
    R_LINE="$(python3 - "$REGISTRY" "$MACHINES" "$R_HOST" "${YMIR_ROLE:-}" "$KNOWN" <<'PY'
import json, re, sys
reg, machines, host, env_role, known = sys.argv[1:6]
known = known.split()

def emit(roles, src):
    print(",".join(roles) + "\t" + src)
    raise SystemExit

if env_role:
    roles = [r for r in env_role.split(",") if r]
    bad = [r for r in roles if r not in known]
    if bad:
        print("!" + ",".join(bad) + "\tenv")
        raise SystemExit
    emit(roles, "env")

try:
    doc = json.load(open(reg))
except Exception:
    doc = {}
row = (doc.get("hosts") or {}).get(host) or {}
roles = [r for r in (row.get("roles") or []) if r in known]
if roles:
    emit(roles, "registry")

try:
    text = open(machines).read()
except Exception:
    text = ""
roles = []
for line in text.splitlines():
    s = line.strip()
    if not s.startswith("|"):
        continue
    cells = [c.strip().strip("*` ").lower() for c in s.strip("|").split("|")]
    if host.lower() not in cells:
        continue
    for r in known:                      # stable order: heart forge dev hand
        if r not in roles and re.search(r"\b" + re.escape(r) + r"\b", line.lower()):
            roles.append(r)
if roles:
    emit(roles, "card")

print("\tnone")
PY
)"
    case "$R_LINE" in
      '!'*) printf 'error: unknown role in YMIR_ROLE: %s (known: %s)\n' "$(printf '%s' "${R_LINE%%$'\t'*}" | sed 's/^!//')" "$KNOWN" >&2; exit 2 ;;
    esac
    R_ROLES="${R_LINE%%$'\t'*}"; R_SRC="${R_LINE##*$'\t'}"
    [ -n "$R_SRC" ] || R_SRC="none"
    if [ "$R_WANT_SRC" = 1 ]; then printf '%s\t%s\n' "$R_ROLES" "$R_SRC"; else printf '%s\n' "$R_ROLES"; fi
    ;;
  *) usage "unknown action ${1}" ;;
esac
