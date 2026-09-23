#!/usr/bin/env bash
# eindri-route.sh — which machine should host an errand, by its nature?
#
# Plan 51 (multi-machine operations), Phase 5. An errand belongs to the role that
# fits it: a model/GPU job to the FORGE, a desktop/UI job to a DEV body, a
# record/ledger job to the HEART. This reads the fleet registry and prints the
# target host(s). It is a planner, not a dispatcher — it changes nothing.
#
#   eindri-route.sh <kind> [--json]
#   eindri-route.sh model     -> the forge host(s)
#   eindri-route.sh ui        -> a dev host
#   eindri-route.sh record    -> the heart
#   eindri-route.sh any       -> this machine first, then the fleet
#   eindri-route.sh --kinds   # the known kinds and their roles
#   eindri-route.sh --version
set -u

VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

# kind -> role. The classifier is a table, so it is easy to read and extend.
role_for() {
  case "$1" in
    model|bench|gpu|train|vram|inference) echo forge ;;
    ui|desktop|app|frontend|design|theme|window|monitor) echo dev ;;
    record|ledger|memory|engram|backlog|plan|planning|sync|ticket|audit) echo heart ;;
    any|"") echo any ;;
    *) echo "" ;;
  esac
}

if [ "${1-}" = "--kinds" ]; then
  printf 'eindri_kinds[4]{kind,role}:\n'
  printf '  "model|bench|gpu|train|inference","forge"\n'
  printf '  "ui|desktop|app|frontend|design|theme","dev"\n'
  printf '  "record|ledger|memory|backlog|plan|sync|ticket|audit","heart"\n'
  printf '  "any|<unmatched>","any"\n'
  exit 0
fi

KIND="${1:-any}"; shift || true
MODE=toon; [ "${1-}" = "--json" ] && MODE=json

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

ROLE="$(role_for "$KIND")"
if [ -z "$ROLE" ]; then
  printf 'eindri_route[2]{kind,role}:\n  "%s","unmatched — defaulting to any"\n' "$KIND"
  ROLE=any
fi

TARGETS="$(python3 - "$REGISTRY" "$ROLE" "$HOST" <<'PY'
import json, sys
reg, role, me = sys.argv[1], sys.argv[2], sys.argv[3]
try: doc = json.load(open(reg))
except Exception: doc = {}
hosts = {h: (v or {}).get("roles") or [] for h, v in (doc.get("hosts") or {}).items()}
if role == "any":
    order = [me] + sorted(h for h in hosts if h != me)
else:
    order = sorted(h for h, r in hosts.items() if role in r)
print(",".join(order))
PY
)"
[ -n "$TARGETS" ] || TARGETS="$HOST"

if [ "$MODE" = json ]; then
  python3 - "$KIND" "$ROLE" "$TARGETS" <<'PY'
import json, sys
kind, role, targets = sys.argv[1], sys.argv[2], sys.argv[3]
print(json.dumps({"kind": kind, "role": role, "targets": [t for t in targets.split(",") if t]}))
PY
  exit 0
fi

printf 'eindri_route[2]{kind,targets}:\n'
printf '  "%s","%s"\n' "$KIND" "$TARGETS"
exit 0
