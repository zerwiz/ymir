#!/usr/bin/env bash
# saga-wake-drain.sh - present durable Brokk wakes, or acknowledge them.
#
# Sága sees the queue. `drain` (default) prints each durable wake; `ack` drops
# the queues once the wakes have been handled. Ported/trimmed from the upstream
# wake-drain contract for plan 29.
#
# Usage: saga-wake-drain.sh [drain|ack]
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)}"
BROKK_HOME="${BROKK_HOME:-$ROOT}"
# The queue lives in the OPERATOR's state, never the code tree (Rule 04). Resolve
# it exactly as every shell tool does, so a standalone drain sees the same queue
# the watcher fills. It once defaulted to $BROKK_HOME/state (the TREE) and
# reported "0 pending" while the hoard queue held unhandled wakes (2026-09-23).
if [ -z "${BROKK_STATE_OVERRIDE:-}" ]; then
  if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
    for _c in "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/../../vault/hoard-lib.sh"; do
      [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
    done
    unset _c
  fi
  hoard_state_dir _HS 2>/dev/null && BROKK_STATE_OVERRIDE="$_HS"
  unset _HS
fi
STATE="${BROKK_STATE_OVERRIDE:-$BROKK_HOME/state}"

mkdir -p "$STATE"
QUEUE="$STATE/.wake-queue"
# The FM runner's own durable queue (its published check-wakes) lives under the
# .agents home, not the main state. The watcher hollers on BOTH doors; a drain
# that reads only one lets strikes hide in the other. Combine them here.
. "$SCRIPT_DIR/sol-lib.sh"
FMQ="$SCRIPT_DIR/../../state/procevent/.wake-queue"

case "${1:-drain}" in
  -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  ack|--ack)
    # THE HELM OWNS THE ACK (2026-11-11). The home's queue is drained by the session that holds
    # the lock; a second session (another Claude, a stale watcher's rewake) that acks it eats the
    # helm's wakes. When the lease names THIS state dir and a live session holds the lock, only that
    # session may ack. Eindri-homes keep their own state dirs and are untouched. YMIR_ACK_ANY=1 is
    # the loud override.
    _lease="$STATE/.arm.lease"
    if [ -z "${YMIR_ACK_ANY:-}" ] && [ -r "$_lease" ] && grep -qE "(^| )state=$STATE( |$)" "$_lease" 2>/dev/null; then
      _owner="$(bash "$SCRIPT_DIR/../records/ymir-state.sh" lock owner 2>/dev/null | tr -d '[:space:]')"
      if [ -n "$_owner" ] && [ -d "/proc/$_owner" ] \
         && ! bash "$SCRIPT_DIR/../records/ymir-state.sh" lock owned --shell-pid "$$" >/dev/null 2>&1; then
        printf 'error: the arm is held by session %s; this queue is its to acknowledge, not yours\nhelp: tell the arm holder over the arm (bin/voice/rodd-arm.sh tell --from <you> "...") — YMIR_ACK_ANY=1 overrides\n' "$_owner" >&2
        exit 3
      fi
    fi
    # Consume EXACTLY what the last drain PRESENTED — never a wake that arrived
    # after it. The old full-truncate ate undrained wakes (the ack race) and let
    # the sweep's re-presentation ring with an empty hand — the ghost wakes the
    # Allfather saw. A multiset diff: handled lines leave, newer lines stay.
    python3 - "$QUEUE" "$FMQ" "$STATE/.wake-drained" "$STATE/.wake-fmq-drained" <<'PY' 2>/dev/null || true
import os, sys, collections
queue, fmq, qsnap, fsnap = sys.argv[1:5]
def consume(path, snap):
    if not os.path.exists(snap) or not os.path.exists(path):
        return  # no presentation record — nothing consumed from this door
    lines = open(path).read().splitlines()
    cnt = collections.Counter(open(snap).read().splitlines())
    out = []
    for l in lines:
        if cnt.get(l, 0) > 0:
            cnt[l] -= 1
        else:
            out.append(l)
    if out:
        open(path, "w").write("\n".join(out) + "\n")
    else:
        os.remove(path)
consume(queue, qsnap)
consume(fmq, fsnap)
for snap in (qsnap, fsnap):
    if os.path.exists(snap):
        os.remove(snap)
PY
    # The flood-brake hash clears only when both doors are truly empty, so a
    # later terminal wake signals cleanly; preserved newer wakes keep it set.
    if [ ! -s "$QUEUE" ] && { [ ! -f "$FMQ" ] || [ ! -s "$FMQ" ]; }; then
      rm -f "$STATE/.wake-last-hash" 2>/dev/null || true
      printf 'wake queue: acknowledged (0 pending)\n'
    else
      printf 'wake queue: acknowledged handled wakes; newer wakes preserved\n'
    fi
    exit 0
    ;;
  drain|--drain|"") ;;
  *) printf 'error: unknown action %s\nhelp: saga-wake-drain.sh [drain|ack]\n' "$1" >&2; exit 2 ;;
esac

if [ -s "$FMQ" ]; then
  printf 'FM wake queue: %s pending (fm-queued wakes below)\n' "$(awk 'END{print NR}' "$FMQ")"
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] && printf 'WAKE %s\n' "$line"
  done <"$FMQ"
  printf 'FM_ACK_REQUIRED: acknowledge handled fm wakes to drop them from the fm queue\n'
fi

if [ ! -s "$QUEUE" ]; then
  printf 'wake queue: 0 pending\n'
else
  # Count LINES, not newlines: the door is judged non-empty by `[ -s ]`, so a queue
  # holding one unterminated line must present that line too. `wc -l` said 0 for
  # exactly that file, while the extension read the same door as non-empty and
  # re-presented one week-old wake at every turn boundary (2026-10-24).
  count=$(awk 'END{print NR}' "$QUEUE")
  printf '%s — wake queue: %s pending\n' "$(sol_line)" "${count:-0}"
  # A RESOLVED WAKE DROPS ITSELF (plan 275 item 28 §3). A wake is news ONCE: it was
  # presented at the previous drain and its subject's record has since gone terminal, so
  # nothing is owed on it and re-reading it at every turn is noise, not memory. The FIRST
  # notice is never dropped (plan 137): a line absent from the previous presentation is
  # printed even when its subject has already closed.
  _prev="$STATE/.wake-drained"
  _kept="$(mktemp "$STATE/.wake-kept.XXXXXX" 2>/dev/null || printf '%s' "$STATE/.wake-kept.tmp")"
  : >"$_kept" 2>/dev/null || true
  _before="$(md5sum <"$QUEUE" 2>/dev/null | cut -d' ' -f1)"
  resolved=0
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    # A wake is presented until Brokk acks it. The errand's status (done/failed)
    # does NOT make it an echo: a self-finishing worker's terminal wake is the
    # FIRST notice Brokk gets, and dropping it on status makes the worker invisible
    # (plan 137). Echoes from Brokk closing his own errand are still presented once
    # and cleared by `ack` — harmless noise, not a reason to drop the real news.
    _key="$(printf '%s' "$line" | cut -f4)"
    if [ -n "$_key" ] && [ -r "$_prev" ] && grep -qxF -- "$line" "$_prev" 2>/dev/null; then
      _claim="$(tail -n1 "$STATE/$_key.status" 2>/dev/null | tr -d '\r')"
      case "$_claim" in
        done:*|failed:*|needs-decision:*|paused:*)
          resolved=$((resolved + 1)); continue ;;
      esac
    fi
    printf '%s\n' "$line" >>"$_kept" 2>/dev/null || true
    printf 'WAKE %s\n' "$(sol_stamped "$line")"
  done <"$QUEUE"
  if [ "$resolved" -gt 0 ] && [ "$(md5sum <"$QUEUE" 2>/dev/null | cut -d' ' -f1)" = "$_before" ]; then
    mv "$_kept" "$QUEUE" 2>/dev/null || true
    printf 'wake_resolved[1]{dropped,why}:\n  %s,"presented once, and its errand has since closed — a resolved wake is not news"\n' "$resolved"
  else
    rm -f "$_kept" 2>/dev/null || true
  fi
  [ "${dropped:-0}" -gt 0 ] && printf 'wake_echo[1]{dropped,why}:\n  %s,"errands already closed — ack clears them, they are not presented as news"\n' "$dropped"
  printf 'WAKE_ACK_REQUIRED: acknowledge handled wakes to drop them from the queue\n'
  # THE OPEN WORK, every wake — not only the morning brief. One line, so a wake says not
  # just "something happened" but "and here is what still stands unmade".
  OW="$SCRIPT_DIR/../records/open-work.sh"
  if [ -x "$OW" ]; then
    ow_json="$("$OW" --json 2>/dev/null)"
    printf '%s' "$ow_json" | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: raise SystemExit(0)
from collections import Counter
items=d.get("items",[])
if not items: raise SystemExit(0)
c=Counter(i.get("state","open") for i in items)
print(f"OPEN WORK: {len(items)} item(s) — " + " · ".join(f"{k} {v}" for k,v in sorted(c.items())) + " · bin/records/open-work.sh --md")' 2>/dev/null
  fi
fi

# Snapshot exactly what this drain presented, so ack consumes these lines and
# never a wake that arrives later (the ack race). An empty door clears its
# snapshot — nothing was presented to consume.
if [ -s "$QUEUE" ]; then cp "$QUEUE" "$STATE/.wake-drained" 2>/dev/null; else rm -f "$STATE/.wake-drained"; fi
if [ -s "$FMQ" ]; then cp "$FMQ" "$STATE/.wake-fmq-drained" 2>/dev/null; else rm -f "$STATE/.wake-fmq-drained"; fi

# Open-decision markers (approval gates) left unhandled.
decisions=$(find "$STATE" -maxdepth 1 -name '*.decision' 2>/dev/null | wc -l | tr -d '[:space:]')
printf 'open decisions: %s\n' "${decisions:-0}"
