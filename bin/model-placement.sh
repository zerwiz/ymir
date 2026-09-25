#!/usr/bin/env bash
# model-placement.sh — which machine hosts the models, and is the rail up?
#
# Plan 51 (multi-machine operations), Phase 5. Models are hardware-bound; the
# FORGE owns the heavy rail and a body does not download 20 GB to a laptop — it
# calls the forge over the tailnet. This reports the fleet's rails (every host
# whose role includes `forge`), whether each answers, and this machine's
# one-local-model lock. Offline-safe.
#
#   model-placement.sh            # TOON
#   model-placement.sh --json
#   model-placement.sh --version
set -u

VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
MODE=toon
[ "${1-}" = "--json" ] && MODE=json

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/hoard-lib.sh" "$(dirname "$SCRIPT_DIR")/bin/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
YMIR_HOME_ROOT=""
if command -v ymir_home_root >/dev/null 2>&1; then ymir_home_root YMIR_HOME_ROOT 2>/dev/null; fi
YMIR_HOME_ROOT="${YMIR_HOME_ROOT:-${YMIR_HOME}}"
REGISTRY="${YMIR_FLEET_REGISTRY:-$YMIR_HOME_ROOT/hodd/data/fleet.json}"
HOST="${YMIR_HOST:-$(hostname -s 2>/dev/null | tr 'A-Z' 'a-z')}"
RAIL_PORT="${YMIR_RAIL_PORT:-8080}"

# the local one-local-model lock
LOCK="unknown"
if [ -x "$SCRIPT_DIR/local-model-lock.sh" ]; then
  LOCK="$(bash "$SCRIPT_DIR/local-model-lock.sh" check 2>/dev/null | tr -d '\n' | sed 's/.*"\(free\|held\)".*/\1/' || echo unknown)"
  case "$LOCK" in free|held) ;; *) LOCK="unknown" ;; esac
fi

# the forge rails, from the registry
_map="$(python3 - "$REGISTRY" "$HOST" "$RAIL_PORT" <<'PY'
import json, sys
reg, me, port = sys.argv[1], sys.argv[2], sys.argv[3]
try: doc = json.load(open(reg))
except Exception: doc = {}
hosts = doc.get("hosts") or {}
for h in sorted(hosts):
    roles = (hosts[h] or {}).get("roles") or []
    if "forge" not in roles: continue
    addr = str((hosts[h] or {}).get("tailnet") or (hosts[h] or {}).get("lan") or h)
    print(f"{h}\thttp://{addr}:{port}\t{roles}")
PY
)"
if [ -z "$_map" ]; then
  printf 'model_placement[1]{note,local_lock}:\n  "no forge host in the registry","%s"\n' "$LOCK"
  exit 0
fi

reach() { curl -fsS -m 2 -o /dev/null "$1" 2>/dev/null && echo yes || echo no; }

if [ "$MODE" = json ]; then
  python3 - "$_map" "$LOCK" <<'PY'
import json, sys, subprocess
rows=[]
for line in sys.argv[1].splitlines():
    h,rail,roles=line.split("\t")
    ok="yes" if subprocess.run(["curl","-fsS","-m","2","-o","/dev/null",rail]).returncode==0 else "no"
    rows.append({"host":h,"rail":rail,"roles":roles.split(","),"reachable":ok})
print(json.dumps({"forges":rows,"local_lock":sys.argv[2]}))
PY
  exit 0
fi

printf 'model_placement[%s]{host,rail,reachable}:\n' "$(printf '%s\n' "$_map" | wc -l | tr -d '[:space:]')"
printf '%s\n' "$_map" | while IFS=$'\t' read -r h rail roles; do
  printf '  "%s","%s","%s"\n' "$h" "$rail" "$(reach "$rail")"
done
printf 'model_placement[1]{note,local_lock}:\n  "the forge owns the heavy rail; a body calls it over the tailnet","%s"\n' "$LOCK"
exit 0
