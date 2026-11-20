#!/usr/bin/env bash
# heavy-slot.sh — this machine's HEAVY LANES: a counted number of heavy jobs at once, and a
# record of who holds each lane.
#
# WHY (plan 002 §6.1, measured on the heart 2026-11-17). `updating.md`'s first law was "one heavy
# job at a time — `bin/heavy-slot.sh take` before a build", and the command did not exist anywhere
# in the tree. So a gate suite, a release build and an errand's test run could all proceed at once
# on a box with 11 GB of RAM whose swap was already 3.0 of 4.0 GB. At 07:20:59 the kernel fired.
# A law with no mechanism is a hope; this is the mechanism.
#
# WHY IT IS COUNTED, NOT ONE (the Allfather, 2026-11-18: "the server can handle more builders").
# The first version was an EXCLUSIVE lock, so the whole machine ran one heavy job. That was the
# right cure for the night it was written, and it taught the house the wrong lesson: it made
# "one heavy job" and "one builder" the same sentence, and a box with eight cores and eleven
# gigabytes sat idle behind a single lane. The number now belongs to the MACHINE and is read from
# its own row in the home's fleet registry (`lanes`), so a small hand carries one and a server
# carries as many as its operator has measured it can.
#
# WHAT IT IS, in one sentence: a counted lock, machine-wide, where each lane carries the holder's
# pid and the instant it started, so a heavy job waits for a FREE lane — or says whose job it
# waits for — instead of running beside one more than the machine allows.
#
#   bin/heavy-slot.sh run -- <command…>     wait for a free lane, then run the command under it
#   bin/heavy-slot.sh status                every lane, who holds it (or that it is free), for how long
#
# THE THREE THINGS THIS DOOR MUST NEVER DO:
#   · it never leaves a lock behind: a holder that dies is REAPED, not waited on forever. The
#     record carries the process START TIME beside the pid, because a pid is reused — a lock
#     whose pid now belongs to another process is stale, and reaping it is the safe reading.
#   · it never runs beside more heavy jobs than the machine carries: `run` holds its lane for the
#     whole life of the command, and the hold is INHERITED by that command's children (so a proof
#     run that itself calls a heavy door nests instead of deadlocking on its own lane).
#   · it never releases someone else's lock: the release is guarded by pid + start time, and the
#     trap fires on EXIT and on INT/TERM/HUP/QUIT alike.
#
# Configuration (Rule 07 — one documented default each):
#   YMIR_HEAVY_SLOTS   how many heavy jobs this machine carries. Unset → the machine's own row
#                      in the home's fleet registry (`hosts.<host>.lanes`) → 1.
#   YMIR_HEAVY_SLOT    lane 1's lock file (default ${XDG_STATE_HOME:-$HOME/.local/state}/ymir/heavy-slot.lock);
#                      lane N's is the same name with `.<N>` before `.lock`, so an existing single
#                      lock is lane 1 and an old caller and a new one cannot disagree.
#   YMIR_HEAVY_SLOT_HELD   set to 1 by this door in the child; a nested call runs straight through
set -uo pipefail

HEAVY_SLOT_VERSION="2.0.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The home's own resolver, so this door never invents a second place to look (Rule 07).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/vault/hoard-lib.sh" "$SCRIPT_DIR/../vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi

say()  { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }
die()  { warn "error: $*"; exit 1; }

usage() {
  cat <<'EOF'
heavy-slot — this machine's heavy lanes (a counted number of heavy jobs at once).

  bin/heavy-slot.sh run [--name LABEL] [--no-wait] [--wait-max SECONDS] -- <command…>
  bin/heavy-slot.sh status [--json]
  bin/heavy-slot.sh lanes
  bin/heavy-slot.sh --help | --version

`run` takes a free lane, prints whose job it waits for when every lane is held, runs the command
with the hold inherited, and releases on exit — including on a signal.

  --name LABEL      what to call this job in the record (default: the command's own name)
  --no-wait         do not wait: refuse (exit 3) and name the holders
  --wait-max N      give up waiting after N seconds, naming the holders (exit 3)

`lanes` prints the count this machine carries and where the number came from.
`status` exits 3 when any lane is held, 0 when every lane is free.

Exit: the command's own code · 2 usage · 3 refused (all lanes held and not waited for).
EOF
}

# ── where the locks live ──────────────────────────────────────────────────────
# Machine-wide and per-user on purpose: two worktrees, two errands and a systemd unit are
# the same machine, and the fault this door exists to stop happened exactly between them.
slot_base() {
  printf '%s' "${YMIR_HEAVY_SLOT:-${XDG_STATE_HOME:-$HOME/.local/state}/ymir/heavy-slot.lock}"
}

lane_path() {  # <n> → the lock for that lane; lane 1 keeps the original name
  local n="${1:-1}" base
  base="$(slot_base)"
  case "$n" in ''|*[!0-9]*) n=1 ;; esac
  if [ "$n" -le 1 ]; then
    printf '%s' "$base"
  else
    printf '%s.%s.lock' "${base%.lock}" "$n"
  fi
}

# ── how many lanes this machine carries ───────────────────────────────────────
# The number is the MACHINE's, never the repo's: it is read from this host's own row in the
# home's fleet registry, where the operator has measured what the box can take. A registry that
# cannot be read is not an error — it is the documented default of one heavy job.
registry_field() {  # <key> → this host's value for that key, empty when it cannot be answered
  local key="$1" home="" reg="" out=""
  command -v python3 >/dev/null 2>&1 || return 0
  if command -v ymir_home_root >/dev/null 2>&1; then ymir_home_root home 2>/dev/null; fi
  home="${home:-${YMIR_HOME:-}}"
  [ -n "$home" ] || return 0
  reg="${YMIR_FLEET_REGISTRY:-$home/hodd/data/fleet.json}"
  [ -r "$reg" ] || return 0
  out="$(YMIR_THIS_HOST="$(hostname -s 2>/dev/null | tr 'A-Z' 'a-z')" python3 - "$reg" "$key" <<'PY' 2>/dev/null
import json, os, sys
reg, key = sys.argv[1], sys.argv[2]
try:
    doc = json.load(open(reg))
except Exception:
    sys.exit(0)
row = (doc.get("hosts") or {}).get(os.environ.get("YMIR_THIS_HOST", ""))
if not isinstance(row, dict):
    sys.exit(0)
v = row.get(key)
if v is None or isinstance(v, bool):
    sys.exit(0)
print(v)
PY
)"
  printf '%s' "$out"
}

slot_lanes_resolve() {  # sets LANES_N and LANES_SRC in THIS shell (a subshell cannot carry them)
  local n="${YMIR_HEAVY_SLOTS:-}" src="env YMIR_HEAVY_SLOTS"
  if [ -z "$n" ]; then
    n="$(registry_field lanes)"
    src="the fleet registry's own row"
  fi
  case "$n" in ''|*[!0-9]*) n=1; src="default (nothing said otherwise)" ;; esac
  [ "$n" -ge 1 ] || { n=1; src="default (nothing said otherwise)"; }
  LANES_N="$n"
  LANES_SRC="$src"
}

slot_lanes() {  # → the lane count, for a caller that only needs the number
  slot_lanes_resolve
  printf '%s' "$LANES_N"
}

# ── the record, read and written ──────────────────────────────────────────────
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
# The rename is the race breaker: two waiters that both judge a lock stale both try to move it,
# and only one move can succeed. Nothing is ever removed by name while a live holder may own it,
# and the release path re-checks pid + start time before it deletes anything.
lane_reap_if_stale() {  # <lock>
  local lock="$1" pid starttime aside
  [ -e "$lock" ] || return 0
  pid="$(slot_field "$lock" pid)"
  starttime="$(slot_field "$lock" starttime)"
  if [ -n "$pid" ] && pid_alive "$pid" "$starttime"; then
    return 1                      # a live holder: this lane is genuinely held
  fi
  aside="${lock}.stale.$$"
  if mv -- "$lock" "$aside" 2>/dev/null; then
    rm -f -- "$aside"
    return 0
  fi
  # Someone else reaped or claimed it in the same instant; the next attempt will see the truth.
  return 0
}

reap_all() {
  local n lanes lock
  lanes="$(slot_lanes)"
  n=1
  while [ "$n" -le "$lanes" ]; do
    lane_reap_if_stale "$(lane_path "$n")" || true
    n=$((n + 1))
  done
}

# ── take: an exclusive create per lane, one link(2) each ──────────────────────
# The record is written in full under a temporary name and then LINKED into place. `ln` fails
# when the target exists, which is the atomicity: no reader ever sees an empty lock, and no two
# takers can both win the same lane.
SLOT_TAKEN=""
SLOT_TAKEN_LANE=""
slot_take() {  # <name> <command…> → 0 taken · 1 every lane held
  local name="$1"; shift
  local n lanes lock tmp
  lanes="$(slot_lanes)"
  n=1
  while [ "$n" -le "$lanes" ]; do
    lock="$(lane_path "$n")"
    mkdir -p -- "$(dirname "$lock")" 2>/dev/null || die "cannot create $(dirname "$lock")"
    tmp="${lock}.tmp.$$"
    {
      printf 'pid=%s\n' "$$"
      printf 'started=%s\n' "$(now_iso)"
      printf 'starttime=%s\n' "$(pid_starttime "$$")"
      printf 'host=%s\n' "$(hostname -s 2>/dev/null || hostname 2>/dev/null || printf 'unknown')"
      printf 'lane=%s\n' "$n"
      printf 'name=%s\n' "$name"
      printf 'cmd=%s\n' "$*"
    } >"$tmp" 2>/dev/null || { rm -f -- "$tmp"; die "cannot write $tmp"; }
    if ln -- "$tmp" "$lock" 2>/dev/null; then
      rm -f -- "$tmp"
      SLOT_TAKEN="$lock"
      SLOT_TAKEN_LANE="$n"
      return 0
    fi
    rm -f -- "$tmp"
    n=$((n + 1))
  done
  return 1
}

slot_held_by_me() {  # <lock> → 0 when this process is the recorded holder
  local lock="$1" pid starttime
  [ -r "$lock" ] || return 1
  pid="$(slot_field "$lock" pid)"
  starttime="$(slot_field "$lock" starttime)"
  [ "$pid" = "$$" ] || return 1
  [ -z "$starttime" ] || [ "$starttime" = "$(pid_starttime "$$")" ]
}

slot_release() {
  local n lanes lock
  if [ -n "${SLOT_TAKEN:-}" ]; then
    slot_held_by_me "$SLOT_TAKEN" && rm -f -- "$SLOT_TAKEN"
    return 0
  fi
  # A trap that fires before the take recorded itself: release only a lane that is truly ours.
  lanes="$(slot_lanes)"
  n=1
  while [ "$n" -le "$lanes" ]; do
    lock="$(lane_path "$n")"
    slot_held_by_me "$lock" && rm -f -- "$lock"
    n=$((n + 1))
  done
  return 0
}

slot_say_holders() {  # <prefix> — name every job being waited for, in the house's own rows
  local n lanes lock rows=0
  lanes="$(slot_lanes)"
  say "${1},held"
  n=1
  while [ "$n" -le "$lanes" ]; do
    lock="$(lane_path "$n")"
    if [ -r "$lock" ] && [ -n "$(slot_field "$lock" pid)" ]; then
      if [ "$rows" = 0 ]; then say "holder[${lanes}]{lane,pid,started,starttime,host,name,cmd,running}:"; rows=1; fi
      printf '  "%s",' "$n"
      holder_row "$lock" | sed 's/^  //'
    fi
    n=$((n + 1))
  done
  [ "$rows" = 1 ] || say '  "unknown","unknown","unknown","unknown","unknown","unknown","unknown","unknown"'
}

# ── status ────────────────────────────────────────────────────────────────────
slot_status() {
  local n lanes lock state="free" held=0 total full=false
  lanes="$(slot_lanes)"
  total="$lanes"
  reap_all
  n=1
  while [ "$n" -le "$lanes" ]; do
    [ -e "$(lane_path "$n")" ] && held=$((held + 1))
    n=$((n + 1))
  done
  [ "$held" -gt 0 ] && state="held"
  # `state` keeps its original meaning (held = at least one lane taken) so an older reader is not
  # lied to; whether EVERY lane is taken is the separate `full` flag.
  if [ "$held" -ge "$total" ]; then full=true; else full=false; fi
  if [ "${JSON_FLAG:-0}" = 1 ]; then
    printf '{"lanes":%s,"held":%s,"state":"%s","full":%s,"lock":"%s"}\n' \
      "$total" "$held" "$state" "$full" "$(slot_base)"
    [ "$held" -eq 0 ] || exit 3
    exit 0
  fi
  slot_lanes_resolve
  say "lanes[1]{count,source}:"
  say "  \"$total\",\"$LANES_SRC\""
  say "lane[${total}]{lane,lock,state,pid,name,started,running}:"
  n=1
  while [ "$n" -le "$lanes" ]; do
    lock="$(lane_path "$n")"
    if [ -r "$lock" ] && [ -n "$(slot_field "$lock" pid)" ]; then
      printf '  "%s","%s","held","%s","%s","%s","%s"\n' "$n" "$lock" \
        "$(slot_field "$lock" pid)" "$(slot_field "$lock" name)" \
        "$(slot_field "$lock" started)" "$(since_of "$(slot_field "$lock" pid)")"
    else
      printf '  "%s","%s","free","","","",""\n' "$n" "$lock"
    fi
    n=$((n + 1))
  done
  [ "$held" -eq 0 ] || exit 3
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
  lanes) ;;
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

if [ "$VERB" = "lanes" ]; then
  slot_lanes_resolve
  say "lanes[1]{count,source}:"
  say "  \"$LANES_N\",\"$LANES_SRC\""
  exit 0
fi

if [ "$VERB" = "status" ]; then
  slot_status
fi

[ "${#CMD[@]}" -gt 0 ] || { warn "run needs a command: bin/heavy-slot.sh run -- <command…>"; exit 2; }
[ -n "$NAME" ] || NAME="$(basename "${CMD[0]}")"
case "${WAIT_MAX:-0}" in ''|*[!0-9]*) warn "--wait-max needs a number of seconds"; exit 2 ;; esac

# ── inherited: a heavy job inside a heavy job is not a second job ────────────
if [ "${YMIR_HEAVY_SLOT_HELD:-0}" = 1 ]; then
  say "SLOT,nested,$NAME,runs under the lane already held by pid ${YMIR_HEAVY_SLOT_PID:-unknown}"
  export YMIR_HEAVY_SLOT_HELD=1 YMIR_HEAVY_SLOT_NAME="$NAME"
  # shellcheck disable=SC2068
  exec "${CMD[@]}"
fi

# ── wait for a lane ──────────────────────────────────────────────────────────
waited=0
LANES_N="$(slot_lanes)"
while :; do
  reap_all
  if slot_take "$NAME" "${CMD[*]}"; then break; fi
  if [ "$NO_WAIT" = 1 ]; then
    slot_say_holders "SLOT,refused"
    say "detail,not waiting,--no-wait was given; every lane is held and nothing was run"
    exit 3
  fi
  if [ -n "$WAIT_MAX" ] && [ "$waited" -ge "$WAIT_MAX" ]; then
    slot_say_holders "SLOT,refused"
    say "detail,gave up,waited ${waited}s of --wait-max ${WAIT_MAX}; nothing was run"
    exit 3
  fi
  # Say whose job it waits for — once at the start, then every minute, so a long wait is
  # legible in a journal rather than a silence.
  if [ $((waited % 60)) -eq 0 ]; then
    slot_say_holders "SLOT,waiting"
    say "detail,waiting for,$NAME waits for a free lane of ${LANES_N}; it runs the moment one is free"
  fi
  sleep 1
  waited=$((waited + 1))
done

# ── run under the hold, and give it back on every way out ────────────────────
# The command runs as a CHILD and is waited for, rather than in the foreground, because a bash trap
# only fires between foreground commands: with the job in the foreground a TERM to this process
# would not release the lane until the heavy job finished on its own. A signal kills the job first,
# then gives the lane back — a kill is a decision, and a decision must not leave the lock behind.
export YMIR_HEAVY_SLOT_HELD=1 YMIR_HEAVY_SLOT_PID="$$" YMIR_HEAVY_SLOT_NAME="$NAME"
CHILD=0
on_exit()  { local rc=$?; slot_release; exit $rc; }
on_signal() {  # <signal> <exit code>
  local sig="$1" code="$2"
  trap - INT TERM HUP QUIT
  if [ "$CHILD" != 0 ]; then kill -TERM "$CHILD" 2>/dev/null; fi
  slot_release
  say "SLOT,released,signal $sig — lane ${SLOT_TAKEN_LANE} is free again"
  exit "$code"
}
trap on_exit EXIT
trap 'on_signal INT 130' INT
trap 'on_signal TERM 143' TERM
trap 'on_signal HUP 129' HUP
trap 'on_signal QUIT 131' QUIT

say "slot[1]{lane,lock,state,pid,name,waited,lanes}:"
say "  \"${SLOT_TAKEN_LANE}\",\"${SLOT_TAKEN}\",\"held\",\"$$\",\"$NAME\",\"${waited}s\",\"${LANES_N}\""
# shellcheck disable=SC2068
"${CMD[@]}" &
CHILD=$!
wait "$CHILD"
rc=$?
CHILD=0
exit "$rc"
