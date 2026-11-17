#!/usr/bin/env bash
# a2a-bridge-session.sh — spawn THIS session's A2A bridge under its own, honest identity.
#
# WHY (measured 2026-10-24, corrected 2026-11-16 by plan 303 §11 and §12.3 step 6): every
# session was given the SAME a2abridge arguments — one bind address, no name, no id, no state
# dir — so on a box running two sessions the first took the port and every later session's
# MCP child failed to bind, answering "Connection closed" with no card at all. A bridge also
# carries its own inbox in its state dir, so sharing one merged two agents' mail. Sep 16's
# finding added: every bridge was named `brokk-<number>` and labelled `model=pi`, whatever
# harness it belonged to, which breaks RULES/44 and makes two agents of any other harness
# indistinguishable; and every bridge advertised `127.0.0.1`, which no other machine can dial.
#
# So the identity is resolved HERE, per spawn, from the session's own environment:
#
#   harness   pi | claude | hermes | codex | …   ($A2A_HARNESS, else detected, else unknown)
#   pane      this session's herdr pane           ($HERDR_PANE_ID, the same id the stamp uses)
#   name/id   <harness>-<pane>                    (pi-w6R-p1) — never `brokk-` for a non-pi agent
#   host      the fleet registry's name for this machine (never 127.0.0.1 on a fleet seat)
#   port      the first free one from A2A_PORT (8391), reserved atomically, dead claims swept
#   state     $HOME/.a2abridge/state/<id>         one inbox per session
#
# Rule 07: every value resolves from the environment with one documented default. A stale port
# reservation — a directory whose `pid` is gone — is released before the span is exhausted, so
# a bridge can always start.
#
#   a2a-bridge-session.sh            spawn the bridge (what a harness's MCP entry calls)
#   a2a-bridge-session.sh --dry      print what it would run, and claim nothing
#   a2a-bridge-session.sh --identity print the resolved identity only
set -u

A2AB="${A2ABRIDGE_BIN:-$HOME/.a2abridge/bin/a2abridge}"
DIRECTORY="${A2A_DIRECTORY:-http://127.0.0.1:7777}"
BASE_PORT="${A2A_PORT:-8391}"
SPAN="${A2A_PORT_SPAN:-40}"
PORTS_DIR="$HOME/.a2abridge/ports"

DRY=0; IDENTITY_ONLY=0
case "${1-}" in
  --dry) DRY=1 ;;
  --identity) IDENTITY_ONLY=1 ;;
  -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

# ── who we are ───────────────────────────────────────────────────────────────────
detect_harness() {
  [ -n "${A2A_HARNESS:-}" ] && { printf '%s' "$A2A_HARNESS"; return; }
  if [ -n "${PI_SESSION_ID:-}${BROKK_SESSION_ID:-}" ]; then printf 'pi'; return; fi
  if [ -n "${CLAUDE_SESSION_ID:-}${CLAUDE_CODE_ENTRYPOINT:-}" ]; then printf 'claude'; return; fi
  if [ -n "${HERMES_SESSION_ID:-}${HERMES_HOME:-}" ]; then printf 'hermes'; return; fi
  if [ -n "${CODEX_HOME:-}${CODEX_SESSION_ID:-}" ]; then printf 'codex'; return; fi
  # an agent that names itself in herdr is still readable from the pane below; a harness we
  # cannot name is `unknown`, never `brokk` — an invented identity is worse than a plain one.
  printf 'unknown'
}

HARNESS="$(detect_harness)"
PANE="${HERDR_PANE_ID:-}"
SHORT=""
if [ -n "${PI_SESSION_ID:-}${BROKK_SESSION_ID:-}" ]; then
  SHORT="$(printf '%s' "${PI_SESSION_ID:-$BROKK_SESSION_ID}" | tr -d '-' | cut -c1-8)"
fi

# the pane is the addressable half of an identity; without one, the session's own short id.
if [ -n "$PANE" ]; then
  SUFFIX="$(printf '%s' "$PANE" | tr ':' '-')"
elif [ -n "$SHORT" ]; then
  SUFFIX="$SHORT"
else
  SUFFIX="$(printf '%s:%s' "$$" "${PWD:-/}" | cksum | awk '{print $1}')"
fi

NAME="${A2A_AGENT_NAME:-$HARNESS-$SUFFIX}"
ID="${A2A_AGENT_ID:-$NAME}"
STATE_DIR="${A2A_STATE_DIR:-$HOME/.a2abridge/state/$ID}"
MODEL="${A2A_MODEL:-$HARNESS}"
SKILLS="${A2A_SKILLS:-ymir,$(basename "${PWD:-ymir}")}"

# ── where we are ─────────────────────────────────────────────────────────────────
# The address a peer can dial. A fleet seat advertises the name the fleet registry gives it;
# a lone box advertises loopback, because that is the truth there.
registry_host() {
  local root reg me home
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  # The home is RESOLVED, never assumed (defaults-guard): the one resolver names it, and only then
  # is the fleet registry read. Measured 2026-11-17: this line was the last unresolved default in
  # the tree, and it blocks every push until it asks.
  home="${YMIR_HOME:-}"
  if [ -z "$home" ] && [ -r "$root/bin/vault/hoard-lib.sh" ]; then
    . "$root/bin/vault/hoard-lib.sh" 2>/dev/null || true
    declare -f ymir_home_root >/dev/null 2>&1 && ymir_home_root home 2>/dev/null
  fi
  reg="${home:-}/hodd/data/fleet.json"
  [ -r "$reg" ] || return 0
  me="$(hostname -s 2>/dev/null || hostname)"
  python3 - "$reg" "$me" <<'PY' 2>/dev/null
import json, sys
d = json.load(open(sys.argv[1]))
h = (d.get("hosts") or {}).get(sys.argv[2]) or {}
print(h.get("tailnet") or "")
PY
}
ADVERTISE="${A2A_ADVERTISE_HOST:-$(registry_host)}"
ADVERTISE="${ADVERTISE:-127.0.0.1}"
BIND_IP=""
if [ "$ADVERTISE" != "127.0.0.1" ]; then
  BIND_IP="$(getent hosts "$ADVERTISE" 2>/dev/null | awk '{print $1; exit}')"
fi
# A card that names an address nobody can dial is the fault §11 measured. So: bind the
# advertised name's own address where it resolves here, bind every interface where it does
# not, and use loopback only on a box that advertises loopback.
if [ -n "${A2A_BIND_HOST:-}" ]; then
  BIND_HOST="$A2A_BIND_HOST"
elif [ "$ADVERTISE" = "127.0.0.1" ]; then
  BIND_HOST="127.0.0.1"
else
  BIND_HOST="${BIND_IP:-0.0.0.0}"
fi

if [ "$IDENTITY_ONLY" = 1 ]; then
  printf 'a2a-bridge[7]{harness,name,id,bind,advertise,state,skills}:\n'
  printf '  "%s","%s","%s","%s","%s","%s","%s"\n' \
    "$HARNESS" "$NAME" "$ID" "$BIND_HOST" "$ADVERTISE" "$STATE_DIR" "$SKILLS"
  exit 0
fi

# ── a port, without a race and without a graveyard ───────────────────────────────
mkdir -p "$STATE_DIR" "$PORTS_DIR" 2>/dev/null || true

sweep_dead() {
  local d holder
  for d in "$PORTS_DIR"/*; do
    [ -d "$d" ] || continue
    holder="$(cat "$d/pid" 2>/dev/null || true)"
    # a reservation whose holder is gone, or which never wrote one, is not a reservation.
    if [ -z "$holder" ] || ! kill -0 "$holder" 2>/dev/null; then
      rm -rf "$d" 2>/dev/null || true
    fi
  done
}

free_port() {
  local p holder
  for i in $(seq 0 "$SPAN"); do
    p=$((BASE_PORT + i))
    ss -tlnH "sport = :$p" 2>/dev/null | grep -q . && continue
    if mkdir "$PORTS_DIR/$p" 2>/dev/null; then
      printf '%s' "$p"; return 0
    fi
    holder="$(cat "$PORTS_DIR/$p/pid" 2>/dev/null || true)"
    if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then
      rm -rf "$PORTS_DIR/$p" 2>/dev/null
      if mkdir "$PORTS_DIR/$p" 2>/dev/null; then printf '%s' "$p"; return 0; fi
    fi
  done
  return 1
}

sweep_dead
if [ "$DRY" = 1 ]; then
  PORT="$BASE_PORT"
else
  PORT="$(free_port)" || {
    printf 'a2a-bridge-session: no free port in %s..%s after sweeping dead claims\n' \
      "$BASE_PORT" "$((BASE_PORT + SPAN))" >&2
    exit 1
  }
  printf '%s' "$$" >"$PORTS_DIR/$PORT/pid" 2>/dev/null || true
  release() { rm -rf "$PORTS_DIR/$PORT" 2>/dev/null || true; }
  trap release EXIT INT TERM
fi

ARGV=("$A2AB" bridge \
  -name "$NAME" -id "$ID" \
  -bind "$BIND_HOST:$PORT" \
  -advertise-host "$ADVERTISE" \
  -directory "$DIRECTORY" \
  -model "$MODEL" -skills "$SKILLS" -state-dir "$STATE_DIR")

if [ "$DRY" = 1 ]; then
  printf '%s\n' "${ARGV[@]}"
  exit 0
fi

# no `exec`: the bridge must keep OUR stdio (it speaks MCP on it), and the trap must survive
# so the reservation is given back when the harness closes the pipe.
"${ARGV[@]}"
