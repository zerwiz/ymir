#!/usr/bin/env bash
# syn-watch.sh — Sýn as a SERVICE: one supervision watcher per home, seated
# once and standing until it is stopped.
#
# The arm used to live and die with the harness session. When the session's lock
# owner went away the watcher exited `0` in silence ("retired"), so a live
# supervision read as dead and the Pi extension flapped through a day of blind
# turn ends and hand re-arms (2026-09-27). The watcher is now a service (plan 58,
# Phase 2): it outlives every session, keeps its own LEASE, IDLES when no session
# is seated instead of retiring, and is restarted by systemd (or by the thin
# client) when it dies.
#
#   syn-watch.sh status   # the truth: lease, heartbeat, session, mode; exit 1 on a gap
#   syn-watch.sh start    # seat the arm service (the systemd unit, else a detached daemon)
#   syn-watch.sh stop     # bring it down (both shapes)
#   syn-watch.sh run      # the daemon loop in the foreground (the unit's ExecStart)
#   syn-watch.sh run --emit  # the loop that PRINTS the raised line and ends (the
#                          # pre-service shape, for a probe: BROKK_WATCH_INLINE=1)
#   syn-watch.sh restart  # stop, then start
#
# The state, all under the resolved state dir (the same dir the harness readers,
# the turn-end guard, and bin/syn-watch-arm.sh use):
#
#   .watch.heartbeat    epoch seconds, touched every cycle (the liveness door)
#   .supervision-armed  the armed marker the turn-end guard reads (inert without it)
#   .arm.lease          pid=<pid> starttime=<st> gen=<n> mode=<systemd|daemon>
#                       session=<pid|none> heartbeat=<epoch> state=<dir>
#   .arm.event          the raised-but-undelivered actionable line (one line)
#   .arm.wake           append-only journal of every line this arm has raised
#
# The grammar is the contract: the arm raises `signal:` / `stale:` / `check:` /
# `heartbeat:` lines and nothing else; bin/syn-watch-arm.sh relays them to the
# harness unchanged. This file writes no line to stdout except those.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BROKK_HOME="${BROKK_HOME:-$ROOT}"

# The arm's state is the OPERATOR's state, resolved here exactly as
# bin/syn-watch-arm.sh and bin/syn-turnend-guard.sh resolve it — one dir, one
# heartbeat, one wake queue (Rule 04: never the code tree).
# An EXPLICIT override means a seat (an Eindri-home's private state) or a test:
# that state is served by a detached daemon, never by the machine's one unit.
_SYN_STATE_GIVEN="${BROKK_STATE_OVERRIDE:-}"
if [ -z "${BROKK_STATE_OVERRIDE:-}" ]; then
  if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
    for _c in "$SCRIPT_DIR/hoard-lib.sh" "$(dirname "$SCRIPT_DIR")/bin/hoard-lib.sh"; do
      [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
    done
    unset _c
  fi
  hoard_state_dir _HS 2>/dev/null && BROKK_STATE_OVERRIDE="$_HS"
  unset _HS
fi
STATE="${BROKK_STATE_OVERRIDE:-$BROKK_HOME/state}"

# shellcheck source=bin/gleipnir-lock-lib.sh
if [ -z "${GLEIPNIR_LOCK_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/gleipnir-lock-lib.sh" "$(dirname "$SCRIPT_DIR")/bin/gleipnir-lock-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; GLEIPNIR_LOCK_LIB_LOADED=1; break; }
  done
  unset _c
fi

VERSION="1.0.0"
POLL_SECONDS="${BROKK_WATCH_POLL_SECONDS:-5}"
HEARTBEAT_STALE_SECONDS="${BROKK_WATCH_HEARTBEAT_STALE_SECONDS:-60}"
UNIT_NAME="${SYN_WATCH_UNIT:-ymir-syn-watch.service}"
DAEMON_GRACE_SECONDS="${BROKK_WATCH_DAEMON_GRACE_SECONDS:-15}"

LEASE="$STATE/.arm.lease"
EVENT="$STATE/.arm.event"
WAKE="$STATE/.arm.wake"
HEARTBEAT="$STATE/.watch.heartbeat"
ARMED="$STATE/.supervision-armed"

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; esac

say_err() { printf 'syn-watch: %s\n' "$*" >&2; }
now() { date -u +%s; }

# ── the lease ───────────────────────────────────────────────────────────────
lease_field() {  # <key> [file] → value, or empty
  local key="${1-}" file="${2:-$LEASE}"
  [ -r "$file" ] || return 0
  awk -v k="$key=" '{
    for (i = 1; i <= NF; i++) if (index($i, k) == 1) { print substr($i, length(k) + 1); exit }
  }' "$file" 2>/dev/null || true
}

lease_read() {  # sets LEASE_PID LEASE_ST LEASE_GEN LEASE_MODE LEASE_SESSION LEASE_STATE
  LEASE_PID="$(lease_field pid)"; LEASE_ST="$(lease_field starttime)"
  LEASE_GEN="$(lease_field gen)"; LEASE_MODE="$(lease_field mode)"
  LEASE_SESSION="$(lease_field session)"; LEASE_STATE="$(lease_field state)"
}

lease_alive() {  # exit 0 iff a live arm owns THIS state
  lease_read
  case "${LEASE_PID:-}" in ''|*[!0-9]*) return 1 ;; esac
  [ "${LEASE_STATE:-}" = "$STATE" ] || return 1
  if command -v gleipnir_pid_alive >/dev/null 2>&1; then
    gleipnir_pid_alive "$LEASE_PID" "${LEASE_ST:-}" || return 1
  else
    kill -0 "$LEASE_PID" 2>/dev/null || return 1
  fi
  return 0
}

heartbeat_age() {
  local beat
  [ -r "$HEARTBEAT" ] || { printf '%s' '-1'; return 0; }
  beat="$(tr -d '[:space:]' <"$HEARTBEAT" 2>/dev/null || true)"
  case "$beat" in ''|*[!0-9]*) printf '%s' '-1'; return 0 ;; esac
  printf '%s' "$(( $(now) - beat ))"
}

session_owner() {  # the live session that holds this home's helm, or "none"
  local owner=""
  if command -v gleipnir_lock_owner >/dev/null 2>&1; then
    gleipnir_lock_owner _lo 2>/dev/null; owner="${_lo:-}"
  fi
  case "$owner" in
    ''|*[!0-9]*) printf '%s' 'none'; return 0 ;;
  esac
  if command -v gleipnir_pid_alive >/dev/null 2>&1; then
    gleipnir_pid_alive "$owner" || { printf '%s' 'none'; return 0; }
  else
    kill -0 "$owner" 2>/dev/null || { printf '%s' 'none'; return 0; }
  fi
  printf '%s' "$owner"
}

# ── the daemon (the one loop) ───────────────────────────────────────────────
write_lease() {  # <mode> <session>
  local mode="$1" sess="$2" st="" gen="" tmp
  gen="$(cat "$STATE/.arm.gen" 2>/dev/null || true)"
  case "$gen" in ''|*[!0-9]*) gen=1 ;; esac
  if command -v gleipnir_proc_starttime >/dev/null 2>&1; then
    gleipnir_proc_starttime "$$" st 2>/dev/null || st=""
  fi
  tmp="$LEASE.$$"
  printf 'pid=%s starttime=%s gen=%s mode=%s session=%s heartbeat=%s state=%s\n' \
    "$$" "${st:-0}" "$gen" "$mode" "$sess" "$(now)" "$STATE" >"$tmp" 2>/dev/null || return 1
  mv -f "$tmp" "$LEASE" 2>/dev/null || return 1
}

release_lease() {
  lease_read
  [ "${LEASE_PID:-}" = "$$" ] && rm -f "$LEASE" 2>/dev/null || true
}

raise_event() {  # prints one actionable line, or nothing
  local h prev sig check
  if [ -s "$STATE/.wake-queue" ]; then
    # ONE signal per DISTINCT queue content (the 2026-09-22 flood brake): an
    # unconsumed queue must never re-inject on every poll. A new wake (changed
    # content) raises exactly one new line; an unchanged queue stays silent until
    # the session drains it (bin/saga-wake-drain.sh) or the content changes.
    h="$(md5sum < "$STATE/.wake-queue" | awk '{print $1}')"
    prev="$(cat "$STATE/.wake-last-hash" 2>/dev/null || true)"
    if [ "$prev" != "$h" ]; then
      printf '%s' "$h" > "$STATE/.wake-last-hash"
      printf 'signal: wake queue\n'
      return 0
    fi
    # An UNCHANGED, unconsumed queue was already raised once. Stay silent and
    # KEEP WATCHING — never exit here. A bare return made the watcher leave
    # without raising anything, and the harness read the close as "ended without
    # an actionable reason", retried five times, and flapped (2026-09-23).
  fi
  sig="$(find "$STATE" -maxdepth 1 -name '*.signal' -print -quit 2>/dev/null || true)"
  if [ -n "$sig" ]; then
    rm -f "$sig"
    printf 'signal: %s\n' "$(basename "$sig" .signal)"
    return 0
  fi
  check="$(find "$STATE" -maxdepth 1 -name '*.check' -print -quit 2>/dev/null || true)"
  if [ -n "$check" ]; then
    rm -f "$check"
    printf 'check: %s\n' "$(basename "$check" .check)"
    return 0
  fi
  if [ -f "$STATE/.watcher-stop" ]; then
    rm -f "$STATE/.watcher-stop"
    printf 'stale: watcher stopped by operator\n'
    return 0
  fi
  return 1
}

publish_event() {  # <line> — the delivery slot + the append-only journal
  [ -s "$EVENT" ] && return 0        # an undelivered line is not overwritten
  printf '%s\n' "$1" >"$EVENT.tmp.$$" 2>/dev/null && mv -f "$EVENT.tmp.$$" "$EVENT" 2>/dev/null || true
  printf '%s\n' "$1" >>"$WAKE" 2>/dev/null || true
}

run_daemon() {
  local emit="${1:-0}"
  local mode="${SYN_WATCH_MODE:-daemon}" session="" event="" gen=""
  mkdir -p "$STATE" 2>/dev/null || { say_err "cannot create state dir $STATE"; exit 1; }

  if lease_alive && [ "$LEASE_PID" != "$$" ]; then
    say_err "refusing — an arm for $STATE is already up (pid $LEASE_PID)"
    exit 0
  fi

  gen="$(cat "$STATE/.arm.gen" 2>/dev/null || true)"
  case "$gen" in ''|*[!0-9]*) gen=0 ;; esac
  gen=$((gen + 1))
  printf '%s\n' "$gen" >"$STATE/.arm.gen" 2>/dev/null || true

  trap 'release_lease; exit 0' TERM INT
  write_lease "$mode" "none" || { say_err "cannot write lease $LEASE"; exit 1; }
  : >"$ARMED" 2>/dev/null || true
  : >"$HEARTBEAT" 2>/dev/null || true
  say_err "arm up pid=$$ gen=$gen mode=$mode state=$STATE"

  while :; do
    date -u +%s >"$HEARTBEAT" 2>/dev/null || true
    [ -f "$ARMED" ] || : >"$ARMED" 2>/dev/null || true
    # IDLE-NOT-DEAD: a dead or absent session owner is recorded, never a reason
    # to exit. The arm stands for the next session; its wake queue is durable and
    # the session-start digest drains what was raised while none was seated.
    session="$(session_owner)"
    write_lease "$mode" "$session"
    # THE MID-SESSION SWEEP. The Eindri handoff failsafe turns a filed
    # report/question into a wake; run it every cycle so a report filed while the
    # session runs fills the queue within seconds instead of waiting for the next
    # session start (2026-09-23).
    if [ -x "$SCRIPT_DIR/eindri-handoff.sh" ]; then
      BROKK_STATE_OVERRIDE="$STATE" "$SCRIPT_DIR/eindri-handoff.sh" sweep >/dev/null 2>&1 || true
    fi
    if event="$(raise_event)"; then
      if [ "$emit" = 1 ]; then
        # The probe/legacy shape: the raised line goes to STDOUT and the cycle
        # ends, exactly as the pre-service watch loop did — nothing is left in the
        # delivery slot for a later client to re-deliver.
        printf '%s\n' "$event"
        printf '%s\n' "$event" >>"$WAKE" 2>/dev/null || true
        release_lease
        exit 0
      fi
      publish_event "$event"
      say_err "raised: $event"
    fi
    sleep "$POLL_SECONDS"
  done
}

# ── starting / stopping ─────────────────────────────────────────────────────
have_systemd() {
  command -v systemctl >/dev/null 2>&1 || return 1
  systemctl --user show --property=Version >/dev/null 2>&1
}

unit_state() {  # the unit's ActiveState (or "absent" when no such unit)
  have_systemd || { printf '%s' 'nosystemd'; return 0; }
  local s
  s="$(systemctl --user show -p LoadState --value "$UNIT_NAME" 2>/dev/null || true)"
  if [ "$s" = "not-found" ] || [ -z "$s" ]; then printf '%s' 'absent'; return 0; fi
  s="$(systemctl --user show -p ActiveState --value "$UNIT_NAME" 2>/dev/null || true)"
  printf '%s' "${s:-absent}"
}

wait_lease() {  # <tenths of a second> — exit 0 once a live arm holds OUR state
  local waited=0 limit="${1:-20}"
  while [ "$waited" -lt "$limit" ]; do
    lease_alive && return 0
    sleep 0.5
    waited=$((waited + 1))
  done
  return 1
}

start_detached() {
  # A detached daemon is still a SERVICE: it outlives the session, keeps its own
  # lease, and the thin client restarts it when it is gone. This is the shape for
  # a state the one unit does not serve (a seat's private state, a test's).
  mkdir -p "$STATE" 2>/dev/null || true
  SYN_WATCH_MODE=daemon setsid "$SCRIPT_DIR/syn-watch.sh" run >>"$STATE/.arm.log" 2>&1 </dev/null &
  say_err "arm seated as a detached daemon for $STATE"
}

start_service() {  # seat the arm (the unit first), then wait for a live lease
  # The machine's ONE unit serves the operator's own state. A seat's private
  # state (an explicit override) is never handed to it: that would make one seat's
  # arm the machine's, and two seats would fight over the unit.
  if have_systemd && [ -z "$_SYN_STATE_GIVEN" ]; then
    # ONE renderer: bin/fleet-ensure.sh owns the template substitution (and the
    # refusal to seat a unit that names a disposable worktree path) — this door
    # only asks it to seat this one unit.
    if [ -x "$SCRIPT_DIR/fleet-ensure.sh" ]; then
      "$SCRIPT_DIR/fleet-ensure.sh" unit syn-watch >/dev/null 2>&1 || \
        say_err "could not materialize $UNIT_NAME (bin/fleet-ensure.sh unit syn-watch)"
    fi
    if systemctl --user daemon-reload >/dev/null 2>&1 && \
       systemctl --user enable --now "$UNIT_NAME" >/dev/null 2>&1; then
      if wait_lease 6; then return 0; fi
      say_err "$UNIT_NAME is up but took no lease for $STATE — seating a detached arm"
    else
      say_err "$UNIT_NAME could not be started (systemctl --user enable --now $UNIT_NAME)"
    fi
  fi
  start_detached
  wait_lease 20 || { say_err "the arm took no lease for $STATE within 10s"; return 1; }
  return 0
}

stop_service() {
  local stopped=0
  if have_systemd; then
    if systemctl --user is-active --quiet "$UNIT_NAME" 2>/dev/null; then
      systemctl --user stop "$UNIT_NAME" >/dev/null 2>&1 && stopped=1
    fi
  fi
  # A detached daemon is not systemd's: take it by its own lease.
  if lease_alive; then
    kill "$LEASE_PID" 2>/dev/null || true
    stopped=1
  fi
  local waited=0
  while [ "$waited" -lt 20 ]; do
    lease_alive || break
    sleep 0.5
    waited=$((waited + 1))
  done
  lease_alive && { say_err "the arm still holds its lease after the stop"; return 1; }
  [ "$stopped" = 1 ] && say_err "arm stopped"
  return 0
}

# ── status ──────────────────────────────────────────────────────────────────
status_state() {  # prints the state word
  local age
  lease_alive || { printf '%s' 'down'; return 0; }
  age="$(heartbeat_age)"
  if [ "${age#-}" = "$age" ] && [ "$age" -gt "$HEARTBEAT_STALE_SECONDS" ]; then
    printf '%s' 'stale'; return 0
  fi
  [ -f "$ARMED" ] || { printf '%s' 'stale'; return 0; }
  if [ "${LEASE_SESSION:-none}" = "none" ]; then printf '%s' 'idle'; return 0; fi
  printf '%s' 'up'
}

status_row() {  # the TOON detail row
  local st mode unit pid age sess armed
  st="$(status_state)"
  if lease_alive; then
    mode="${LEASE_MODE:-unknown}"; pid="${LEASE_PID:-}"; sess="${LEASE_SESSION:-none}"
  else
    mode="none"; pid=""; sess="$(session_owner)"
  fi
  unit="$(unit_state)"
  age="$(heartbeat_age)"
  [ -f "$ARMED" ] && armed="yes" || armed="no"
  printf '  "%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' \
    "$st" "$mode" "$unit" "${pid:-none}" "$age" "$HEARTBEAT_STALE_SECONDS" "$sess" "$armed" "$STATE"
}

status() {
  local st rc=0
  st="$(status_state)"
  [ "$st" = "up" ] || [ "$st" = "idle" ] || rc=1
  if [ "${1-}" = "--detail" ]; then
    printf 'arm=%s mode=%s unit=%s pid=%s heartbeat=%ss session=%s\n' \
      "$st" "$(lease_alive && printf '%s' "${LEASE_MODE:-unknown}" || printf 'none')" \
      "$(unit_state)" "$(lease_alive && printf '%s' "${LEASE_PID:-none}" || printf 'none')" \
      "$(heartbeat_age)" "$(session_owner)"
    return "$rc"
  fi
  printf 'syn-watch[1]{state,mode,unit,pid,heartbeat_age,stale_seconds,session,armed,state_dir}:\n'
  status_row
  if [ "$rc" != 0 ]; then
    case "$st" in
      down)  printf 'syn-watch: the arm is DOWN — no live lease for %s\n' "$STATE" >&2
             printf 'remedy: bin/syn-watch.sh start\n' >&2 ;;
      stale) printf 'syn-watch: the arm is STALE — heartbeat age %ss exceeds %ss\n' "$(heartbeat_age)" "$HEARTBEAT_STALE_SECONDS" >&2
             printf 'remedy: bin/syn-watch.sh restart\n' >&2 ;;
    esac
  fi
  return "$rc"
}

# ── the door ────────────────────────────────────────────────────────────────
case "${1-}" in
  -h|--help|"")
    sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  run)
    shift || true
    emit=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --emit) emit=1 ;;
        --foreground) ;;   # the unit's ExecStart names no flag; kept for callers
        *) say_err "unknown flag $1 to run"; exit 2 ;;
      esac
      shift
    done
    run_daemon "$emit"
    ;;
  status)  shift || true; status "${1-}" ;;
  start)   shift || true; start_service ;;
  stop)    shift || true; stop_service ;;
  restart) shift || true; stop_service || true; start_service ;;
  *) say_err "unknown command ${1-} (status|start|stop|restart|run)"; exit 2 ;;
esac
