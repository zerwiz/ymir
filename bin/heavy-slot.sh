#!/usr/bin/env bash
# heavy-slot.sh — ONE heavy job at a time on this machine, and a record of who holds it.
#
# WHY (plan 002 §6.1, measured on the heart 2026-11-17). `updating.md`'s first law was "one heavy
# job at a time — `bin/heavy-slot.sh take` before a build", and the command did not exist anywhere
# in the tree. So a gate suite, a release build and an errand's test run could all proceed at once
# on a box with 11 GB of RAM whose swap was already 3.0 of 4.0 GB. At 07:20:59 the kernel fired.
# A law with no mechanism is a hope; this is the mechanism.
#
# WHAT IT IS, in one sentence: an exclusive lock, machine-wide, that carries the holder's pid and
# the instant it started, so a second heavy job WAITS AND SAYS WHOSE JOB IT WAITS FOR instead of
# running beside the first.
#
#   bin/heavy-slot.sh run -- <command…>     wait for the slot, then run the command under it
#   bin/heavy-slot.sh status                who holds it (or that it is free), and for how long
#
# THE THREE THINGS THIS DOOR MUST NEVER DO:
#   · it never leaves a lock behind: a holder that dies is REAPED, not waited on forever. The
#     record carries the process START TIME beside the pid, because a pid is reused — a lock
#     whose pid now belongs to another process is stale, and reaping it is the safe reading.
#   · it never runs a second heavy job beside the first: `run` holds the slot for the whole life
#     of the command, and the hold is INHERITED by that command's children (so a proof run that
#     itself calls a heavy door nests instead of deadlocking on its own lock).
#   · it never releases someone else's lock: the release is guarded by pid + start time, and the
#     trap fires on EXIT and on INT/TERM/HUP/QUIT alike.
#
# Configuration (Rule 07 — one documented default each):
#   YMIR_HEAVY_SLOT   the lock file  (default ${XDG_STATE_HOME:-$HOME/.local/state}/ymir/heavy-slot.lock)
#   YMIR_HEAVY_SLOT_HELD   set to 1 by this door in the child; a nested call runs straight through
set -uo pipefail

HEAVY_SLOT_VERSION="1.0.0"

say()  { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }
die()  { warn "error: $*"; exit 1; }

usage() {
  cat <<'EOF'
heavy-slot — one heavy job at a time on this machine.

  bin/heavy-slot.sh run [--name LABEL] [--no-wait] [--wait-max SECONDS] -- <command…>
  bin/heavy-slot.sh status [--json]
  bin/heavy-slot.sh --help | --version

`run` takes the machine's heavy lock, prints whose job it waits for when the slot is held,
runs the command with the hold inherited, and releases on exit — including on a signal.

  --name LABEL      what to call this job in the record (default: the command's own name)
  --no-wait         do not wait: refuse (exit 3) and name the holder
  --wait-max N      give up waiting after N seconds, naming the holder (exit 3)

Exit: the command's own code · 2 usage · 3 refused (held and not waited for).
EOF
}

# ── where the lock lives ──────────────────────────────────────────────────────
# Machine-wide and per-user on purpose: two worktrees, two errands and a systemd unit are
# the same machine, and the fault this door exists to stop happened exactly between them.
slot_path() {
  printf '%s' "${YMIR_HEAVY_SLOT:-${XDG_STATE_HOME:-$HOME/.local/state}/ymir/heavy-slot.lock}"
}

slot_field() {  # <file> <key> → the value, empty when absent
  [ -r "${1-}" ] || return 0
  sed -n "s/^$2=//p" "$1" 2>/dev/null | head -1
}

# A pid is not an identity: the kernel reuses them. The process's start time — field 22 of
# /proc/<pid>/stat, counted after the comm — is the second half of the name.
pid_starttime() {  # <pid> → the start time, or empty where /proc cannot answer
  local pid="${1-}" f="/proc/${1-}/stat"
  [ -n "$pid" ] && [ -r "$f" ] || return 0
  sed 's/.*) //' "$f" 2>/dev/null | awk '{print $20}'
}

pid_alive() {  # <pid> <starttime> → 0 when that exact process still runs
  local pid="${1-}" want="${2-}" now=""
  [ -n "$pid" ] || return 1
  if [ -d /proc ]; then
    [ -d "/proc/$pid" ] || return 1
    now="$(pid_starttime "$pid")"
    # No start time in the record (an older lock, or a platform without /proc): pid alone.
    [ -n "$want" ] && [ -n "$now" ] && [ "$want" != "$now" ] && return 1
    return 0
  fi
  kill -0 "$pid" 2>/dev/null
}

now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }

since_of() {  # <pid> → how long that process has run, e.g. "12m"
  local et=""
  et="$(ps -o etime= -p "${1-}" 2>/dev/null | tr -d ' ')"
  printf '%s' "${et:-unknown}"
}

holder_row() {  # <lock file> — the holder, one row, or nothing when the lock is not a record
  local lock="$1" pid started starttime host name cmd
  pid="$(slot_field "$lock" pid)"
  [ -n "$pid" ] || return 1
  started="$(slot_field "$lock" started)"
  starttime="$(slot_field "$lock" starttime)"
  host="$(slot_field "$lock" host)"
  name="$(slot_field "$lock" name)"
  cmd="$(slot_field "$lock" cmd)"
  printf '  "%s","%s","%s","%s","%s","%s","%s"\n' \
    "$pid" "${started:-unknown}" "${starttime:-unknown}" "${host:-unknown}" \
    "${name:-unnamed}" "${cmd:-unknown}" "$(since_of "$pid")"
}

# ── reap: a lock whose holder is gone is not a lock ───────────────────────────
# The rename is the race breaker: two waiters that both judge the lock stale both try to move
# it, and only one move can succeed. Nothing is ever removed by name while a live holder may
# own it, and the release path re-checks pid + start time before it deletes anything.
slot_reap_if_stale() {
  local lock pid starttime aside
  lock="$(slot_path)"
  [ -e "$lock" ] || return 0
  pid="$(slot_field "$lock" pid)"
  starttime="$(slot_field "$lock" starttime)"
  if [ -n "$pid" ] && pid_alive "$pid" "$starttime"; then
    return 1                      # a live holder: the slot is genuinely held
  fi
  aside="${lock}.stale.$$"
  if mv -- "$lock" "$aside" 2>/dev/null; then
    rm -f -- "$aside"
    return 0
  fi
  # Someone else reaped or claimed it in the same instant; the next attempt will see the truth.
  return 0
}

# ── take: an exclusive create, one link(2) ────────────────────────────────────
# The record is written in full under a temporary name and then LINKED into place. `ln` fails
# when the target exists, which is the atomicity: no reader ever sees an empty lock, and no two
# takers can both win.
slot_take() {  # <name> <command…> → 0 taken · 1 held
  local lock tmp name="$1"; shift
  lock="$(slot_path)"
  mkdir -p -- "$(dirname "$lock")" 2>/dev/null || die "cannot create $(dirname "$lock")"
  tmp="${lock}.tmp.$$"
  {
    printf 'pid=%s\n' "$$"
    printf 'started=%s\n' "$(now_iso)"
    printf 'starttime=%s\n' "$(pid_starttime "$$")"
    printf 'host=%s\n' "$(hostname -s 2>/dev/null || hostname 2>/dev/null || printf 'unknown')"
    printf 'name=%s\n' "$name"
    printf 'cmd=%s\n' "$*"
  } >"$tmp" 2>/dev/null || { rm -f -- "$tmp"; die "cannot write $tmp"; }
  if ln -- "$tmp" "$lock" 2>/dev/null; then
    rm -f -- "$tmp"
    return 0
  fi
  rm -f -- "$tmp"
  return 1
}

slot_held_by_me() {  # 0 when this process is the recorded holder
  local lock pid starttime
  lock="$(slot_path)"
  [ -r "$lock" ] || return 1
  pid="$(slot_field "$lock" pid)"
  starttime="$(slot_field "$lock" starttime)"
  [ "$pid" = "$$" ] || return 1
  [ -z "$starttime" ] || [ "$starttime" = "$(pid_starttime "$$")" ]
}

slot_release() {
  local lock
  lock="$(slot_path)"
  slot_held_by_me || return 0        # never someone else's lock, never a lock already gone
  rm -f -- "$lock"
}

slot_say_holder() {  # <prefix> — name the job being waited for, in the house's own row
  local lock; lock="$(slot_path)"
  say "${1},held"
  say "holder[1]{pid,started,starttime,host,name,cmd,running}:"
  holder_row "$lock" || say '  "unknown","unknown","unknown","unknown","unknown","unknown","unknown"'
}

# ── status ────────────────────────────────────────────────────────────────────
slot_status() {
  local lock state="free"
  lock="$(slot_path)"
  if [ -e "$lock" ]; then
    slot_reap_if_stale || true
    [ -e "$lock" ] && state="held"
  fi
  if [ "${JSON_FLAG:-0}" = 1 ]; then
    printf '{"lock":"%s","state":"%s"}\n' "$lock" "$state"
    [ "$state" = held ] || exit 0
    exit 3
  fi
  say "slot[1]{lock,state}:"
  say "  \"$lock\",\"$state\""
  if [ "$state" = "held" ]; then
    say "holder[1]{pid,started,starttime,host,name,cmd,running}:"
    holder_row "$lock" || say '  "unknown","unknown","unknown","unknown","unknown","unknown","unknown"'
    exit 3
  fi
  exit 0
}

# ── argument parsing ─────────────────────────────────────────────────────────
[ $# -gt 0 ] || { usage >&2; exit 2; }
VERB="$1"; shift
JSON_FLAG=0
case "$VERB" in
  -h|--help) usage; exit 0 ;;
  -v|-V|--version) printf 'heavy-slot %s\n' "$HEAVY_SLOT_VERSION"; exit 0 ;;
  status) ;;
  run) ;;
  *) warn "unknown verb $VERB"; usage >&2; exit 2 ;;
esac

NAME=""; NO_WAIT=0; WAIT_MAX=""; CMD=()
while [ $# -gt 0 ]; do
  case "${1-}" in
    --name)      NAME="${2-}"; shift 2 ;;
    --no-wait)   NO_WAIT=1; shift ;;
    --wait-max)  WAIT_MAX="${2-}"; shift 2 ;;
    --json)      JSON_FLAG=1; shift ;;
    --)          shift; CMD=("$@"); break ;;
    -h|--help)   usage; exit 0 ;;
    -*)          warn "unknown flag $1"; usage >&2; exit 2 ;;
    *)           CMD=("$@"); break ;;
  esac
done

if [ "$VERB" = "status" ]; then
  slot_status
fi

[ "${#CMD[@]}" -gt 0 ] || { warn "run needs a command: bin/heavy-slot.sh run -- <command…>"; exit 2; }
[ -n "$NAME" ] || NAME="$(basename "${CMD[0]}")"
case "${WAIT_MAX:-0}" in ''|*[!0-9]*) warn "--wait-max needs a number of seconds"; exit 2 ;; esac

# ── inherited: a heavy job inside a heavy job is not a second job ────────────
if [ "${YMIR_HEAVY_SLOT_HELD:-0}" = 1 ]; then
  say "SLOT,nested,$NAME,runs under the slot already held by pid ${YMIR_HEAVY_SLOT_PID:-unknown}"
  export YMIR_HEAVY_SLOT_HELD=1 YMIR_HEAVY_SLOT_NAME="$NAME"
  # shellcheck disable=SC2068
  exec "${CMD[@]}"
fi

# ── wait for the slot ────────────────────────────────────────────────────────
waited=0
while :; do
  slot_reap_if_stale || true
  if slot_take "$NAME" "${CMD[*]}"; then break; fi
  if [ "$NO_WAIT" = 1 ]; then
    slot_say_holder "SLOT,refused"
    say "detail,not waiting,--no-wait was given; nothing was run"
    exit 3
  fi
  if [ -n "$WAIT_MAX" ] && [ "$waited" -ge "$WAIT_MAX" ]; then
    slot_say_holder "SLOT,refused"
    say "detail,gave up,waited ${waited}s of --wait-max ${WAIT_MAX}; nothing was run"
    exit 3
  fi
  # Say whose job it waits for — once at the start, then every minute, so a long wait is
  # legible in a journal rather than a silence.
  if [ $((waited % 60)) -eq 0 ]; then
    slot_say_holder "SLOT,waiting"
    say "detail,waiting for,$NAME waits for the job above; it runs the moment the slot is free"
  fi
  sleep 1
  waited=$((waited + 1))
done

# ── run under the hold, and give it back on every way out ────────────────────
# The command runs as a CHILD and is waited for, rather than in the foreground, because a bash trap
# only fires between foreground commands: with the job in the foreground a TERM to this process
# would not release the slot until the heavy job finished on its own. A signal kills the job first,
# then gives the slot back — a kill is a decision, and a decision must not leave the lock behind.
export YMIR_HEAVY_SLOT_HELD=1 YMIR_HEAVY_SLOT_PID="$$" YMIR_HEAVY_SLOT_NAME="$NAME"
CHILD=0
on_exit()  { local rc=$?; slot_release; exit $rc; }
on_signal() {  # <signal> <exit code>
  local sig="$1" code="$2"
  trap - INT TERM HUP QUIT
  if [ "$CHILD" != 0 ]; then kill -TERM "$CHILD" 2>/dev/null; fi
  slot_release
  say "SLOT,released,signal $sig — the slot is free again"
  exit "$code"
}
trap on_exit EXIT
trap 'on_signal INT 130' INT
trap 'on_signal TERM 143' TERM
trap 'on_signal HUP 129' HUP
trap 'on_signal QUIT 131' QUIT

say "slot[1]{lock,state,pid,name,waited}:"
say "  \"$(slot_path)\",\"held\",\"$$\",\"$NAME\",\"${waited}s\""
# shellcheck disable=SC2068
"${CMD[@]}" &
CHILD=$!
wait "$CHILD"
rc=$?
CHILD=0
exit "$rc"
