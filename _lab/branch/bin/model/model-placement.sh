#!/usr/bin/env bash
# model-placement.sh — which machine hosts the models, and is the rail up?
#
# Plan 51 (multi-machine operations), Phases 5 + 9c. Models are hardware-bound; a
# body does not download 20 GB to a laptop — it calls a strong box over the
# tailnet. The rails are a LIVE set: whichever strong box is CONNECTED serves, and
# a dropped box reroutes. This reports the fleet's rails through the ONE resolver
# (`bin/model/rail-resolve.sh` → `src/ymir_runtime/fleet/rail.py`) — the registry's
# `rails` list, else its `ear` list, else its `forge` hosts — whether each answers,
# and this machine's one-local-model lock. Offline-safe.
#
#   model-placement.sh            # TOON
#   model-placement.sh --json
#   model-placement.sh check      # the gate; exit 1 on an unresolved alias
#   model-placement.sh --version
set -u

VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
MODE=toon
case "${1-}" in --json) MODE=json ;; check) MODE=check ;; esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/../../vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
YMIR_HOME_ROOT=""
if command -v ymir_home_root >/dev/null 2>&1; then ymir_home_root YMIR_HOME_ROOT 2>/dev/null; fi
YMIR_HOME_ROOT="${YMIR_HOME_ROOT:-${YMIR_HOME}}"
RAIL_PORT="${YMIR_RAIL_PORT:-8080}"

# the local one-local-model lock
LOCK="unknown"
if [ -x "$SCRIPT_DIR/local-model-lock.sh" ]; then
  LOCK="$(bash "$SCRIPT_DIR/local-model-lock.sh" check 2>/dev/null | tr -d '\n' | sed 's/.*"\(free\|held\)".*/\1/' || echo unknown)"
  case "$LOCK" in free|held) ;; *) LOCK="unknown" ;; esac
fi

# The rails are a LIVE set (plan 51 Part 9c): the ONE resolver names the strong
# boxes, probes each, and ranks first-alive. A dropped box shows as unreachable
# and drops out of the serving answer — never hidden, and never restated here.
export YMIR_RAIL_PORT="${YMIR_RAIL_PORT:-$RAIL_PORT}"
RAIL_JSON="$(bash "$SCRIPT_DIR/rail-resolve.sh" status --json 2>/dev/null || true)"
if [ -z "$RAIL_JSON" ]; then
  printf 'model_placement[1]{note,local_lock}:\n  "the rail resolver answered nothing (registry unreadable, or the engine is absent)","%s"\n' "$LOCK"
  exit 0
fi

# the alias-conformance gate (plan 51 §6): every alias this seat's registry
# names must resolve on the RESOLVED provider — whichever strong box serves.
# `check` exits 1 on a missing alias, so a rename can never silently break a seat.
ALIAS_VERDICT="skipped"; ALIAS_NOTE="gate absent"
if [ "${YMIR_ALIAS_CHECK:-on}" != off ] && [ -x "$SCRIPT_DIR/../gates/checks/model-alias-check.sh" ]; then
  _ao="$(bash "$SCRIPT_DIR/../gates/checks/model-alias-check.sh" --local 2>/dev/null)" || true
  ALIAS_VERDICT="$(printf '%s' "$_ao" | sed -nE 's/^  "verdict","([^"]+)".*/\1/p' | head -1)"
  [ -n "$ALIAS_VERDICT" ] || ALIAS_VERDICT="unknown"
  if [ "$ALIAS_VERDICT" = FAIL ]; then
    ALIAS_NOTE="$(printf '%s' "$_ao" | grep -m1 '^help:' | sed 's/^help: //')"
  elif [ "$ALIAS_VERDICT" = pass ]; then
    ALIAS_NOTE="every alias this seat names resolves (or its rail is offline)"
  fi
fi

if [ "$MODE" = json ]; then
  python3 - "$RAIL_JSON" "$LOCK" "$ALIAS_VERDICT" "$ALIAS_NOTE" <<'PY'
import json, sys
doc = json.loads(sys.argv[1])
rows = [{"host": r.get("host"), "rail": r.get("base"), "roles": r.get("roles") or [],
         "reachable": "yes" if r.get("live") else "no"} for r in doc.get("rails") or []]
print(json.dumps({"forges": rows, "serving": doc.get("serving"), "local_lock": sys.argv[2],
                  "alias_conformance": {"verdict": sys.argv[3], "detail": sys.argv[4]}}))
PY
  exit 0
fi

python3 - "$RAIL_JSON" "$LOCK" "$ALIAS_VERDICT" "$ALIAS_NOTE" <<'PY'
import json, sys
doc = json.loads(sys.argv[1]); rails = doc.get("rails") or []
serving = doc.get("serving") or {}
print('model_placement[%d]{host,rail,reachable}:' % len(rails))
for r in rails:
    print('  "%s","%s","%s"' % (r.get("host"), r.get("base"), "yes" if r.get("live") else "no"))
print('model_placement[1]{serving,key_ref}:')
print('  "%s","%s"' % (serving.get("host") or "none", serving.get("key_ref") or "LLAMA_SWAP_API_KEY"))
print('model_placement[1]{note,local_lock}:')
print('  "the strong boxes serve the fleet by liveness (plan 51 Part 9c); a body calls one over the tailnet","%s"' % sys.argv[2])
print('model_placement[1]{alias_conformance,detail}:')
print('  "%s","%s"' % (sys.argv[3], sys.argv[4]))
PY
if [ "$MODE" = check ] && [ "$ALIAS_VERDICT" = FAIL ]; then exit 1; fi
exit 0
