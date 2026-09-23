#!/usr/bin/env bash
# eindri-handoff.sh — the handoff failsafe. An Eindri's work ALWAYS reaches Brokk.
#
# The fast road is the when-adapter (eindri-seen.sh → eindri-acclaim.sh, driven
# by .agents/backend/fm-procevent.sh). It is good, and it can fail three ways we
# have actually seen:
#
#   1. the poller is not running           → nothing fires, ever
#   2. the arm wrote its spec into a
#      worktree instead of the hoard       → written, then deleted
#   3. nobody looked                       → the report sat on the shelf
#
# A handoff that depends on one poller alive is not a handoff. This is the SLOW
# road that cannot be missed: it sweeps the report and question shelves for
# anything NOT yet delivered to Brokk and puts it in the wake queue, so Sága's
# drain surfaces it in the very next session digest. It is idempotent — one
# delivery marker per item, so a second sweep never re-fires old news.
#
#   eindri-handoff.sh sweep     # deliver everything undelivered (the failsafe)
#   eindri-handoff.sh status    # what is waiting, without delivering
#
# Exit: 0 nothing waited (or all delivered), 3 something WAS waiting and is now
# delivered, 1 error, 2 usage. `3` means "there was a miss, and it is fixed".
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/hoard-lib.sh" "$(dirname "$SCRIPT_DIR")/bin/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
fi
hoard_state_dir YMIR_STATE_DIR
STATE="${BROKK_STATE_OVERRIDE:-$YMIR_STATE_DIR}"
QUEUE="$STATE/.wake-queue"
DELIVERED="$STATE/eindri-handoff"          # the per-item delivery markers

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION="${1:-sweep}"; shift || true

mkdir -p "$STATE/eindri-reports" "$STATE/eindri-questions" "$DELIVERED" 2>/dev/null || true

# The shelf an item sits on, its name, and the kind the wake should carry.
# A question needs an ANSWER; a report needs a REVIEW. They never share a marker.
waiting_items() {
  local f name
  for f in "$STATE/eindri-questions"/*.md; do
    [ -f "$f" ] || continue
    name="$(basename "$f" .md)"
    [ -f "$DELIVERED/$name.question" ] && continue
    printf 'QUESTION\t%s\t%s\n' "$name" "$f"
  done
  for f in "$STATE/eindri-reports"/*.md; do
    [ -f "$f" ] || continue
    name="$(basename "$f" .md)"
    [ -f "$DELIVERED/$name.report" ] && continue
    printf 'REPORT\t%s\t%s\n' "$name" "$f"
  done
}

count_waiting() { waiting_items | grep -c . || true; }

deliver() {  # <kind> <name> <path>
  local kind=$1 name=$2 path=$3 mark line
  case "$kind" in
    QUESTION) mark="$DELIVERED/$name.question"
              line="eindri $name QUESTION: $path — answer with bin/eindri-send.sh $name \"…\" (handoff failsafe)" ;;
    *)        mark="$DELIVERED/$name.report"
              line="eindri $name reported: report filed at $path (handoff failsafe)" ;;
  esac
  printf '%s\n' "$line" >>"$QUEUE"
  printf '%s %s delivered %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$name" "$kind" >"$mark"
  if [ -x "$SCRIPT_DIR/ymir-say.sh" ]; then
    [ "$kind" = "QUESTION" ] && "$SCRIPT_DIR/ymir-say.sh" alarm "Eindri $name asks — answer it" >/dev/null 2>&1 \
                            || "$SCRIPT_DIR/ymir-say.sh" note "Eindri $name reported" >/dev/null 2>&1
  fi
}

case "$ACTION" in
  status)
    n="$(count_waiting)"
    printf 'eindri-handoff[1]{action,waiting,state}:\n  "status",%s,"%s"\n' \
      "$n" "$([ "$n" -gt 0 ] && echo 'undelivered work on the shelf' || echo 'nothing waiting')"
    waiting_items | while IFS=$'\t' read -r k a p; do printf '  "%s","%s","%s"\n' "$k" "$a" "$p"; done
    [ "$n" -gt 0 ] && exit 3
    exit 0 ;;

  sweep|"")
    delivered=0
    # Collect first, then deliver — a marker written mid-iteration would shift
    # the glob under us.
    while IFS=$'\t' read -r kind name path; do
      [ -n "${kind:-}" ] || continue
      deliver "$kind" "$name" "$path"
      delivered=$((delivered + 1))
    done < <(waiting_items)

    printf 'eindri-handoff[1]{action,delivered,state}:\n  "sweep",%s,"%s"\n' \
      "$delivered" "$([ "$delivered" -gt 0 ] && echo 'undelivered work was waiting — now in the wake queue' || echo 'nothing was waiting')"
    [ "$delivered" -gt 0 ] && exit 3
    exit 0 ;;

  *)
    printf 'error: unknown action %s (sweep|status)\n' "$ACTION" >&2; exit 2 ;;
esac
