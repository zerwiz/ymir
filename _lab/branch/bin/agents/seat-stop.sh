#!/usr/bin/env bash
# seat-stop.sh — stop a seat WHOLE: every process working in its worktree, not just the pane.
#
# WHY (2026-10-24): closing an errand left a worker waiting on the model lock alive — the
# pane was gone, the process was not, and it had to be killed by hand. The same fault hid
# five orphaned cron loops inside seats. A close that stops a pane and not the work is a
# close that lies.
#
# The test is the WORKTREE, not the process name: anything whose cwd lies inside
# .yggdrasil/<id> belongs to that seat, whatever it is called — a harness, an opencode
# node, a flock waiting for the rail, a scheduler loop.
#
#   seat-stop.sh <errand-id> [--dry-run] [--grace N]
#
# Exit: 0 nothing left running · 1 processes survived · 2 usage.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root _H 2>/dev/null || true
WT_ROOT="$ROOT/.yggdrasil"

ID="${1-}"; shift || true
[ -n "$ID" ] || { printf 'error: seat-stop needs an errand id\nhelp: bin/agents/seat-stop.sh <errand-id> [--dry-run] [--grace N]\n' >&2; exit 2; }
DRY=0; GRACE=5
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --grace) GRACE="${2-5}"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'error: unknown flag %s\n' "$1" >&2; exit 2 ;;
  esac
done

WT="$WT_ROOT/$ID"
printf 'seat-stop[1]{seat,worktree,state}:\n  "%s","%s","%s"\n' "$ID" "$WT" "$([ -d "$WT" ] && echo present || echo absent)"

# Every process whose cwd is the worktree or below it.
_find() {
  local p c
  for p in /proc/[0-9]*; do
    p="${p#/proc/}"
    [ "$p" = "$$" ] && continue
    c="$(readlink "/proc/$p/cwd" 2>/dev/null)" || continue
    case "$c" in
      "$WT"|"$WT"/*) printf '%s\n' "$p" ;;
    esac
  done
}

pids="$(_find)"
n=0; [ -n "$pids" ] && n="$(printf '%s\n' "$pids" | wc -l | tr -d ' ')"
printf 'processes[%s]{pid,cmd}:\n' "$n"
for p in $pids; do
  printf '  "%s","%s"\n' "$p" "$(tr '\0' ' ' <"/proc/$p/cmdline" 2>/dev/null | cut -c1-60)"
done

if [ "$n" = 0 ]; then
  printf 'seat-stop[1]{result}:\n  "clean","nothing was working in %s"\n' "$WT"
  exit 0
fi
if [ "$DRY" = 1 ]; then
  printf 'seat-stop[1]{result}:\n  "dry-run","%s would be stopped"\n' "$n"
  exit 0
fi

# Terminate the harness first (TERM), then anything still standing (KILL), then re-check.
for p in $pids; do kill -TERM "$p" 2>/dev/null || true; done
for _ in $(seq 1 "$GRACE"); do sleep 1; [ -z "$(_find)" ] && break; done
left="$(_find)"
for p in $left; do kill -KILL "$p" 2>/dev/null || true; done
sleep 1
left="$(_find)"
if [ -n "$left" ]; then
  printf 'seat-stop[1]{result,survivors}:\n  "failed","%s"\n' "$(printf '%s' "$left" | tr '\n' ' ')"
  exit 1
fi
printf 'seat-stop[1]{result,stopped}:\n  "clean","%s process(es) in %s"\n' "$n" "$ID"
