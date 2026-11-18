#!/usr/bin/env bash
# ratatoskr-arm.sh — a task for a MACHINE goes to that machine's arm holder, and nowhere else.
#
#   bin/bridge/ratatoskr-arm.sh <machine> "<one line>"     hand the holder one line
#   bin/bridge/ratatoskr-arm.sh --who                      who holds the arm on every machine
#
# WHY (plan 303 §12.3 step 5, §11): a task addressed to a machine has no pane to wake. The
# machine's one live arm holder is the agent that answers for it, and the house already has
# exactly one door to that holder per direction — `bin/agents/eindri-notify.sh` here, and
# `bin/fleet/arm-send.sh` over the fleet's own roads. This door JOINS them; it adds no second
# wire, no second lease and no second holder. Each machine keeps ONE holder (RULES/55).
#
# A machine with no live holder is refused BY NAME and nothing is handed — a message that
# goes to nobody must say so, not sit in a queue looking delivered.
#
# The law a relay keeps (RULES/49, 56): this door says *handed*, never *delivered*. The task
# counts as delivered only when the holder drains it and the queue carries an answer.
#
# Exit: 0 handed · 1 refused (no live holder, named) · 2 usage.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Test seams, the house's own style (YMIR_UNIT_DIR, HDR_BIN): the two doors this one joins are
# named by their paths, so a test can judge this door without a live holder on the machine.
NOTIFY="${RATATOSKR_NOTIFY_DOOR:-$ROOT/bin/agents/eindri-notify.sh}"
FLEET="${RATATOSKR_ARM_SEND_DOOR:-$ROOT/bin/fleet/arm-send.sh}"

me="$(hostname -s 2>/dev/null || hostname)"
line=""
machine=""
case "${1-}" in
  ""|-h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
  --who)        exec bash "$FLEET" --who ;;
  *)            machine="$1"; shift; line="$*" ;;
esac
[ -n "$line" ] || { printf 'ratatoskr-arm: give the line to hand over\n' >&2; exit 2; }

# The registry is the one place a machine is named; a name it does not know is a refusal.
if ! python3 - "$ROOT" "$machine" <<'PY' 2>/dev/null
import json, os, subprocess, sys
root, want = sys.argv[1], sys.argv[2]
lib = os.path.join(root, "bin", "vault", "hoard-lib.sh")
home = os.environ.get("YMIR_HOME") or ""
if not home and os.path.exists(lib):
    out = subprocess.run(["bash", "-c", ". %s >/dev/null 2>&1 && ymir_home_root _h >/dev/null 2>&1 && printf '%%s' \"$_h\"" % lib],
                         capture_output=True, text=True).stdout.strip()
    home = out
reg = os.path.join(home, "hodd", "data", "fleet.json")
hosts = (json.load(open(reg)) or {}).get("hosts") or {} if os.path.exists(reg) else {}
sys.exit(0 if want in hosts else 1)
PY
then
  printf 'ratatoskr-arm: refused — %s is not in the fleet registry; nothing was handed\n' "$machine" >&2
  exit 1
fi

if [ "$machine" = "$me" ]; then
  # The local road: the holder's own pane, resolved by the door that owns that resolution.
  if out="$(bash "$NOTIFY" --from ratatoskr -- "$line" 2>&1)"; then
    printf 'ratatoskr-arm\thanded\t%s\t(handed; delivered only when the holder answers)\n' "$machine"
    exit 0
  fi
  printf 'ratatoskr-arm\tREFUSED\tnobody holds the arm on %s — nothing was handed\n' "$machine" >&2
  printf '%s\n' "$out" | tail -2 >&2
  exit 1
fi

# The fleet road: one line over this seat's own road to that machine's holder.
out="$(bash "$FLEET" "$machine" "$line" 2>&1)"; rc=$?
printf '%s\n' "$out"
case "$rc" in
  0) exit 0 ;;
  3) exit 1 ;;   # the far door's own "nobody holds the arm" answer, already named
  *) exit 1 ;;
esac
