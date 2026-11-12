#!/usr/bin/env bash
# desk-screen — the screens of the hall's computer, run INSIDE the desk container.
#
#   desk-screen init        start the default screen (:99) and keep the container alive
#   desk-screen start N     start screen :N (an Xvnc display with its own window manager)
#   desk-screen stop N      stop screen :N
#   desk-screen list        one line per running screen: "N WIDTHxHEIGHT RFBPORT"
#
# Every screen is an Xvnc display. Its RFB port is DESK_VNC_BASE + (N - 99), bound to loopback only,
# and it asks for the VNC password mounted at /run/desk-secret/vnc.pass. The X server listens on its
# unix socket inside the container only (no TCP, no abstract socket), so nothing on the host can draw
# on an agent's screen except through the VNC door.
set -u
BASE="${DESK_VNC_BASE:-5990}"
GEOMETRY="${DESK_GEOMETRY:-1280x800}"
SECRET=/run/desk-secret/vnc.pass
PASSWD=/root/.vnc/passwd
LOGS=/var/log/desk
mkdir -p "$LOGS" /root/.vnc

port_of() { echo $(( BASE + $1 - 99 )); }
running() { pgrep -f "^Xvnc :$1( |$)" >/dev/null 2>&1; }

password() {
  [ -s "$SECRET" ] || { echo "desk-screen: no VNC password at $SECRET" >&2; return 1; }
  vncpasswd -f < "$SECRET" > "$PASSWD" && chmod 600 "$PASSWD"
}

start() {
  local n="$1"
  case "$n" in ''|*[!0-9]*) echo "desk-screen: bad screen '$n'" >&2; return 2 ;; esac
  if running "$n"; then return 0; fi
  [ -s "$PASSWD" ] || password || return 1
  rm -f "/tmp/.X$n-lock" "/tmp/.X11-unix/X$n"
  Xvnc ":$n" -geometry "$GEOMETRY" -depth 24 -localhost -rfbport "$(port_of "$n")" \
    -SecurityTypes VncAuth -PasswordFile "$PASSWD" -AlwaysShared \
    -nolisten tcp -nolisten local -desktop "hall-$n" >"$LOGS/xvnc-$n.log" 2>&1 &
  for _ in $(seq 1 50); do [ -S "/tmp/.X11-unix/X$n" ] && break; sleep 0.1; done
  [ -S "/tmp/.X11-unix/X$n" ] || { echo "desk-screen: screen :$n did not start (see $LOGS/xvnc-$n.log)" >&2; return 1; }
  # A window manager, so windows can be maximized, raised and closed by the desk scripts.
  DISPLAY=":$n" dbus-launch --exit-with-session xfwm4 --compositor=off >"$LOGS/wm-$n.log" 2>&1 &
  echo "screen :$n on port $(port_of "$n")"
}

stop() {
  local n="$1"
  pkill -f "^Xvnc :$n( |$)" 2>/dev/null
  for pid in $(pgrep -x xfwm4); do
    { tr '\0' '\n' < "/proc/$pid/environ"; } 2>/dev/null | grep -qx "DISPLAY=:$n" && kill "$pid" 2>/dev/null
  done
  return 0
}

list() {
  for sock in /tmp/.X11-unix/X*; do
    [ -S "$sock" ] || continue
    local n="${sock##*/X}"
    running "$n" || continue
    local size; size="$(DISPLAY=":$n" xdpyinfo 2>/dev/null | awk '/dimensions:/{print $2; exit}')"
    echo "$n ${size:-$GEOMETRY} $(port_of "$n")"
  done
}

case "${1-}" in
  init)
    password || exit 1
    start 99 || exit 1
    trap 'for s in $(list | cut -d" " -f1); do stop "$s"; done; exit 0' TERM INT
    while :; do sleep 3600 & wait $!; done ;;
  start) start "${2-}" ;;
  stop) stop "${2-}" ;;
  list) list ;;
  *) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
