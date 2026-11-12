#!/usr/bin/env bash
# helm-identity.sh — WHO holds this helm, WHAT it is for, WHICH machine and fleet it
# stands on, and WHICH pinned code it runs — in ONE row, read from the RECORD.
#
# Plans 254 (B1b, B1c) and 257 (H8) asked the same question three times and the lease
# could not answer any of them: it named a pid, a generation, a service shape and a
# shelf, and left "whose hand, what for, which machine, how far behind" to be inferred
# from a path or from behaviour. So the arm WRITES those fields at take and this door
# READS them back — the record answers the question, never an inference.
#
#   helm-identity.sh                 the one row, read from the lease the arm holds
#   helm-identity.sh --lease <file>  read THAT lease (a caller that already resolved one)
#   helm-identity.sh --check         the holder gate: can THIS machine resolve host and
#                                    fleet role? exit 3 and the field is named when not
#
# THE LEASE IS THE AUTHORITY, NEVER A PATH: the lease's own `state=` names the queue
# and the room, and this door never invents a state dir.
#
# `unnamed` is RENDERED, never invented (Rule 44): a seat with no sealed name still
# holds the helm and says so. A lease that names no host or no fleet role reads
# `identity=readonly` and names the missing field — that holder may beat, but no
# errand may be seated under it.
#
# Exit: 0 read · 3 refused (the holder gate, or no lease) · 2 usage · 1 a fault.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

HOARD_LIB="$ROOT/bin/vault/hoard-lib.sh"
ENGINE="$ROOT/bin/engine/ymir-engine.sh"

usage() { sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
die()   { printf 'helm-identity: %s\n' "$*" >&2; exit 1; }
refuse(){ printf 'helm-identity: %s\n' "$*" >&2; exit 3; }

LEASE_OVERRIDE=""
ACTION="row"
while [ $# -gt 0 ]; do
  case "$1" in
    --lease) LEASE_OVERRIDE="${2:-}"; shift 2 ;;
    --check) ACTION="check"; shift ;;
    --format|row) ACTION="row"; shift ;;
    -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
    -h|--help) usage 0 ;;
    *) usage 2 ;;
  esac
done

# ── the holder gate ────────────────────────────────────────────────────────────
# The gate asks the ENGINE, because the engine is the one writer of these fields: if
# the door re-derived them here there would be two answers to one question (Rule 07).
holder_gate() {
  if [ ! -x "$ENGINE" ]; then
    refuse "the engine door is missing ($ENGINE) — this machine's identity cannot be resolved, so the helm is not taken"
  fi
  local out rc
  out="$(bash "$ENGINE" identity --check 2>&1)"; rc=$?
  printf '%s\n' "$out"
  if [ "$rc" != 0 ]; then
    return 3
  fi
  return 0
}

# ── the row ────────────────────────────────────────────────────────────────────
lease_field() {  # <file> <field>
  sed -n "s/.*\b$2=\([^ ]*\).*/\1/p" "$1" 2>/dev/null | head -1
}

charter_text() {  # planning,mail,the-work-in-hand,dispatch-on → planning · mail · the work in hand · dispatch on
  printf '%s' "$1" | tr ',' '\n' | sed 's/-/ /g; s/^ *//; s/ *$//' | grep -v '^$' | paste -sd'·' - \
    | sed 's/·/ · /g'
}

print_row() {  # <lease>
  local lease="$1" pid gen role seat charter host fleetrole fleet pin behind identity missing
  local heartbeat state_dir age queue room
  pid="$(lease_field "$lease" pid)"
  gen="$(lease_field "$lease" gen)"; [ -n "$gen" ] || gen=unknown
  role="$(lease_field "$lease" role)"; [ -n "$role" ] || role=unknown
  seat="$(lease_field "$lease" seat)"; [ -n "$seat" ] || seat=unnamed
  charter="$(lease_field "$lease" charter)"; [ -n "$charter" ] || charter="planning,mail,the-work-in-hand,dispatch-on"
  host="$(lease_field "$lease" host)"; [ -n "$host" ] || host=none
  fleetrole="$(lease_field "$lease" fleetrole)"; [ -n "$fleetrole" ] || fleetrole=none
  fleet="$(lease_field "$lease" fleet)"; [ -n "$fleet" ] || fleet=none
  pin="$(lease_field "$lease" pin)"; [ -n "$pin" ] || pin=none
  behind="$(lease_field "$lease" pin_behind)"; [ -n "$behind" ] || behind=none
  identity="$(lease_field "$lease" identity)"; [ -n "$identity" ] || identity=unknown
  missing="$(lease_field "$lease" missing)"; [ -n "$missing" ] || missing=none
  heartbeat="$(lease_field "$lease" heartbeat)"
  state_dir="$(lease_field "$lease" state)"
  age=unknown
  case "$heartbeat" in
    ''|*[!0-9]*) age=unknown ;;
    *) age=$(( $(date +%s) - heartbeat )); [ "$age" -ge 0 ] || age=0 ;;
  esac
  queue="${state_dir:-none}/.wake-queue"
  room="${state_dir:-none}/rodd/room.jsonl"
  printf 'helm[1]{seat,role,charter,host,fleetrole,fleet,pin,behind,gen,pid,heartbeat_age_s,identity,missing,state_dir,queue,room}:\n'
  printf '  "%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' \
    "$seat" "$role" "$(charter_text "$charter")" "$host" "$fleetrole" \
    "$(printf '%s' "$fleet" | tr '-' ' ')" "$pin" "$behind" "$gen" "${pid:-none}" "$age" \
    "$identity" "$missing" "${state_dir:-none}" "$queue" "$room"
}

case "$ACTION" in
  check)
    holder_gate || exit 3
    exit 0 ;;
esac

LEASE="${LEASE_OVERRIDE:-}"
if [ -z "$LEASE" ]; then
  if [ -n "${RODD_ARM_LEASE:-}" ]; then
    LEASE="$RODD_ARM_LEASE"
  else
    [ -r "$HOARD_LIB" ] || refuse "the home resolver is missing ($HOARD_LIB) — no lease can be named"
    # shellcheck source=vault/hoard-lib.sh
    . "$HOARD_LIB"
    hoard_state_dir STATE_ROOT 2>/dev/null || refuse "the home resolver could not name a state dir"
    LEASE="$STATE_ROOT/.arm.lease"
  fi
fi
[ -r "$LEASE" ] || refuse "there is no arm lease at $LEASE — nobody is holding the helm"
print_row "$LEASE"
