#!/usr/bin/env bash
# nornir-cron-start.sh - ensure Brokk's scheduled jobs are running (idempotent).
#
# Nornir are the fates who govern time. Jobs are declared in config/cron.yaml as
# `HH:MM <command>` lines (one per line, `#` comments; `@hourly`, `@hourly:MM`,
# `@daily` and `@every:N` are the other shapes). This script keeps exactly
# one lightweight scheduler loop alive via state/cron.pid. The loop:
#   * date-guards each job under state/.cron-fired/<job> so it runs once a day,
#     even across a restarted loop;
#   * runs each command with a per-job flock so a slow job never overlaps itself;
#   * exports the BROKK_* home/state/config/root env to every job;
#   * runs jobs from BROKK_HOME and logs to state/cron.log.
#
# Ported concept from plan 24 (cron schedule) and the upstream stateless-spawn
# pattern for plan 29.
#
# Usage: nornir-cron-start.sh [--status|--stop [--why "<reason>"]]
#
# Environment (kept from the original interface):
#   BROKK_ROOT_OVERRIDE, BROKK_HOME, BROKK_STATE_OVERRIDE, BROKK_CONFIG_OVERRIDE
#   BROKK_CRON_LOG_MAX_BYTES  rotation threshold for state/cron.log (default 1 MiB)
case "${1-}" in
  -h|--help) sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
set -u

# --- portability shim: bin/fleet/ymir-platform.sh --------------------------------
# One place knows the OS differences (readlink -f, /proc, setsid, stat, nproc).
if [ -z "${YMIR_PLATFORM_LOADED:-}" ]; then
  _ymir_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  for _ymir_c in "${_ymir_dir}/../fleet/ymir-platform.sh" "$(CDPATH='' cd "$_ymir_dir" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)/bin/fleet/ymir-platform.sh"; do
    [ -r "$_ymir_c" ] && { . "$_ymir_c"; YMIR_PLATFORM_LOADED=1; break; }
  done
  unset _ymir_dir _ymir_c
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)}"
export ROOT  # the job wrapper needs it after bash -c
BROKK_HOME="${BROKK_HOME:-$ROOT}"
# A SEAT MUST NOT SCHEDULE THE HOUSE. Every errand seat runs a session start with
# its OWN state dir (`…/ymir/seats/<id>`), and this door's "is it stopped" check then
# answers yes — so six seats started six schedulers over one config/cron.yaml, each
# keeping its own already-fired marks. A 14:20 job could run six times, each scheduler
# believing it was first (measured 2026-10-24: `cron-leak: 6 cron loops`). Only the
# primary's state starts the house schedule; a seat says so and exits 0.
case "${BROKK_STATE_OVERRIDE:-}" in
  */seats/*)
    printf 'cron[1]{state,why}:\n  "refused","a seat does not schedule the house — %s is a seat state dir; the primary owns config/cron.yaml"\n' "$BROKK_STATE_OVERRIDE" >&2
    exit 0 ;;
esac
# ONE STATE DIR (phase 0): the operator's runtime state belongs to the HOME, never
# the code tree. With no explicit override the default used to be $BROKK_HOME/state
# (the repo's scratch), so any advisory caller — ymir-validate, a session start —
# read a DIFFERENT pidfile than the units and started a second scheduler over the
# same schedule (measured 2026-11-06: one loop under the unit, one under the repo).
# The hoard is the one answer; the repo's state/ is the fallback only when there is
# no home at all.
if [ -n "${BROKK_STATE_OVERRIDE:-}" ]; then
  STATE="$BROKK_STATE_OVERRIDE"
else
  _hoard=""
  if [ -r "$SCRIPT_DIR/../vault/hoard-lib.sh" ]; then
    . "$SCRIPT_DIR/../vault/hoard-lib.sh" 2>/dev/null || true
    ymir_home_root _hoard 2>/dev/null || _hoard=""
  fi
  if [ -n "$_hoard" ] && [ -d "$_hoard/state" ]; then
    STATE="$_hoard/state"
  else
    STATE="$BROKK_HOME/state"
  fi
  unset _hoard
fi
# The schedule is the USER'S, not the distro's: an explicit BROKK_CONFIG_OVERRIDE
# wins, then the home's own config/cron.yaml, then the repo's example (which
# ships what a fresh hour suggests but never claims to be the live schedule).
if [ -n "${BROKK_CONFIG_OVERRIDE:-}" ]; then
  CONFIG="$BROKK_CONFIG_OVERRIDE"
else
  . "$SCRIPT_DIR/../vault/hoard-lib.sh"  # ymir_home_root — one answer, never drift
  ymir_home_root _h
  if [ -r "$_h/config/cron.yaml" ]; then
    CONFIG="$_h/config"
  elif [ -r "$BROKK_HOME/config/cron.yaml" ] && [ "$BROKK_HOME" != "$_h" ]; then
    CONFIG="$BROKK_HOME/config"
  else
    CONFIG="$BROKK_HOME/config"
  fi
fi
CRON_CONFIG="$CONFIG/cron.yaml"
# Fall back to the shipped example ONLY when no user schedule exists yet — the
# example is a template, never the live job list.
if [ ! -r "$CRON_CONFIG" ] && [ -r "$BROKK_HOME/config/cron.yaml.example" ]; then
  CRON_CONFIG="$BROKK_HOME/config/cron.yaml.example"
fi
PID_FILE="$STATE/cron.pid"
# Which lock the clock watches (plan 369 item 17). <state>/.lock-path is believed only when it names this
# machine's primary lock, or a lock inside this state dir with a live owner. Anything else (a test's scratch
# lock once stood there) is refused in words and the primary lock is watched. Prints "<lock><TAB><refusal>".
lock_to_watch() { # <state-dir>
  local st="$1" def p="" owner why=""
  def="${XDG_STATE_HOME:-$HOME/.local/state}/ymir/brokk.lock"
  if [ -n "${BROKK_MACHINE_STATE_DIR:-}" ]; then printf '%s\t\n' "$BROKK_MACHINE_STATE_DIR/brokk.lock"; return 0; fi
  [ -f "$st/.lock-path" ] && p=$(tr -d '[:space:]' <"$st/.lock-path" 2>/dev/null)
  if [ -n "$p" ] && [ "$p" != "$def" ]; then
    case "$p" in
      "$st"/*)
        owner=$(tr -d '[:space:]' <"$p" 2>/dev/null)
        case "$owner" in ''|*[!0-9]*) owner="" ;; esac
        if [ -n "$owner" ] && kill -0 "$owner" 2>/dev/null; then def="$p"
        else why="$st/.lock-path refused: $p has no live owner"; fi ;;
      *) why="$st/.lock-path refused: $p is outside $st and is not the primary lock" ;;
    esac
  fi
  printf '%s\t%s\n' "$def" "$why"
}
export -f lock_to_watch

# A WORKER SEAT MUST NEVER START, REPLACE OR STOP THE HOUSE CLOCK (2026-11-24). A herdr seat is created with
# BROKK_MACHINE_STATE_DIR (and BROKK_STATE_OVERRIDE) set to ONE private dir, so a seat never takes the helm's
# lock. Its Claude session hook still called this door: the scheduler it started bound to the seat's lock
# dir, found no lock, retired, and the house clock missed a day of @dev jobs. A seat is a private machine dir
# that is also its own state dir and is not the helm's; it is refused with one named line. A machine dir
# that does not exist is refused the same way, never turned into a retirement.
_mach="${BROKK_MACHINE_STATE_DIR:-}"
if [ -n "$_mach" ] && [ "${BROKK_NORNIR_PERSIST:-0}" != "1" ]; then
  _hp=""; _hh=""
  . "$SCRIPT_DIR/../vault/hoard-lib.sh" 2>/dev/null || true
  ymir_home_root _hh 2>/dev/null || _hh=""
  [ -n "$_hh" ] && [ -f "$_hh/state/.lock-path" ] && _hp="$(dirname "$(cat "$_hh/state/.lock-path" 2>/dev/null)")"
  _helm_dir="${_hp:-${XDG_STATE_HOME:-$HOME/.local/state}/ymir}"
  case "${1-}" in --status|--last) ;; *)
    if [ ! -d "$_mach" ]; then
      printf 'cron[1]{state,why}:\n  "refused","BROKK_MACHINE_STATE_DIR %s does not exist; the clock is not started against a missing lock dir"\n' "$_mach" >&2
      exit 0
    fi
    if [ "$_mach" != "$_helm_dir" ] && [ "$_mach" = "${BROKK_STATE_OVERRIDE:-}" ]; then
      printf 'cron[1]{state,why}:\n  "refused","a worker seat does not start or stop the house clock — %s is a seat dir, the helm lock is in %s"\n' "$_mach" "$_helm_dir" >&2
      exit 0
    fi ;;
  esac
  unset _hp _hh
fi
LOG_FILE="$STATE/cron.log"
STAMP_DIR="$STATE/.cron-fired"
LOCK_DIR="$STATE/.cron-locks"
IDENTITY_MARK='cron run:'

mkdir -p "$STATE"

job_count() {
  [ -r "$CRON_CONFIG" ] || { printf '0'; return; }
  grep -vE '^[[:space:]]*(#|$)' "$CRON_CONFIG" 2>/dev/null | wc -l | tr -d '[:space:]'
}

# A live loop is a live pid whose command line still carries the scheduler body.
# The identity check guards against pid reuse after a reboot/crash.
running_pid() {
  [ -r "$PID_FILE" ] || return 1
  local pid
  pid=$(tr -d '[:space:]' <"$PID_FILE")
  case "$pid" in
    ''|*[!0-9]*) return 1 ;;
  esac
  kill -0 "$pid" 2>/dev/null || return 1
  # /proc is Linux-only; the shim falls back to `ps -o command=`.
  if ymir_pid_alive "$pid"; then
    ymir_pid_cmdline "$pid" 2>/dev/null | grep -q "$IDENTITY_MARK" || return 1
  fi
  printf '%s' "$pid"
}

# The live lock owner this caller does NOT descend from (exit 1: no live owner, or the caller is inside it).
foreign_owner() {
  local lock owner p i
  [ -n "${BROKK_MACHINE_STATE_DIR:-}" ] || [ -f "$STATE/.lock-path" ] || return 1
  lock=$(lock_to_watch "$STATE"); lock=${lock%%$'\t'*}
  owner=$(tr -d '[:space:]' <"$lock" 2>/dev/null)
  case "$owner" in ''|*[!0-9]*) return 1 ;; esac
  kill -0 "$owner" 2>/dev/null || return 1
  p=$$
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    [ "$p" = "$owner" ] && return 1
    p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
    case "$p" in ''|0|1) break ;; esac
  done
  printf '%s' "$owner"
}

rotate_log() {
  [ -r "$LOG_FILE" ] || return 0
  local size max
  size=$(wc -c <"$LOG_FILE" 2>/dev/null | tr -d '[:space:]')
  case "$size" in ''|*[!0-9]*) return 0 ;; esac
  max="${BROKK_CRON_LOG_MAX_BYTES:-1048576}"
  if [ "$size" -gt "$max" ]; then
    mv "$LOG_FILE" "$LOG_FILE.1" 2>/dev/null || true
  fi
}

# ── the schedule SHAPES (plan 140) ─────────────────────────────────────────────
# One parser, used by the loop AND by the start-time warning, because two parsers
# is how a row goes declared-but-dead (2026-09-24, one layer up). A shape decides
# BOTH what fires and which STAMP it writes: a per-day job may fire once a day, a
# per-hour job once an hour, and the stamp is what stops a 45 s loop from firing
# the same row twice.
is_role() { # <token> -> 0 when it is a role gate (@heart, @dev,forge)
  case "${1-}" in @?*) ;; *) return 1 ;; esac
  local _r
  for _r in $(printf '%s' "${1#@}" | tr ',' ' '); do
    case "$_r" in heart|forge|dev|hand) ;; *) return 1 ;; esac
  done
  return 0
}

is_dow() { # <token> -> 0 when it is a day-of-week gate: Mon · Mon,Fri · Monday
  case "${1-}" in ''|*[!A-Za-z,]*) return 1 ;; esac
  local _d _hit=0
  for _d in $(printf '%s' "$1" | tr ',' ' '); do
    _hit=1
    case "$_d" in
      Mon|Tue|Wed|Thu|Fri|Sat|Sun) ;;
      Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday) ;;
      *) return 1 ;;
    esac
  done
  [ "$_hit" = 1 ]
}

dow_matches() { # <dow> -> 0 when TODAY is one of the days it names
  local _want _today _d
  _today=$(date +%a)
  for _want in $(printf '%s' "${1-}" | tr ',' ' '); do
    case "$_want" in
      Mon|Monday) _d=Mon ;; Tue|Tuesday) _d=Tue ;; Wed|Wednesday) _d=Wed ;;
      Thu|Thursday) _d=Thu ;; Fri|Friday) _d=Fri ;; Sat|Saturday) _d=Sat ;;
      Sun|Sunday) _d=Sun ;; *) continue ;;
    esac
    [ "$_d" = "$_today" ] && return 0
  done
  return 1
}

at_valid() { # <at> -> 0 when the time token is a shape the scheduler understands
  case "${1-}" in
    @hourly|@daily) return 0 ;;
    @hourly:*)
      local _m="${1#@hourly:}"
      case "$_m" in ''|*[!0-9]*) return 1 ;; esac
      [ "$_m" -le 59 ] 2>/dev/null && return 0
      return 1 ;;
    @every:*)
      # Every N minutes, aligned to the hour (:00, :05, …). Added 2026-11-13 for the
      # auto-join clock: `@hourly` is too coarse to put a bot into a 30-minute meeting.
      local _n="${1#@every:}"
      case "$_n" in ''|*[!0-9]*) return 1 ;; esac
      [ "$_n" -ge 1 ] 2>/dev/null && [ "$_n" -le 59 ] 2>/dev/null && return 0
      return 1 ;;
    [01][0-9]:[0-5][0-9]|2[0-3]:[0-5][0-9]) return 0 ;;
  esac
  return 1
}

# parse_line <line> -> "gate<TAB>at<TAB>cmd" — the role gate may sit before or after
# the time (plan 54), and a shape may sit in either place too, so the token that is
# a ROLE is found by what it is, never by its position.
parse_line() { # -> "gate<TAB>at<TAB>dow<TAB>cmd"
  local _rest="${1-}" _tok _gate="-" _dow="" _at=""
  # `-` stands for 'no role gate': a leading EMPTY field would be eaten by IFS
  # (tab is whitespace to `read`), which silently shifts every field by one.
  _tok=${_rest%% *}
  if [ "$_tok" = "$_rest" ]; then _rest=""; else _rest=${_rest#* }; fi
  if is_role "$_tok"; then _gate=$_tok; _tok=${_rest%% *}
    if [ "$_tok" = "$_rest" ]; then _rest=""; else _rest=${_rest#* }; fi
  fi
  # A DAY gate may sit before the time (`@heart Mon 09:15 …`, or `Mon 09:15 …` on an
  # ungated row). It is recognised by what it IS, never by its position (plan 305).
  if is_dow "$_tok"; then _dow=$_tok; _tok=${_rest%% *}
    if [ "$_tok" = "$_rest" ]; then _rest=""; else _rest=${_rest#* }; fi
  fi
  # The shape may also sit before the role (`09:15 @heart …`), which is the older form.
  _at=$_tok
  if is_role "$_at" && [ -n "$_rest" ]; then
    [ "$_gate" = "-" ] && _gate=$_at
    _at=${_rest%% *}
    if [ "$_at" = "$_rest" ]; then _rest=""; else _rest=${_rest#* }; fi
  fi
  printf '%s\t%s\t%s\t%s\n' "$_gate" "$_at" "$_dow" "$_rest"
}
export -f is_role is_dow dow_matches at_valid parse_line

scheduler='
  config="$1"; log="$2"; state="$3"; home="$4"; confdir="$5"; root="$6"
  export BROKK_HOME="$home"
  export BROKK_STATE_OVERRIDE="$state"
  export BROKK_CONFIG_OVERRIDE="$confdir"
  export BROKK_ROOT_OVERRIDE="$root"
  export BROKK_REALM="${BROKK_REALM:-}"
  export BROKK_ROLES="${BROKK_ROLES:-dev}"
  stamp_dir="$state/.cron-fired"
  lock_dir="$state/.cron-locks"
  # The ONE sentence a failure gets (bin/time/cron-fail-lib.sh, plan 292). Optional on purpose: a
  # scheduler started from an older tree keeps the tail-only message instead of failing to start.
  _fail_lib="${YMIR_CRON_FAIL_LIB:-$ROOT/bin/time/cron-fail-lib.sh}"
  [ -r "$_fail_lib" ] && . "$_fail_lib" 2>/dev/null
  # One row, one run, one verdict. Both branches below call THIS, because the notifier had been
  # copied twice and the two copies could drift — and one of them deciding the message is how
  # "the job broke" and "the job was never found" came to read identically (plan 292).
  run_row() {
    cd "$home" 2>/dev/null || true
    # THE ROW SPEAKS FOR ITSELF (2026-11-21). The tail used to be read from the SHARED log, so a row
    # that failed was described by whatever line another row wrote last, or by nothing ("no output").
    # The row now writes its own stdout and stderr to its own files; both are appended to the log, and
    # a failure is described by its OWN last stderr lines (its stdout when stderr is empty).
    _t0=$(date +%s)
    _out="$(mktemp "${TMPDIR:-/tmp}/nornir-row.XXXXXX")"; _err="$(mktemp "${TMPDIR:-/tmp}/nornir-row.XXXXXX")"
    if [ -n "$_out" ] && [ -n "$_err" ]; then
      bash -lc "$cmd" >"$_out" 2>"$_err"
      _rc=$?
      cat "$_out" "$_err" >>"$log" 2>/dev/null
    else
      bash -lc "$cmd" >>"$log" 2>&1
      _rc=$?
    fi
    printf "%s cron done rc=%s %ss seat=%s: %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_rc" "$(( $(date +%s) - _t0 ))" "$(hostname -s 2>/dev/null)" "$cmd" >>"$log" 2>/dev/null
    if [ "$_rc" -eq 0 ]; then rm -f "$_out" "$_err"; return 0; fi
    # A door this machine does not run (not its door) is a clean skip, never a failure (RULES/25; exit 78 = EX_CONFIG).
    if [ "$_rc" -eq "${WARDEN_RC_NOT_HERE:-78}" ]; then
      printf "%s cron SKIP not-here: %s\n" "$ts" "$cmd" >>"$log"
      rm -f "$_out" "$_err"; return 0
    fi
    if declare -f cron_row_tail >/dev/null 2>&1; then
      _tail="$(cron_row_tail "$_err" "$_out")"
    else
      _tail="$(tail -n 4 "$_err" "$_out" 2>/dev/null | grep -v "^$" | grep -v "^==>" | tail -n 1 | cut -c1-160)"
    fi
    rm -f "$_out" "$_err"
    _why=""
    if declare -f cron_fail_detail >/dev/null 2>&1; then
      _why="$(cron_fail_detail "$home" "$cmd" "$_rc" "$_tail" 2>/dev/null)"
    fi
    [ -n "$_why" ] || _why="${_tail:-no output}"
    printf "%s cron FAIL rc=%s %s :: %s\n" "$ts" "$_rc" "$cmd" "$_why" >>"$log"
    # The events store (plan 333): one row per failed job, deduped by the same key the hotline uses.
    [ -x "$ROOT/bin/records/events-append.sh" ] && bash "$ROOT/bin/records/events-append.sh" --source cron \
      --kind job-failed --severity HIGH --key "cron-fail:$key:$today" --subject "job failed (rc=$_rc): $cmd" \
      --body "$_why" >/dev/null 2>&1 || true
    [ -x "$ROOT/bin/notify/send.sh" ] && bash "$ROOT/bin/notify/send.sh" --source cron --severity HIGH \
      --key "cron-fail:$key:$today" --message "job failed (rc=$_rc): $cmd — $_why" >/dev/null 2>&1 || true
    return 0
  }
  # A tab carried in a variable: fields are taken by expansion, never by `read`.
  # On this seat `IFS=<tab> read` put the whole line in the first field, and a
  # schedule parser that can eat a row without saying so is a schedule nobody trusts.
  TAB=$(printf "\t")
  mkdir -p "$stamp_dir" "$lock_dir"
  # A clock that is killed says so. The nap is a background sleep so the signal is answered at once.
  nap() { sleep "$1" & _nap=$!; wait "$_nap" 2>/dev/null; }
  stopped_by_signal() {
    printf "%s cron stopped by signal %s (pid %s)\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$$" >>"$log"
    [ -n "${_nap:-}" ] && kill "$_nap" 2>/dev/null
    [ "$(cat "$state/cron.pid" 2>/dev/null)" = "$$" ] && rm -f "$state/cron.pid"
    exit 0
  }
  trap "stopped_by_signal TERM" TERM
  trap "stopped_by_signal INT" INT
  trap "stopped_by_signal HUP" HUP
  while :; do
    today=$(date +%Y-%m-%d)
    # Retire when the session that started this scheduler is gone: a seat that
    # ends must not leave its cron loop behind (2026-09-23 -- eight orphan loops
    # from ended seats). The scheduler lives only while the state lock is held by
    # a live process; a headless scheduler with no lock retires too, because
    # Nornir is started BY a session, never before one.
    #
    # EXCEPTION (plan 51 Part 7): the always-on heart has no interactive session,
    # so the record crons would never run. A PERSISTENT seat sets
    # BROKK_NORNIR_PERSIST=1 and the loop binds to the machine ROLE, not a
    # session: it stays up with no lock and is stopped only by --stop or the
    # unit. (A fake session lock was the rejected alternative — it would refuse a
    # real Brokk seat on the heart.)
    # EXCEPTION kept: the persistent seat binds to the machine role, never to a session lock.
    if [ "${BROKK_NORNIR_PERSIST:-0}" != "1" ]; then
      _watch=$(lock_to_watch "$state")
      lockf=${_watch%%"$(printf "\t")"*}
      _refusal=${_watch#*"$(printf "\t")"}
      if [ -n "$_refusal" ] && [ "$_refusal" != "${_said:-}" ]; then
        printf "%s cron %s; watching %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$_refusal" "$lockf" >>"$log"
      fi
      _said=$_refusal
      # A lock missing for a moment (a runtime flip rewrites it) must not stop the clock: wait a
      # grace period and re-check before retiring (2026-11-22: three retirements around flips).
      _grace=${BROKK_CRON_LOCK_GRACE:-600}; _waited=0
      while :; do
        owner=$(tr -d "[:space:]" <"$lockf" 2>/dev/null || true)
        st=$(ps -o stat= -p "$owner" 2>/dev/null | tr -d " ")
        if [ -n "$owner" ] && [ "$owner" != "1" ] && [ -d "/proc/$owner" ] \
           && [ "${st#Z}" = "$st" ] && [ "${st#X}" = "$st" ]; then _live=1; break; fi
        [ "$_waited" -ge "$_grace" ] && { _live=0; break; }
        nap "${BROKK_CRON_LOCK_RECHECK:-15}"; _waited=$((_waited + ${BROKK_CRON_LOCK_RECHECK:-15}))
      done
      if [ "$_live" = 0 ]; then
        printf "%s cron retired - no live session lock at %s (waited %ss)\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$lockf" "$_waited" >>"$log"
        # A clock that stops is an alarm, not a quiet exit: the trouble panel and the board read this.
        mkdir -p "$state" 2>/dev/null; printf "%s no live session lock at %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$lockf" >"$state/.cron-retired" 2>/dev/null || true
        [ -x "$root/bin/notify/send.sh" ] && bash "$root/bin/notify/send.sh" --source cron --severity HIGH \
          --key "cron-retired:$today" --message "the Nornir clock retired: no live session lock" >/dev/null 2>&1 || true
        rm -f "$state/cron.pid" 2>/dev/null || true
        exit 0
      fi
      rm -f "$state/.cron-retired" 2>/dev/null || true
    fi
    now=$(date +%H:%M)
    today=$(date +%Y-%m-%d)
    this_hour=$(date +%Y-%m-%dT%H)
    while IFS= read -r line; do
      case "$line" in ""|\#*) continue ;; esac
      # An optional role gate may sit BEFORE the time (the home config form:
      # @heart 06:00 bin/x) or AFTER it (06:00 @heart bin/x). The 2026-09-24
      # fault: only the after-time shape parsed, so every role-first line was
      # silently DEAD while --status still counted it declared — on every seat,
      # the heart record jobs never fired. Both orders are one gate now (plan 54).
      gate=""; at=""; dow=""; cmd=""
      _parsed=$(parse_line "$line")
      gate=${_parsed%%"$TAB"*}
      _after=${_parsed#*"$TAB"}
      at=${_after%%"$TAB"*}
      _after=${_after#*"$TAB"}
      dow=${_after%%"$TAB"*}
      cmd=${_after#*"$TAB"}
      [ "$gate" = "-" ] && gate=""
      [ -n "$cmd" ] || continue
      # A token the scheduler cannot read is a job that would be SILENTLY dead, so
      # it is named once (in state/.cron-invalid, which --status reports) and never
      # fired. It is not allowed to look declared.
      if ! at_valid "$at"; then
        grep -qxF -- "$line" "$state/.cron-invalid" 2>/dev/null \
          || printf "%s\n" "$line" >>"$state/.cron-invalid"
        continue
      fi
      # The shape decides the fire and the STAMP (plan 140): @hourly fires at the
      # top of every hour, @hourly:MM at that minute, @daily at 00:00, HH:MM once a
      # day. The stamp key is derived from the shape — never guessed from the time.
      fire=0; stamp_key=""
      case "$at" in
        @hourly)   stamp_key="$this_hour"; [ "${now#*:}" = "00" ] && fire=1 ;;
        @hourly:*) _want=$(printf "%02d" "${at#@hourly:}" 2>/dev/null)
                   stamp_key="$this_hour"; [ "${now#*:}" = "$_want" ] && fire=1 ;;
        @every:*)  _n=$((10#${at#@every:}))
                   _min=$((10#$(date +%M)))
                   stamp_key="$this_hour/slot$((_min / _n))"
                   [ $((_min % _n)) -eq 0 ] && fire=1 ;;
        @daily)    stamp_key="$today"; [ "$now" = "00:00" ] && fire=1 ;;
        *)         stamp_key="$today $at"; [ "$at" = "$now" ] && fire=1   # the time is in the stamp: one script at 06:10 AND 18:10 fires twice (plan 365)
                   # CATCH-UP (panels-mend): a scheduler that was down (retired for want of a session lock, or restarted
                   # by a release flip) never saw its minute. A clock time already past today, for a job with no run
                   # stamped today, fires ONCE now, inside BROKK_CRON_CATCHUP_HOURS (default 14). The stamp holds the date of today
                   # date afterwards, so a later row of the same job cannot fire it again.
                   if [ "$fire" = 0 ] && [ "$at" \< "$now" ]; then
                     _cw=${BROKK_CRON_CATCHUP_HOURS:-14}
                     _lag=$(( (10#${now%%:*} * 60 + 10#${now#*:}) - (10#${at%%:*} * 60 + 10#${at#*:}) ))
                     _prev=$(cat "$stamp_dir/$(printf "%s" "$cmd" | tr -c "A-Za-z0-9._-" "_")" 2>/dev/null)
                     if [ "$_lag" -le $((_cw * 60)) ] && [ "${_prev%% *}" != "$today" ]; then fire=1; fi
                   fi ;;
      esac
      [ "$fire" = 1 ] || continue
      # A DAY gate (plan 305): a weekly row fires on its day only, and its stamp is the day, so a
      # 45-second loop cannot fire it twice on that day. A day the scheduler cannot read never
      # reaches here: it fails `at_valid` above and is NAMED in state/.cron-invalid.
      if [ -n "$dow" ]; then
        dow_matches "$dow" || continue
      fi
      if [ -n "$gate" ]; then
        _match=0
        for _w in $(printf "%s" "${gate#@}" | tr "," " "); do
          case ",${BROKK_ROLES:-dev}," in *",$_w,"*) _match=1 ;; esac
        done
        # The forge fallback (plan 365): a row gated for the forge runs on the heart when the forge has
        # been dark for more than 24 hours, so the record keeps its nightly work. The heart logs the row
        # as usual; `ymir nornir` names it MOVED while the forge is away.
        if [ "$_match" = 0 ]; then
          case ",$(printf "%s" "${gate#@}" | tr " " ","),:,${BROKK_ROLES:-dev}," in
            *,forge,*:*,heart,*)
              bash "$root/bin/time/forge-dark.sh" --state "$state" >/dev/null 2>&1 && _match=1 ;;
          esac
        fi
        [ "$_match" = 1 ] || continue
      fi
      key=$(printf "%s" "$cmd" | tr -c "A-Za-z0-9._-" "_")
      stamp="$stamp_dir/$key"
      if [ -r "$stamp" ] && [ "$(cat "$stamp" 2>/dev/null)" = "$stamp_key" ]; then continue; fi
      printf "%s\n" "$stamp_key" >"$stamp"
      ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      printf "%s cron run: %s\n" "$ts" "$cmd" >>"$log"
      lock="$lock_dir/$key.lock"
      if command -v flock >/dev/null 2>&1; then
        ( flock -n 8 || { printf "%s cron skip (busy): %s\n" "$ts" "$cmd" >>"$log"; exit 0; }
          run_row
        ) 8>>"$lock" &
      else
        ( run_row ) &
      fi
    done <"$config"
    [ "${BROKK_CRON_ONCE:-0}" = 1 ] && exit 0
    nap "${BROKK_CRON_TICK:-45}"
  done
'

case "${1-}" in
  --status)
    refused=$(lock_to_watch "$STATE"); refused=${refused#*$'\t'}
    [ -n "$refused" ] && printf 'cron: WARNING — %s\n' "$refused" >&2
    invalid=0
    [ -r "$STATE/.cron-invalid" ] && invalid=$(grep -c . "$STATE/.cron-invalid" 2>/dev/null || printf '0')
    extra=""; [ "${invalid:-0}" != 0 ] && extra=" invalid=$invalid"
    if pid=$(running_pid); then
      printf 'cron: running pid=%s jobs=%s%s\n' "$pid" "$(job_count)" "$extra"
    else
      printf 'cron: stopped jobs=%s%s\n' "$(job_count)" "$extra"
    fi
    exit 0
    ;;
  --last)
    # Per-job last run, read from THIS seat's own log (plan 365): the one fact the status resolver
    # (bin/time/nornir-status.sh) asks every owning seat for, over the ssh ring or locally.
    if pid=$(running_pid); then _st="running	$pid"; else _st="stopped	"; fi
    printf '#state\t%s\n#now\t%s\t%s\n#log\t%s\n' "$_st" "$(date +%s)" "$(date +%z)" "$LOG_FILE"
    [ -r "$LOG_FILE" ] && tail -n 60000 "$LOG_FILE" | awk '
      / cron run: /  { ts=$1; c=$0; sub(/^[^ ]+ cron run: /,"",c); run[c]=ts; cur=c; want=1; next }
      / cron FAIL rc=/ { ts=$1; c=$0; sub(/^[^ ]+ cron FAIL rc=/,"",c); rc=c; sub(/ .*/,"",rc); sub(/^[0-9]+ /,"",c); sub(/ :: .*/,"",c);
                         fail[c]=ts; frc[c]=rc; want=0; next }
      / cron SKIP /  { want=0; next }
      /^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]+Z cron / { next }
      want && cur != "" && !(cur in note) && length($0) { note[cur]=substr($0,1,90); want=0 }
      END { for (c in run) printf "%s\t%s\t%s\t%s\t%s\n", c, run[c], (c in fail ? fail[c] : ""), (c in frc ? frc[c] : ""), (c in note ? note[c] : "") }'
    exit 0
    ;;
  --stop)
    why=""; [ "${2-}" = "--why" ] && why="${3-}"
    if pid=$(running_pid); then
      who="pid=$PPID ($(ps -o command= -p "$PPID" 2>/dev/null | cut -c1-120))"
      # While a session holds the lock, only that session, the unit's own ExecStop (a child of the systemd
      # manager) or a caller that states why may stop the clock. Every stop and refusal is logged.
      if [ -z "$why" ] && [ "$(ps -o comm= -p "$PPID" 2>/dev/null)" != systemd ] && foreign_owner >/dev/null; then
        printf '%s cron stop REFUSED for %s: session pid %s holds the lock\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$who" "$(foreign_owner)" >>"$LOG_FILE"
        printf 'cron[1]{state,why}:\n  "refused","session pid %s holds the lock; to stop the clock anyway: %s --stop --why \\"<reason>\\""\n' "$(foreign_owner)" "$0" >&2
        exit 1
      fi
      [ -n "$why" ] || why=$([ "$(ps -o comm= -p "$PPID" 2>/dev/null)" = systemd ] && echo "unit stop" || echo "session or no live lock")
      printf '%s cron stop of pid %s by %s: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$pid" "$who" "$why" >>"$LOG_FILE"
      kill "$pid" 2>/dev/null || true
      rm -f "$PID_FILE"
      printf 'cron: stopped pid=%s\n' "$pid"
    else
      rm -f "$PID_FILE" 2>/dev/null || true
      printf 'cron: already stopped\n'
    fi
    exit 0
    ;;
esac

if pid=$(running_pid); then
  printf 'cron: running pid=%s jobs=%s\n' "$pid" "$(job_count)"
  exit 0
fi

jobs=$(job_count)
if [ "$jobs" = "0" ]; then
  printf 'cron: no jobs configured (%s absent or empty)\n' "$CRON_CONFIG"
  exit 0
fi

# Name every line whose schedule shape the scheduler does not understand, BEFORE the
# loop starts. A row that cannot be read is a job that will never fire, and this house
# has already paid once for a declared-but-dead schedule (2026-09-24).
_bad=$(
  grep -vE '^[[:space:]]*(#|$)' "$CRON_CONFIG" 2>/dev/null | while IFS= read -r _l; do
    _p=$(parse_line "$_l")
    _rest=${_p#*	}
    _at=${_rest%%	*}
    _rest=${_rest#*	}
    _dow=${_rest%%	*}
    { at_valid "$_at" && { [ -z "$_dow" ] || is_dow "$_dow"; }; } || printf '%s\n' "$_l"
  done
)
if [ -n "$_bad" ]; then
  printf 'cron: WARNING — %s line(s) carry a schedule shape Nornir does not understand, and will NOT fire:\n' "$(printf '%s\n' "$_bad" | grep -c .)" >&2
  printf '%s\n' "$_bad" | sed 's/^/  /' >&2
  printf 'cron: shapes are HH:MM · @hourly · @hourly:MM · @daily · @every:N · Mon|Mon,Fri HH:MM (after or before the @role gate)\n' >&2
fi
unset _bad _l _p _at _dow _rest

mkdir -p "$STAMP_DIR" "$LOCK_DIR"
rotate_log

# This machine's roles (plan 51): the scheduler runs only the jobs its roles own.
# Read from the topology resolver; default to `dev` when there is no registry, so
# an unconfigured box runs only ungated jobs (and never a heart's record jobs).
if [ -z "${BROKK_ROLES:-}" ]; then
  _roles="dev"
  if [ -x "$SCRIPT_DIR/../fleet/topology.sh" ]; then
    _roles="$(bash "$SCRIPT_DIR/../fleet/topology.sh" --json 2>/dev/null \
      | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: d={}
print(",".join(d.get("roles") or ["dev"]))' 2>/dev/null)"
    [ -n "$_roles" ] || _roles="dev"
  fi
  BROKK_ROLES="$_roles"
  unset _roles
fi
export BROKK_ROLES

if command -v setsid >/dev/null 2>&1; then
  setsid bash -c "$scheduler" _ "$CRON_CONFIG" "$LOG_FILE" "$STATE" "$BROKK_HOME" "$CONFIG" "$ROOT" >>"$LOG_FILE" 2>&1 &
else
  nohup bash -c "$scheduler" _ "$CRON_CONFIG" "$LOG_FILE" "$STATE" "$BROKK_HOME" "$CONFIG" "$ROOT" >>"$LOG_FILE" 2>&1 &
fi
loop_pid=$!
printf '%s\n' "$loop_pid" >"$PID_FILE"
# A state override leaves the default state dir with an old log nobody writes (the heart read it and called
# the clock dead, 2026-11-24). Say where the live log is, there, once per start.
_def_state="${XDG_STATE_HOME:-$HOME/.local/state}/ymir"
if [ "$_def_state" != "$STATE" ] && [ -d "$_def_state" ]; then printf '%s\n' "$LOG_FILE" >"$_def_state/cron.log.now" 2>/dev/null || true; fi
printf 'cron: started pid=%s jobs=%s\n' "$loop_pid" "$jobs"
