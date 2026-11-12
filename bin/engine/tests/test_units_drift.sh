#!/usr/bin/env bash
# test_units_drift.sh — plan 278, problem 17: an installed unit that still runs a value its source has
# retired is FOUND (`units.sh drift`, exit 1) and RE-SEATED (`units.sh write <name> --render`), while a
# seat's own `--set` choice is never called drift.
#
#   1. a mail desk unit on the retired port 8490 is named, with the command that mends it
#   2. `write gna-desk --render` re-seats it from the register on the source's port, old line logged
#   3. after the re-seat, drift is clean
#   4. a seat that chose its own port (not a retired one) is not drift
#   5. without --render, the adopt road still keeps an existing unit's shape (no flip-flop between writers)
#
# Everything runs in a temp HOME with a fake unit directory: no real unit is read, written or restarted.
set -uo pipefail
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
pass=0; fail=0
t() { local name=$1; shift; if "$@"; then printf '  ok   %s\n' "$name"; pass=$((pass+1)); else printf '  FAIL %s\n' "$name"; fail=$((fail+1)); fi; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export HOME="$T/home" XDG_CONFIG_HOME="$T/home/.config" XDG_DATA_HOME="$T/home/.local/share"
export YMIR_HOME="$T/ymirhome" YMIR_STATE_DIR="$T/state" YMIR_UNIT_DIR="$T/units"
export YMIR_APPLICATIONS_DIR="$T/apps-dir" YMIR_AUTOSTART_DIR="$T/autostart"
export YMIR_UNITS_NO_SYSTEMCTL=1 YMIR_UNITS_NO_ROLE_PROBE=1 YMIR_RUNTIME_DIR="$ROOT"
mkdir -p "$HOME" "$YMIR_HOME/config" "$YMIR_UNIT_DIR" "$T/state"
UNITS="$ROOT/bin/engine/units.sh"

# the shape the fleet step wrote before the desk moved off the share's port
cat >"$YMIR_UNIT_DIR/gna-desk.service" <<UNIT
[Unit]
Description=the mail desk

[Service]
ExecStart=/usr/bin/python3 $ROOT/bin/mail/gna_desk.py --port 8490
Restart=always

[Install]
WantedBy=default.target
UNIT

# 1
out="$(bash "$UNITS" drift 2>&1)"; rc=$?
t "drift: a unit on a retired value fails (exit 1)" [ "$rc" -eq 1 ]
t "drift: it names the unit, the value and the source's value" grep -q '"gna-desk","service","DRIFT","GNA_DESK_PORT=8490 is a retired default; the source says 8494' <<<"$out"
t "drift: it names the command that mends it" grep -q 'units.sh write gna-desk --render' <<<"$out"

# 5 — the adopt road alone keeps the shape (two writers must not flip-flop)
bash "$UNITS" write gna-desk >/dev/null 2>&1
t "adopt without --render keeps the old argument" grep -q -- '--port 8490' "$YMIR_UNIT_DIR/gna-desk.service"

# 2
bash "$UNITS" write gna-desk --render >/dev/null 2>&1
t "--render re-seats the unit on the source's port" grep -q -- '--port 8494' "$YMIR_UNIT_DIR/gna-desk.service"
t "--render leaves no retired port behind" bash -c '! grep -q -- "--port 8490" "$0"' "$YMIR_UNIT_DIR/gna-desk.service"
t "the replaced line is logged (the undo)" grep -q -- '--port 8490' "$T/state/units-replaced.log"

# 3
bash "$UNITS" drift >/dev/null 2>&1
t "after the re-seat, drift is clean" [ $? -eq 0 ]

# 4 — a seat's own choice is not drift
bash "$UNITS" write gna-desk --set GNA_DESK_PORT=9123 >/dev/null 2>&1
bash "$UNITS" drift >/dev/null 2>&1
t "a seat's own --set port is not drift" [ $? -eq 0 ]

printf 'test_units_drift: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
