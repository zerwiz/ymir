#!/usr/bin/env bash
# seat-prove.sh — a spawn is not a seat until the agent list shows it.
#
# Measured 2026-11-05 (plan 190 §4.1): `einherjar-spawn.sh` printed
# `spawned … target=wQ:p1` for an errand whose pane held a bare shell while the
# agent had come up somewhere else, and three errands died the same way while
# their records claimed a seat. A pane is not an agent (plan 189 §18.2); only
# `herdr agent list` shows a worker. This door asks that one question, through
# the one reader (bin/seat/herdr-agents.py), for every road that seats: the
# spawner's shell road AND the engine (src/ymir_runtime) — so an unproven seat
# fails in both, and neither can claim a worker it never saw.
#
# Usage:
#   seat-prove.sh <pane> <cwd> [--backend herdr|tmux] [--settle SECONDS]
#
# Prints `<pane>\t<state>` on success and exits 0. The pane it prints is the pane
# the agent ACTUALLY stands in — which may differ from the pane the caller chose;
# when it does, the finding says so and the caller must record the printed one.
#
# Exit: 0 proven · 1 unproven (the finding names pane, cwd and the wait) · 2 usage.
set -u
VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
READER="$SCRIPT_DIR/herdr-agents.py"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

PANE="${1-}"; CWD="${2-}"; shift 2 2>/dev/null || true
BACKEND="herdr"
# THE ONE DEFAULT (the Allfather, 2026-11-10: "make the seat-prove wait LONGER",
# then corrected the same evening to sixty seconds). 25 s was shorter than a pi boot
# on a loaded rail, so a live seat was read as `no agent`, the errand recorded
# failed, and its arm was never armed. Every road — the spawner and the engine —
# passes `--settle` only when the operator set YMIR_SEAT_SETTLE, so this value is
# the shipped truth and there is not a second copy of it to drift.
SETTLE="${YMIR_SEAT_SETTLE:-60}"
while [ $# -gt 0 ]; do
  case "$1" in
    --backend) BACKEND="${2-}"; shift 2 ;;
    --settle) SETTLE="${2-}"; shift 2 ;;
    *) printf 'error: unknown flag %s\n' "$1" >&2; exit 2 ;;
  esac
done
[ -n "$PANE" ] && [ -n "$CWD" ] || {
  printf 'error: seat-prove needs a pane and a cwd\nhelp: seat-prove.sh <pane> <cwd> [--backend herdr|tmux] [--settle N]\n' >&2
  exit 2
}

# A worker queued on the local-model lock is ALIVE, not absent (measured 2026-11-04):
# the rail serves one resident model, so a second errand waits on
# bin/model/local-model-lock.sh before its pi ever starts. This door used to read that
# wait as "no agent" and fail a worker that was about to boot. While such a waiter
# stands in the worktree the clock is RESET, so the wait is bounded by progress and
# not by the wall.
lock_waiters() {  # <worktree> — pids waiting on the local-model lock in that tree
  local wt=$1 pid found=""
  for pid in /proc/[0-9]*; do
    [ "$(readlink "$pid/cwd" 2>/dev/null)" = "$wt" ] || continue
    tr '\0' ' ' <"$pid/cmdline" 2>/dev/null | grep -qE 'local-model[.-]lock' || continue
    found="$found ${pid#/proc/}"
  done
  printf '%s' "${found# }"
}

queued=0
deadline=$(( $(date +%s) + SETTLE ))
while :; do
  if [ "$BACKEND" = tmux ]; then
    cmd=$(tmux list-panes -t "$PANE" -F '#{pane_current_command}' 2>/dev/null | head -1)
    case "$cmd" in
      pi|pi-signed|node|opencode|bun|deno)
        printf '%s\tforeground:%s\n' "$PANE" "$cmd"; exit 0 ;;
    esac
  else
    if command -v herdr >/dev/null 2>&1 && [ -r "$READER" ]; then
      hit=$(python3 "$READER" --find --pane "$PANE" 2>/dev/null)
      if [ -z "$hit" ]; then hit=$(python3 "$READER" --find --cwd "$CWD" 2>/dev/null); fi
      if [ -n "$hit" ]; then
        printf '%s\n' "$hit"
        found_pane=${hit%%$'\t'*}
        if [ "$found_pane" != "$PANE" ]; then
          printf 'seat-prove: the agent stands in %s, not in the pane %s this spawn chose — record the printed pane\n' \
            "$found_pane" "$PANE" >&2
        fi
        exit 0
      fi
    fi
  fi
  [ "$(date +%s)" -ge "$deadline" ] && break
  waiters="$(lock_waiters "$CWD")"
  if [ -n "$waiters" ]; then
    queued=1
    deadline=$(( $(date +%s) + SETTLE ))   # a queued worker is a worker on its way
    printf 'seat-prove: queued on the local-model lock (%s) — still waiting, this is not a dead seat\n' "$waiters" >&2
  fi
  sleep 2
done

if [ "$BACKEND" = tmux ]; then
  printf 'seat-prove: no agent in tmux pane %s after %ss%s (the pane holds no foreground harness)\n' \
    "$PANE" "$SETTLE" "$([ "$queued" = 1 ] && echo ', though it was queued on the model lock')" >&2
else
  printf 'seat-prove: no agent in pane %s after %ss%s, and none with foreground cwd %s (herdr agent list)\n' \
    "$PANE" "$SETTLE" "$([ "$queued" = 1 ] && echo ', though it was queued on the model lock')" "$CWD" >&2
fi
exit 1
