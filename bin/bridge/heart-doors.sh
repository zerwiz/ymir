#!/usr/bin/env bash
# heart-doors.sh — a seat's road to the heart's record MCPs, held open over ssh.
#
# The heart's skills (Bölþorn), ticket (Skuld) and meeting (Snotra) doors listen on loopback only
# (docs/fixes/fleet/2026-11-12-the-fleet-doors-face-loopback-and-skuld-can-start.md), and the ward
# rates an MCP that answers a tailnet peer without a token as HIGH (2026-11-16). So a seat that is not
# the heart does not dial them across the network: it holds ONE ssh connection to the heart that
# forwards each door to this seat's loopback, on <heart port> + an offset. The MCP gateway
# (bin/bridge/mcp-gateway.sh) tries that forward first. ssh is the credential; no port opens.
#
#   heart-doors.sh status    what each door answers here, without changing anything
#   heart-doors.sh ensure    write and start the user unit (heart-doors.service); a clean skip on the heart
#   heart-doors.sh serve     the unit's ExecStart: one ssh connection in the foreground
#   heart-doors.sh down      stop the unit
#
# Env (one documented default each, RULES/07):
#   YMIR_HEART               the heart's ssh host (default: the `heart` the fleet registry names)
#   HEART_DOOR_PORTS         the heart's ports to forward     (default: "8319 8320 8321")
#   YMIR_HEART_DOOR_OFFSET   local port = heart port + this   (default: 10000; the gateway reads the same)
#
# Exit: 0 every door answers (or a clean skip) · 1 a door is silent · 2 usage or no heart.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for _w in "$SCRIPT_DIR/../vault/hoard-lib.sh"; do
  [ -r "$_w" ] && . "$_w"
done
unset _w

PORTS="${HEART_DOOR_PORTS:-8319 8320 8321}"
OFFSET="${YMIR_HEART_DOOR_OFFSET:-10000}"
UNIT="heart-doors.service"
UNIT_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/$UNIT"

HEART="${YMIR_HEART:-}"
if [ -z "$HEART" ] && command -v ymir_fleet_heart >/dev/null 2>&1; then ymir_fleet_heart HEART 2>/dev/null || true; fi
ME="$(hostname -s 2>/dev/null || hostname)"

say() { printf '%s\n' "$*"; }

need_heart() {
  [ -n "$HEART" ] && return 0
  say "heart-doors: no heart — set YMIR_HEART, or name one in the fleet registry" >&2
  exit 2
}

on_heart() { [ -n "$HEART" ] && [ "$HEART" = "$ME" ]; }

probe() { # <port> -> 0 when something accepts on 127.0.0.1:<port>
  { exec 3<>"/dev/tcp/127.0.0.1/$1"; } 2>/dev/null && { exec 3>&-; return 0; }
  return 1
}

forwards() { local p; for p in $PORTS; do printf -- '-L %s:127.0.0.1:%s ' "$((p + OFFSET))" "$p"; done; }

cmd_serve() {
  need_heart
  # shellcheck disable=SC2046 # the forwards are separate words on purpose
  exec ssh -N -o BatchMode=yes -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 -o ConnectTimeout=10 $(forwards) "$HEART"
}

cmd_status() {
  if on_heart; then say "heart-doors: skip — this seat is the heart; the gateway reaches its doors on loopback"; return 0; fi
  need_heart
  local p rc=0 unit
  unit="$(systemctl --user is-active "$UNIT" 2>/dev/null || true)"
  printf 'heart_doors[%s]{heart_port,here,state}:\n' "$HEART"
  for p in $PORTS; do
    if probe "$((p + OFFSET))"; then printf '  "%s","%s","answering"\n' "$p" "$((p + OFFSET))"
    else printf '  "%s","%s","silent"\n' "$p" "$((p + OFFSET))"; rc=1; fi
  done
  printf '  "unit","%s","%s"\n' "$UNIT" "${unit:-absent}"
  [ "$rc" = 0 ] || say "heart-doors: a door is silent — raise it: bin/bridge/heart-doors.sh ensure" >&2
  return "$rc"
}

cmd_ensure() {
  if on_heart; then say "heart-doors: skip — this seat is the heart"; return 0; fi
  need_heart
  local self; self="$(cd "$SCRIPT_DIR" && pwd)/heart-doors.sh"
  mkdir -p "$(dirname "$UNIT_FILE")"
  local want
  want="[Unit]
Description=Heart doors — this seat's ssh road to the heart's record MCPs (skills, tickets, meetings)
After=network-online.target

[Service]
Environment=YMIR_HEART=$HEART
Environment=HEART_DOOR_PORTS=$PORTS
Environment=YMIR_HEART_DOOR_OFFSET=$OFFSET
ExecStart=/usr/bin/env bash $self serve
Restart=always
RestartSec=15

[Install]
WantedBy=default.target
"
  if [ "$(cat "$UNIT_FILE" 2>/dev/null)" != "$want" ]; then
    printf '%s' "$want" >"$UNIT_FILE"
    systemctl --user daemon-reload
  fi
  systemctl --user enable "$UNIT" >/dev/null 2>&1 || true
  systemctl --user restart "$UNIT"
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    probe "$((${PORTS%% *} + OFFSET))" && break
    sleep 1
  done
  cmd_status
}

cmd_down() { systemctl --user stop "$UNIT" 2>/dev/null; say "heart-doors: stopped"; }

case "${1:-status}" in
  serve)  cmd_serve ;;
  status) cmd_status ;;
  ensure) cmd_ensure ;;
  down)   cmd_down ;;
  -h|--help|help) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) say "usage: heart-doors.sh status|ensure|serve|down" >&2; exit 2 ;;
esac
