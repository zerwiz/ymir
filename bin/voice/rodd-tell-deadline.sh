#!/usr/bin/env bash
# rodd-tell-deadline.sh — a tell that nobody answers does not wait forever: it escalates.
#
# Why (plan 001 §4 F3, measured 2026-11-17): a tell was handed to the heart's arm and nothing
# answered, because the arm was held by a supervisor with no mind and no model heartbeat. The tell sat
# in the queue looking delivered. A message that is never acknowledged must therefore stop being a
# private hope and become the operator's business — with a DEADLINE, not a shrug.
#
# The record it reads is the house's own: the wake queue the lease names. `rodd-arm.sh tell` appends a
# wake of kind `signal` with a `rodd-<epoch>` key; the drain acknowledges by dropping the queue once its
# wakes are handled. So a tell is UNACKNOWLEDGED exactly when its line is still there — and it has
# expired when its epoch is older than the deadline.
#
# Each tell escalates ONCE: the key is written to `<state>/.rodd-tell-escalated`, so a sweeper that runs
# every few minutes does not turn one unanswered tell into a hundred messages (which is how an operator
# learns to ignore the house).
#
# Usage:
#   rodd-tell-deadline.sh check     [--deadline S] [--dry-run]   # what has expired, and say it
#   rodd-tell-deadline.sh list      [--deadline S]               # the expired tells, no message
#   rodd-tell-deadline.sh --version
#
# Env:
#   RODD_TELL_DEADLINE_SECONDS   default 300
#   YMIR_STATE_DIR               the state root (default: the home's, via hoard-lib.sh)
#   BROKK_WAKE_QUEUE             the queue path (default: the one the arm lease names)
#
# Exit: 0 nothing expired · 1 something expired (and was escalated, or reported with --dry-run) · 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

usage() { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
die()   { printf 'rodd-tell-deadline: %s\n' "$*" >&2; exit 1; }

if [ -z "${YMIR_STATE_DIR:-}" ] && [ -r "$ROOT/bin/vault/hoard-lib.sh" ]; then
  # shellcheck source=../vault/hoard-lib.sh
  . "$ROOT/bin/vault/hoard-lib.sh"
  hoard_state_dir YMIR_STATE_DIR 2>/dev/null || true
fi
[ -n "${YMIR_STATE_DIR:-}" ] || YMIR_STATE_DIR="$HOME/.local/state/ymir"

# THE LEASE IS THE AUTHORITY (the same law rodd-arm.sh keeps): if it names a state dir, that is where
# the queue the arm actually drains lives. Only with no lease does the home's own state dir answer.
QUEUE="${BROKK_WAKE_QUEUE:-}"
if [ -z "$QUEUE" ] && [ -r "$YMIR_STATE_DIR/.arm.lease" ]; then
  LEASED_STATE="$(sed -n 's/.* state=\([^ ]*\).*/\1/p' "$YMIR_STATE_DIR/.arm.lease" 2>/dev/null | head -1)"
  [ -n "${LEASED_STATE:-}" ] && [ -d "$LEASED_STATE" ] && YMIR_STATE_DIR="$LEASED_STATE"
fi
QUEUE="${QUEUE:-$YMIR_STATE_DIR/.wake-queue}"
DEADLINE="${RODD_TELL_DEADLINE_SECONDS:-300}"
ESCALATED="$YMIR_STATE_DIR/.rodd-tell-escalated"

ACTION="${1:-check}"; shift || true
case "$ACTION" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) usage 0 ;;
  check|list) ;;
  *) usage 2 ;;
esac

DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --deadline) DEADLINE="${2:-300}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    *) printf 'error: unknown flag %s\n' "$1" >&2; exit 2 ;;
  esac
done
case "$DEADLINE" in ''|*[!0-9]*) die "the deadline must be a number of seconds, not '$DEADLINE'" ;; esac

# The expired tells, one row per tell: key<TAB>age_s<TAB>payload. The queue is read through the state
# module (one parser), and the age is Sol's clock versus the wake's own epoch.
EXPIRED="$(QUEUE="$QUEUE" DEADLINE="$DEADLINE" ESCALATED="$ESCALATED" PYTHONPATH="$ROOT/src${PYTHONPATH:+:$PYTHONPATH}" python3 - <<'PY'
import os
import sys
import time
from pathlib import Path

queue_path = Path(os.environ["QUEUE"])
deadline = int(os.environ["DEADLINE"])
escalated_path = Path(os.environ["ESCALATED"])
now = int(time.time())

try:
    from ymir_runtime.state.queue import parse_all
except Exception:
    print("error: the state module is missing — the queue cannot be read", file=sys.stderr)
    sys.exit(2)

try:
    text = queue_path.read_text(encoding="utf-8", errors="replace")
except OSError:
    print("error: the wake queue cannot be read at %s" % queue_path, file=sys.stderr)
    sys.exit(2)

escalated = set()
try:
    escalated = {line.strip() for line in escalated_path.read_text(encoding="utf-8").splitlines() if line.strip()}
except OSError:
    pass

expired = []
for wake in parse_all(text):
    if wake.kind != "signal":
        continue
    if not wake.key.startswith("rodd-"):
        continue
    age = now - wake.epoch
    if age < deadline:
        continue
    expired.append((wake.key, age, wake.payload, wake.key in escalated))

for key, age, payload, done in expired:
    print("%s\t%s\t%s\t%s" % (key, age, payload, "escalated" if done else "fresh"))
PY
)" || die "the queue could not be read ($QUEUE)"

if [ -z "$EXPIRED" ]; then
  printf 'rodd-tell-deadline[1]{verdict,queue,deadline_s,expired}:\n  "quiet","%s","%s","0"\n' "$QUEUE" "$DEADLINE"
  exit 0
fi

rc=1
printf 'rodd-tell-deadline[1]{verdict,queue,deadline_s,expired}:\n  "expired","%s","%s","%s"\n' \
  "$QUEUE" "$DEADLINE" "$(printf '%s\n' "$EXPIRED" | grep -c .)"
printf 'rodd-tell-expired[]{key,age_s,state,payload}:\n'
printf '%s\n' "$EXPIRED" | while IFS=$'\t' read -r key age payload state; do
  [ -n "$key" ] || continue
  printf '  "%s","%s","%s","%s"\n' "$key" "$age" "$state" "$payload"
  # `list` READS and never acts: a door that escalates while merely listing is a door that alarms on
  # inspection (measured the hard way, 2026-11-17: three synthetic tells reached the notifier because
  # `list` ran the escalation arm). Only `check` speaks.
  [ "$ACTION" = "check" ] || continue
  [ "$state" = "escalated" ] && continue
  line="a tell to the arm is unacknowledged after ${age}s (deadline ${DEADLINE}s): ${payload}"
  if [ "$DRY" = "1" ]; then
    printf 'would escalate: %s\n' "$line"
    continue
  fi
  # A sink for a test and for a replay: a proof must never be an alarm.
  if [ -n "${YMIR_RODD_ESCALATE_SINK:-}" ]; then
    printf '%s\t%s\n' "$key" "$line" >>"$YMIR_RODD_ESCALATE_SINK"
    printf '%s\n' "$key" >>"$ESCALATED"
    continue
  fi
  if bash "$ROOT/bin/notify/send.sh" --source ward --severity HIGH --key "rodd-tell:$key" --message "$line" >/dev/null 2>&1; then
    printf '%s\n' "$key" >>"$ESCALATED"
  else
    printf 'rodd-tell-deadline: the escalation for %s did NOT reach the door — the tell still stands\n' "$key" >&2
  fi
done

grep -q . <<<"$EXPIRED" && exit 1 || exit 0
