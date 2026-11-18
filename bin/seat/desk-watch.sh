#!/usr/bin/env bash
# desk-watch.sh — a desk restart is noticed, and its hands are either raised or NAMED.
#
# Why (plan 001 §4 F2, measured 2026-11-17): the desk was restarted by systemd after an OOM kill and
# 27 panes came back as bare shells while `herdr agent list` still said *idle*. Nothing noticed, so
# nothing repaired it — his conversation was gone and the machine claimed everyone was present.
#
# This is the second half of that failsafe: `desk-inventory.sh` writes down who stood where, and this
# door reads the machine (not the desk) and does ONE of two things:
#
#   · re-raises the lost panes as agents, resuming the session file the inventory recorded — bounded
#     by `--limit`, because 27 hands raised at once would swap the machine to death, which is the
#     fault it repairs; or
#   · when it cannot (no herdr, no session file, no cwd, or the limit is spent), says every lost pane
#     in ONE line, so the operator learns it once instead of discovering it hours later.
#
# Usage:
#   desk-watch.sh check [--notify]        # the verdict, and with --notify one message to the Allfather
#   desk-watch.sh raise [--limit N] [--dry-run]   # re-raise lost panes (default limit 1)
#   desk-watch.sh watch [--limit N]       # check, raise up to the limit, then notify if any remain
#   desk-watch.sh --version
#
# Env:
#   YMIR_DESK_RAISE_CMD   the command a pane runs, with @SESSION@, @CWD@ and @PANE@ placeholders
#                         (default: the scoped pi resume the runbook names)
#   YMIR_DESK_INVENTORY   the snapshot (default: <state>/desk-inventory.json)
#
# Exit: 0 nothing lost · 1 something is lost (and this run did not put it back) · 2 usage.
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
INVENTORY="${YMIR_DESK_INVENTORY:-$YMIR_STATE_DIR/desk-inventory.json}"
export YMIR_DESK_INVENTORY="$INVENTORY"

# The resume command: the runbook's own words (`the-desk.md` §3), scoped so a re-raised hand is in its
# own cgroup (F1). A machine may override it; nothing here guesses a session or a model.
RAISE_CMD="${YMIR_DESK_RAISE_CMD:-$ROOT/bin/seat/agent-scope.sh -- pi --session @SESSION@}"

usage() { sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

ACTION="${1:-check}"; shift || true
# `save`/`show`/`lost` belong to desk-inventory.sh; `install-units` is the cadence half of this door.
if [ "$ACTION" = "install-units" ]; then
  # THE UNIT IS THE REGISTER'S, never a heredoc here (plan 269): `config/units.yaml` carries the entry
  # and `bin/engine/units.sh` is the one writer that renders it against the PINNED runtime. A hand-written
  # unit would run from the worktree it was installed out of, and would survive the next update as drift.
  UNITS="$ROOT/bin/engine/units.sh"
  [ -x "$UNITS" ] || { printf 'error: the unit writer is missing (%s)\n' "$UNITS" >&2; exit 1; }
  bash "$UNITS" write desk-failsafe --render
  printf 'enable it: systemctl --user daemon-reload && systemctl --user enable --now desk-failsafe.timer\n'
  exit 0
fi
case "$ACTION" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) usage 0 ;;
  check|lost|show|install-units) ;;
  *) usage 2 ;;
esac

NOTIFY=0; LIMIT=1; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --notify) NOTIFY=1; shift ;;
    --limit) LIMIT="${2:-1}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    *) printf 'error: unknown flag %s\n' "$1" >&2; exit 2 ;;
  esac
done

# The lost rows, as `pane<TAB>session<TAB>cwd<TAB>why`. The door's own TSV face is used, not a parse of
# its prose: a count line read as a row is how a watcher reports two lost hands when it lost one.
lost_rows() { YMIR_DESK_TSV=1 bash "$SCRIPT_DIR/desk-inventory.sh" lost 2>/dev/null | awk -F'\t' 'NF>=4 && $1!=""'; }

# ONE LINE, because the plan asks for one message: what is lost, how many, and what still stands.
compose_line() {
  local rows=$1 count; count="$(printf '%s\n' "$rows" | grep -c . || true)"
  [ "${count:-0}" -gt 0 ] || { printf 'the desk is whole — every pane the inventory recorded still holds its agent'; return 0; }
  local names; names="$(printf '%s\n' "$rows" | cut -f1 | tr '\n' ' ' | sed 's/ *$//')"
  local live; live="$(bash "$SCRIPT_DIR/desk-inventory.sh" check 2>/dev/null | sed -n 's/^  "\([0-9]*\)","\([0-9]*\)","\([0-9]*\)"$/\2/p' | tail -1)"
  printf 'the desk lost %s hand(s) to a restart — panes %s hold shells, not agents; %s agent(s) still stand' \
    "$count" "$names" "${live:-0}"
}

check_lost() {
  local rows; rows="$(lost_rows)"
  if [ -z "$rows" ]; then
    printf 'desk-watch[1]{verdict,lost,line}:\n  "whole","0","%s"\n' "$(compose_line "")"
    return 0
  fi
  local count; count="$(printf '%s\n' "$rows" | grep -c .)"
  printf 'desk-watch[1]{verdict,lost,line}:\n  "lost","%s","%s"\n' "$count" "$(compose_line "$rows")"
  printf 'desk-watch-lost[]{pane,session,cwd,why}:\n'
  printf '%s\n' "$rows" | while IFS=$'\t' read -r pane session cwd why; do
    printf '  "%s","%s","%s","%s"\n' "$pane" "$session" "$cwd" "$why"
  done
  return 1
}

notify_lost() {
  local line; line="$(compose_line "$(lost_rows)")"
  [ -n "$line" ] || return 0
  bash "$ROOT/bin/seat/desk-notify.sh" --kind panes-lost --message "$line" 2>/dev/null \
    || printf 'desk-watch: the notifier did not answer — the line stands here: %s\n' "$line" >&2
}

# raise_lost — put hands back, bounded. Never touches a pane that a live agent already holds: only the
# rows `lost` reports are raised, and those are, by definition, shells.
raise_lost() {
  local rows; rows="$(lost_rows)"
  [ -n "$rows" ] || { printf 'desk-watch-raise[1]{raised,skipped,note}:\n  "0","0","nothing is lost"\n'; return 0; }
  local raised=0 skipped=0 pane session cwd why cmd
  while IFS=$'\t' read -r pane session cwd why; do
    [ -n "$pane" ] || continue
    if [ "$raised" -ge "$LIMIT" ]; then
      skipped=$((skipped + 1)); continue
    fi
    if [ -z "$session" ] || [ ! -r "$session" ]; then
      skipped=$((skipped + 1)); continue
    fi
    if [ -n "$cwd" ] && [ ! -d "$cwd" ]; then
      skipped=$((skipped + 1)); continue
    fi
    cmd="$RAISE_CMD"
    cmd="${cmd//@SESSION@/$session}"
    cmd="${cmd//@CWD@/$cwd}"
    cmd="${cmd//@PANE@/$pane}"
    if [ "$DRY" = "1" ]; then
      printf 'would raise: %s — cd %s — %s\n' "$pane" "${cwd:-?}" "$cmd"
      raised=$((raised + 1)); continue
    fi
    # `herdr-run.sh run` is the one door that seats a command in a pane; it quotes every argument.
    if ( cd "${cwd:-$HOME}" 2>/dev/null || exit 1; bash "$ROOT/bin/seat/herdr-run.sh" run "resume:$pane" -- bash -lc "$cmd" ) >/dev/null 2>&1; then
      raised=$((raised + 1))
    else
      skipped=$((skipped + 1))
    fi
  done <<<"$rows"
  printf 'desk-watch-raise[1]{raised,skipped,limit}:\n  "%s","%s","%s"\n' "$raised" "$skipped" "$LIMIT"
  [ "$raised" -gt 0 ] && return 0
  return 1
}

case "$ACTION" in
  check)
    rc=0; check_lost || rc=1
    [ "$NOTIFY" = "1" ] && [ "$rc" -ne 0 ] && notify_lost
    exit "$rc" ;;
  raise)
    raise_lost; exit $? ;;
  watch)
    rc=0
    raise_lost >/dev/null 2>&1 || true
    check_lost || rc=1
    [ "$rc" -ne 0 ] && notify_lost
    exit "$rc" ;;
esac
