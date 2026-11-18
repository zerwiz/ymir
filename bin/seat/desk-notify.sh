#!/usr/bin/env bash
# desk-notify.sh — the death is SPOKEN: one line to the Allfather, not a discovery hours later.
#
# Why (plan 001 §4 F5, measured 2026-11-17): the desk's OOM death at 07:20:59 was found because he
# asked about it hours later. Nothing on the machine said a word — though the kernel, systemd and the
# panes had each recorded the whole thing. A machine that dies in silence is a machine that lies by
# omission.
#
# Three deaths are worth one line each, and they are read from the machine's own record:
#
#   oom        the kernel killed a process        `journalctl -k` — "Out of memory: Killed process"
#   oom-kill   a unit failed with result 'oom-kill' `journalctl` — systemd's own verdict
#   panes-lost a restart left panes as shells      `bin/seat/desk-watch.sh check`
#
# ONE message per event, and never two: the composed line is hashed into a durable `seen` file, so a
# replay of the same event is `suppressed` and says so. `bin/notify/send.sh` is the one door that
# speaks (Runes, the arm, the desktop, the pocket and Telegram) — this door only decides WHAT to say.
#
# Usage:
#   desk-notify.sh check [--since T] [--until T] [--dry-run]
#         read the machine's record for the window (default: the last 15 minutes), compose the one
#         line, and send it unless it has already been said
#   desk-notify.sh --kind panes-lost --message "<one line>" [--dry-run]
#         say a line another door composed (desk-watch does this), still exactly once
#   desk-notify.sh replay [--since T] [--until T] [--dry-run]
#         the same read over a KNOWN window — how the 07:21 event is replayed against this door
#   desk-notify.sh --version
#
# Env:
#   YMIR_DESK_NOTIFY_SEEN   the record of what has been said (default: <state>/desk-notify.seen)
#   YMIR_DESK_UNIT          the desk unit (default: herdr-server.service)
#
# Exit: 0 said, or deliberately suppressed (the output names which) · 1 nothing to say · 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

if [ -z "${YMIR_STATE_DIR:-}" ] && [ -r "$ROOT/bin/vault/hoard-lib.sh" ]; then
  # shellcheck source=../vault/hoard-lib.sh
  . "$ROOT/bin/vault/hoard-lib.sh"
  hoard_state_dir YMIR_STATE_DIR 2>/dev/null || true
fi
[ -n "${YMIR_STATE_DIR:-}" ] || YMIR_STATE_DIR="$HOME/.local/state/ymir"
SEEN="${YMIR_DESK_NOTIFY_SEEN:-$YMIR_STATE_DIR/desk-notify.seen}"
UNIT="${YMIR_DESK_UNIT:-herdr-server.service}"

usage() { sed -n '2,34p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
have() { command -v "$1" >/dev/null 2>&1; }

ACTION="${1:-check}"; [ $# -gt 0 ] && shift || true
case "$ACTION" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) usage 0 ;;
  check|replay|--kind) ;;
  *) usage 2 ;;
esac

KIND="auto"; MESSAGE=""; SINCE=""; UNTIL=""; DRY=0
if [ "$ACTION" = "--kind" ]; then
  KIND="${1:-auto}"; shift || true
fi
while [ $# -gt 0 ]; do
  case "$1" in
    --kind) KIND="${2:-auto}"; shift 2 ;;
    --message) MESSAGE="${2:-}"; shift 2 ;;
    --since) SINCE="${2:-}"; shift 2 ;;
    --until) UNTIL="${2:-}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    *) printf 'error: unknown flag %s\n' "$1" >&2; exit 2 ;;
  esac
done

# ── the record, read once ─────────────────────────────────────────────────────
# The window is the caller's; a check with no window is "what happened since the last look", which for
# a cron-driven door is the last 15 minutes.
if [ -z "$SINCE" ]; then
  if have date && date -d '-15 minutes' +%Y-%m-%dT%H:%M:%S >/dev/null 2>&1; then
    SINCE="$(date -d '-15 minutes' +%Y-%m-%dT%H:%M:%S)"
  else
    SINCE="-15min"
  fi
fi

journal_window() {  # <extra args...>
  have journalctl || return 0
  local args=(--no-pager --output=short-iso --since "$SINCE")
  [ -n "$UNTIL" ] && args+=(--until "$UNTIL")
  journalctl "${args[@]}" "$@" 2>/dev/null
}

# oom_facts — the kernel's own sentence: which process, which cgroup, when.
oom_facts() {
  journal_window -k 2>/dev/null | grep -E "Out of memory: Killed process" | tail -3
}

# unit_facts — systemd's verdict on a unit: 'Failed with result oom-kill'.
unit_facts() {
  journal_window 2>/dev/null | grep -E "Failed with result 'oom-kill'" | tail -3
}

# panes_facts — the shells a restart left behind, counted by the one door that asks the machine.
panes_facts() {
  bash "$SCRIPT_DIR/desk-watch.sh" check 2>/dev/null | sed -n 's/^desk-watch\[1\]{verdict,lost,line}:$//p; s/^  "\(lost\|whole\)","\([0-9]*\)","\(.*\)"$/\2\t\3/p'
}

compose() {
  local oom unit_lines panes parts="" count=0
  oom="$(oom_facts)"; unit_lines="$(unit_facts)"
  case "$KIND" in
    oom|auto) ;;
  esac
  if [ -n "$oom" ]; then
    local proc where when
    proc="$(printf '%s\n' "$oom" | sed -n 's/.*Killed process \([0-9]*\) (\([^)]*\)).*/\2 (pid \1)/p' | tail -1)"
    where="$(printf '%s\n' "$oom" | sed -n 's/.*task_memcg=\([^,]*\).*/\1/p' | tail -1 | sed 's#.*/##')"
    when="$(printf '%s\n' "$oom" | sed -nE 's/^([0-9T:+.-]+) .*/\1/p' | tail -1 | sed 's/T/ /; s/+.*//')"
    parts="the kernel OOM killer took ${proc:-a process}"
    [ -n "$where" ] && parts="$parts inside $where"
    [ -n "$when" ] && parts="$parts at $when"
    count=$((count + 1))
  fi
  if [ -n "$unit_lines" ]; then
    local units
    units="$(printf '%s\n' "$unit_lines" | sed -nE 's/.* ([a-zA-Z0-9@._-]+\.service): Failed with result .*/\1/p' | sort -u | tr '\n' ' ' | sed 's/ *$//')"
    if [ -n "$units" ]; then
      parts="${parts:+$parts; }systemd failed with result oom-kill: $units"
      count=$((count + 1))
    fi
  fi
  if [ "$KIND" = "auto" ] || [ "$KIND" = "panes-lost" ]; then
    panes="$(panes_facts)"
    if [ -n "$panes" ]; then
      local n line; n="$(printf '%s\n' "$panes" | cut -f1 | tail -1)"; line="$(printf '%s\n' "$panes" | cut -f2 | tail -1)"
      case "${n:-0}" in ''|0) ;; *)
        parts="${parts:+$parts; }$line"
        count=$((count + 1)) ;;
      esac
    fi
  fi
  [ -n "$parts" ] || return 1
  printf '%s' "$parts"
}

# ── say it exactly once ───────────────────────────────────────────────────────
say_once() {  # <kind> <line>
  local kind=$1 line=$2 key
  key="desk:$(printf '%s|%s|%s' "$kind" "$line" "${UNTIL:-open}" | sha256sum | cut -c1-16)"
  touch "$SEEN" 2>/dev/null || true
  if grep -qxF "$key" "$SEEN" 2>/dev/null; then
    printf 'desk-notify[1]{verdict,key,line}:\n  "suppressed — already said","%s","%s"\n' "$key" "$line"
    return 0
  fi
  if [ "$DRY" = "1" ]; then
    printf 'desk-notify[1]{verdict,key,line}:\n  "would say (dry run)","%s","%s"\n' "$key" "$line"
    return 0
  fi
  # A SINK for a test and for a replay: when it is set the message is appended there instead of being
  # handed to the one door that speaks. A proof that sends a real alarm is not a proof, it is an alarm.
  if [ -n "${YMIR_DESK_NOTIFY_SINK:-}" ]; then
    printf '%s\t%s\n' "$key" "$line" >>"$YMIR_DESK_NOTIFY_SINK"
    printf '%s\n' "$key" >>"$SEEN"
    printf 'desk-notify[1]{verdict,key,sink,line}:\n  "said — one message (sink)","%s","%s","%s"\n' "$key" "$YMIR_DESK_NOTIFY_SINK" "$line"
    return 0
  fi
  if bash "$ROOT/bin/notify/send.sh" --source ward --severity CRITICAL --key "$key" \
       --message "the desk on $(hostname -s 2>/dev/null || hostname): $line" --target "log:journalctl -b -0" >/dev/null 2>&1; then
    printf '%s\n' "$key" >>"$SEEN"
    printf 'desk-notify[1]{verdict,key,line}:\n  "said — one message","%s","%s"\n' "$key" "$line"
    return 0
  fi
  printf 'desk-notify[1]{verdict,key,line}:\n  "NOT DELIVERED","%s","%s"\n' "$key" "$line" >&2
  return 1
}

if [ -n "$MESSAGE" ]; then
  say_once "${KIND}" "$MESSAGE"; exit $?
fi

LINE="$(compose)" || { printf 'desk-notify[1]{verdict,line}:\n  "nothing to say","no OOM kill, no oom-kill failure and no lost pane in the window"\n'; exit 1; }
say_once "auto" "$LINE"
