#!/usr/bin/env bash
# plan-card-after.sh — after a plan is made or appended, bring its card on the board up to date (plan 335, item 5).
#
#   plan-card-after.sh <plan-file>…      # absolute, or relative to the home; anything not a plan is ignored
#
# Called by the plan tools themselves — bin/records/plan.sh new, bin/records/note.sh, bin/vault/home-sync.sh ship —
# so the board stays current on every seat without anyone remembering to run the sync.
#
# What it says, always by name (never a silent skip):
#   plan-card: plan <N> → <place>: syncing in the background (log: <path>)
#   plan-card: plan <N>: no road to the board on this seat — <why>
#   plan-card: <file>: <why its project has no board>
#   plan-card: off on this seat (YMIR_PLAN_CARD=0)
# The road is checked in the foreground (fast); the sync itself runs detached, so the tool that called this is not
# held while the board draws diagrams. The sync is idempotent, so two calls for one plan cost nothing extra.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
[ $# -gt 0 ] || exit 0
if [ "${YMIR_PLAN_CARD:-1}" = "0" ]; then echo "plan-card: off on this seat (YMIR_PLAN_CARD=0)"; exit 0; fi
if [ -z "${YMIR_HOME:-}" ] && [ -r "$ROOT/bin/vault/hoard-lib.sh" ]; then
  . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
  command -v ymir_home_root >/dev/null 2>&1 && ymir_home_root YMIR_HOME 2>/dev/null && export YMIR_HOME
fi
[ -n "${YMIR_HOME:-}" ] || { echo "plan-card: no home on this seat — the board was not touched"; exit 0; }
LOG="${YMIR_PLAN_CARD_LOG:-${XDG_STATE_HOME:-$HOME/.local/state}/ymir/plan-sync.log}"
mkdir -p "$(dirname "$LOG")" 2>/dev/null || true

files=()
for p in "$@"; do
  case "$p" in /*) f="$p" ;; *) f="$YMIR_HOME/$p" ;; esac
  case "$f" in */plans/[0-9]*.md) ;; *) continue ;; esac   # only a numbered plan has a card
  [ -f "$f" ] && files+=("$f")
done
[ ${#files[@]} -gt 0 ] || exit 0

for f in "${files[@]}"; do
  n="$(basename "$f" | grep -oE '^[0-9]+' | sed 's/^0*//')"
  if ! road="$("$HERE/plan-sync.sh" --file "$f" --road 2>&1)"; then
    why="$(printf '%s' "$road" | sed -n 's/^plan-sync: refused — //p' | head -1)"
    case "$why" in
      "no project with a board"*|"the plan shelf"*) echo "plan-card: $(basename "$f"): ${why}" ;;
      *) echo "plan-card: plan ${n:-?}: no road to the board on this seat — ${why:-$road}" ;;
    esac
    continue
  fi
  place="$(printf '%s' "$road" | sed -n 's/.*→ //p' | head -1)"
  { printf '\n== %s plan %s (%s)\n' "$(date -u +%FT%TZ)" "${n:-?}" "$f"; } >>"$LOG"
  setsid nohup "$HERE/plan-sync.sh" --file "$f" >>"$LOG" 2>&1 </dev/null &
  echo "plan-card: plan ${n:-?} → ${place:-its board}: syncing in the background (log: $LOG)"
done
exit 0
