#!/usr/bin/env bash
# topology.sh — what IS this machine in the fleet, and is it talking to the heart?
#
# Plan 51 (multi-machine operations), Phase 0. Ymir had no answer to the three
# questions the Allfather asks first: is this a single computer, is it connected
# to a server, or is it one node among several — and if the server is down, is
# this machine detached or fully offline? This reports it, from ONE registry and
# the machine's own hostname. It changes nothing.
#
#   topology.sh            # this machine, as TOON
#   topology.sh --json     # the same facts, machine-readable
#   topology.sh check      # exit 0 always (a smoke/gate probe); same table
#   topology.sh --version
#
# Registry (machine-local facts, one row per host, read by hostname):
#   $YMIR_HOME/hodd/data/fleet.json   (override YMIR_FLEET_REGISTRY)
#   {
#     "heart": "whynot",
#     "hosts": { "heimdall": {"roles": ["dev"], "lan": "...", "tailnet": "..."} }
#   }
# A missing registry degrades cleanly: role defaults to "dev", shape to "single",
# link to "standalone" — never a failure, because a lone box has no registry.
#
# Env overrides: YMIR_ROLE (comma list), YMIR_HEART, YMIR_HOST (the hostname to
# report as), YMIR_LINK_TIMEOUT (seconds, default 2).
set -u

VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BROKK_HOME="${BROKK_HOME:-$ROOT}"

# The operator's home: env → recorded choice → the ONE documented default (Rule 07).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/hoard-lib.sh" "$(dirname "$SCRIPT_DIR")/bin/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
YMIR_HOME_ROOT=""
if command -v ymir_home_root >/dev/null 2>&1; then ymir_home_root YMIR_HOME_ROOT 2>/dev/null; fi
YMIR_HOME_ROOT="${YMIR_HOME_ROOT:-${YMIR_HOME}}"
STATE=""
if command -v hoard_state_dir >/dev/null 2>&1; then hoard_state_dir STATE 2>/dev/null; fi
STATE="${STATE:-${YMIR_STATE_DIR:-$YMIR_HOME_ROOT/state}}"

REGISTRY="${YMIR_FLEET_REGISTRY:-$YMIR_HOME_ROOT/hodd/data/fleet.json}"
HOST="${YMIR_HOST:-$(hostname -s 2>/dev/null | tr 'A-Z' 'a-z')}"
HOST="${HOST:-unknown}"
LINK_TIMEOUT="${YMIR_LINK_TIMEOUT:-2}"
MODE=toon
case "${1-}" in --json) MODE=json ;; check) MODE=toon ;; esac

# ── one registry read: roles, shape, heart (defaults when absent) ────────────
read -r ROLES SHAPE HEART HEART_ADDR < <(python3 - "$REGISTRY" "$HOST" <<'PY'
import json, sys
reg, host = sys.argv[1], sys.argv[2]
try:
    doc = json.load(open(reg))
except Exception:
    print("dev single  "); raise SystemExit
hosts = doc.get("hosts") or {}
me = hosts.get(host) or {}
roles = ",".join(me.get("roles") or ["dev"])
shape = "fleet" if len(hosts) > 1 else "single"
heart = str(doc.get("heart") or "")
haddr = ""
if heart:
    h = hosts.get(heart) or {}
    haddr = str(h.get("tailnet") or h.get("lan") or heart)
print(f"{roles} {shape} {heart or '-'} {haddr or '-'}")
PY
)
[ "${YMIR_ROLE:-}" ] && ROLES="$YMIR_ROLE"
# An explicit heart override probes by that name/address itself; `none` (or a
# bare empty) means this machine has no heart configured.
if [ -n "${YMIR_HEART:-}" ]; then
  HEART="$YMIR_HEART"
  HEART_ADDR="$YMIR_HEART"
fi
if [ "$HEART" = "-" ] || [ "$HEART" = "none" ]; then HEART=""; fi
[ "$HEART_ADDR" = "-" ] && HEART_ADDR=""

# ── the live link: offline · detached · attached ─────────────────────────────
has_route() { ip route show default 2>/dev/null | grep -q 'default'; }
heart_up() {  # <addr-or-name>
  [ -n "$1" ] || return 1
  if command -v getent >/dev/null 2>&1; then getent hosts "$1" >/dev/null 2>&1 || true; fi
  ping -c1 -W"$LINK_TIMEOUT" "$1" >/dev/null 2>&1
}
LINK="standalone"
if [ -n "$HEART" ]; then
  if ! has_route; then LINK="offline"
  elif heart_up "$HEART_ADDR"; then LINK="attached"
  else LINK="detached"; fi
elif ! has_route; then
  LINK="offline"
fi

# ── the journal: what has not yet reached the heart ──────────────────────────
JOURNAL="none"
_jf="$STATE/journal/$HOST.jsonl"
if [ -s "$_jf" ]; then
  _n="$(wc -l <"$_jf" | tr -d '[:space:]')"
  _age=$(( $(date -u +%s) - $(stat -c %Y "$_jf" 2>/dev/null || echo 0) ))
  JOURNAL="$_n entries, last ${_age}s ago"
fi

if [ "$MODE" = json ]; then
  python3 - "$HOST" "$ROLES" "$SHAPE" "$HEART" "$LINK" "$JOURNAL" <<'PY'
import json, sys
host, roles, shape, heart, link, journal = sys.argv[1:7]
print(json.dumps({"host": host, "roles": roles.split(","), "shape": shape,
                  "heart": heart or None, "link": link, "journal": journal}))
PY
  exit 0
fi

printf 'topology[7]{fact,value}:\n'
printf '  "host","%s"\n' "$HOST"
printf '  "roles","%s"\n' "$ROLES"
printf '  "shape","%s"\n' "$SHAPE"
printf '  "heart","%s"\n' "${HEART:-none}"
printf '  "link","%s"\n' "$LINK"
printf '  "journal","%s"\n' "$JOURNAL"
printf '  "registry","%s"\n' "$REGISTRY"
exit 0
