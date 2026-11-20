#!/usr/bin/env bash
# host-watch.sh — the watcher a hand can actually have.
#
# The fault this answers (2026-10-21): `security-audit.sh` reported
# "nothing watches this host — no fail2ban/crowdsec/lynis/aide/osquery/falco",
# and on Android every one of those is absent for a reason: no root, no systemd,
# no inotify budget. The honest question is not "is fail2ban installed" but
# "does anything look at this host on a cycle and leave a record".
#
# So this is that look:
#
#   listeners   every TCP port bound, and whether it is bound to the world
#   doors       the hashes of the files that decide who may enter (authorized_keys,
#               sshd_config and its drop-ins)
#   attempts    failed SSH authentications, when a log source exists; when none
#               does it SAY so rather than report zero
#
# It records; it does not ban. Closing a door is a decision (bin/ward/harden.sh),
# and this ward reports (Rule 24).
#
#   host-watch.sh run        take one look, append to the log, refresh the heartbeat
#   host-watch.sh status     exit 0 when the last look is younger than MAX_AGE_H hours
#
# Exit: 0 fine · 1 stale/never ran · 2 usage. Never fails because a source is missing.

set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _w in "$SCRIPT_DIR/../vault/hoard-lib.sh" "$ROOT/bin/vault/hoard-lib.sh"; do
    [ -r "$_w" ] && { . "$_w"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _w
fi
HOME_DIR=""
if [ -n "${YMIR_HOME:-}" ]; then HOME_DIR="$YMIR_HOME"
elif command -v ymir_home_root >/dev/null 2>&1; then ymir_home_root HOME_DIR
fi
[ -n "$HOME_DIR" ] || HOME_DIR="${HOME}"

STATE_DIR="${YMIR_STATE_DIR:-$HOME_DIR/state}"
WARD_DIR="$STATE_DIR/ward"
LOG="$WARD_DIR/host-watch.log"
BEAT="$WARD_DIR/host-watch.last"
MAX_AGE_H="${HOST_WATCH_MAX_AGE_H:-26}"

# The sshd config: Termux keeps its own prefix, a server keeps /etc.
sshd_config_file() {
  local c
  for c in "${SSHD_CONFIG:-}" "${PREFIX:-}/etc/ssh/sshd_config" /etc/ssh/sshd_config; do
    [ -n "$c" ] && [ -r "$c" ] && { printf '%s\n' "$c"; return 0; }
  done
  return 1
}

listeners() {
  local out=""
  if command -v ss >/dev/null 2>&1; then out="$(ss -ltn 2>/dev/null)"; fi
  # Android's `ss` is denied netlink and Termux's `netstat` refuses AF_INET, so an
  # empty table is NOT "nothing is listening" — it is "this host will not say".
  # Say that. A false zero is how an open door stays unlooked at.
  if [ -z "$(printf '%s\n' "$out" | awk '$4 ~ /:[0-9]+$/ {print; exit}')" ]; then
    if command -v netstat >/dev/null 2>&1; then
      out="$(netstat -ltn 2>/dev/null)"
    fi
  fi
  if [ -z "$(printf '%s\n' "$out" | awk '$4 ~ /:[0-9]+$/ {print; exit}')" ]; then
    printf '(listeners unmeasured — the kernel table is denied to this app: netlink and /proc/net/tcp both refuse)\n'
    return 0
  fi
  printf '%s\n' "$out"
}

world_bound() {
  local rows
  rows="$(listeners | awk '$4 ~ /:[0-9]+$/')"
  [ -n "$rows" ] || { printf 'unmeasured\n'; return 0; }
  printf '%s\n' "$rows" | awk '$4 ~ /^(0\.0\.0\.0|\*|\[::\]):/ || $4 ~ /^:::?[0-9]+$/ {print $4}' | sort -u
}

door_hashes() {
  local f
  { command -v sha256sum >/dev/null 2>&1 && H=sha256sum; } || H="shasum -a 256"
  for f in "$HOME/.ssh/authorized_keys" "$(sshd_config_file 2>/dev/null)"; do
    [ -n "$f" ] && [ -r "$f" ] || continue
    printf '%s  %s\n' "$($H "$f" 2>/dev/null | awk '{print $1}')" "$f"
  done
  local d
  d="$(dirname "$(sshd_config_file 2>/dev/null)" 2>/dev/null)/sshd_config.d"
  [ -d "$d" ] && for f in "$d"/*.conf; do
    [ -r "$f" ] || continue
    printf '%s  %s\n' "$($H "$f" 2>/dev/null | awk '{print $1}')" "$f"
  done
  return 0
}

attempts() {
  local src=""
  if command -v logcat >/dev/null 2>&1; then
    src="$(logcat -d -s sshd 2>/dev/null | grep -ci 'failed\|invalid user' 2>/dev/null || true)"
    [ -n "$src" ] && { printf 'failed authentications (logcat sshd): %s\n' "$src"; return 0; }
  fi
  local logs="$PREFIX/var/log/sshd.log /var/log/auth.log"
  for f in $logs; do
    [ -r "$f" ] || continue
    printf 'failed authentications (%s): %s\n' "$f" "$(grep -ci 'failed\|invalid user' "$f" 2>/dev/null || echo 0)"
    return 0
  done
  printf 'failed authentications: unmeasured — no sshd log source on this host\n'
}

run_once() {
  mkdir -p "$WARD_DIR" 2>/dev/null || return 1
  local stamp w
  stamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  {
    printf '\n### %s · host-watch %s\n' "$stamp" "$VERSION"
    printf 'host: %s\n' "$(uname -n 2>/dev/null || echo unknown)"
    printf 'world-bound ports: %s\n' "$(world_bound | tr '\n' ' ' | sed 's/ $//')"
    printf 'all listeners:\n'
    listeners | sed 's/^/  /'
    printf 'door hashes:\n'
    door_hashes | sed 's/^/  /'
    printf '%s\n' "$(attempts)"
  } >>"$LOG" 2>/dev/null || return 1
  printf '%s\n' "$stamp" >"$BEAT" 2>/dev/null || return 1
  printf 'host-watch: recorded %s\n' "$LOG"
}

status() {
  [ -r "$BEAT" ] || { printf 'host-watch: never ran\n' >&2; return 1; }
  local beat age
  beat="$(head -n1 "$BEAT" 2>/dev/null)"
  age=$(( ( $(date -u +%s) - $(date -u -d "$beat" +%s 2>/dev/null || echo 0) ) / 3600 ))
  if [ "$age" -lt 0 ]; then age=0; fi
  if [ "$age" -le "$MAX_AGE_H" ]; then
    printf 'host-watch: last look %sh ago\n' "$age"; return 0
  fi
  printf 'host-watch: last look %sh ago (stale, > %sh)\n' "$age" "$MAX_AGE_H" >&2
  return 1
}

case "${1:-}" in
  run)    run_once ;;
  status) status ;;
  -v|--version) printf '%s\n' "$VERSION" ;;
  -h|--help|"") sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) printf 'usage: host-watch.sh run|status\n' >&2; exit 2 ;;
esac
