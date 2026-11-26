#!/usr/bin/env bash
# test_fleet_smidja_db.sh — `fleet-ensure.sh unit smidja` renders CMD_DB in the operator's HOME, never the
# tree or pin it ran from, and honours SMIDJA_DB (2026-11-25, found by Eir on a second machine).
#
#   1. with no SMIDJA_DB, CMD_DB is <YMIR_HOME>/smidja/smidja.db
#   2. with SMIDJA_DB=<path>, CMD_DB is that path
#   3. with a pin seated, and a home that carries RULES/ and an installer, the settle step
#      (unit_settle → units.sh write) leaves CMD_DB in the home, SMIDJA_DB inside the home included
#
# Fenced: a temp HOME and a temp YMIR_HOME. Cases 1-2 name a runtime dir that does not exist, so
# unit_settle refuses in words. Case 3 names a temp pin and sets YMIR_UNITS_NO_SYSTEMCTL, so nothing
# real is read, written or restarted.
set -uo pipefail
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
pass=0; fail=0
t() { local name=$1; shift; if "$@"; then printf '  ok   %s\n' "$name"; pass=$((pass+1)); else printf '  FAIL %s\n' "$name"; fail=$((fail+1)); fi; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export HOME="$T/home" XDG_CONFIG_HOME="$T/home/.config"   # allow-home-default: the test fences HOME in a temp dir
export YMIR_HOME="$T/ymirhome" YMIR_STATE_DIR="$T/state" YMIR_RUNTIME_DIR="$T/no-pin"
unset SMIDJA_DB BROKK_ROOT_OVERRIDE FLEET_TEMPLATE_ROOT 2>/dev/null || true
mkdir -p "$HOME/.config/systemd/user" "$YMIR_HOME/config" "$T/state"
UNIT="$HOME/.config/systemd/user/smidja.service"

bash "$ROOT/bin/fleet/fleet-ensure.sh" unit smidja >/dev/null 2>&1
t "default: smidja.service is rendered" [ -f "$UNIT" ]
t "default: CMD_DB is the home's db" grep -qx "Environment=CMD_DB=$YMIR_HOME/smidja/smidja.db" "$UNIT"
t "default: CMD_DB never names the tree it ran from" bash -c '! grep -q "^Environment=CMD_DB=$0" "$1"' "$ROOT" "$UNIT"

rm -f "$UNIT"
SMIDJA_DB="$T/elsewhere/smithy.db" bash "$ROOT/bin/fleet/fleet-ensure.sh" unit smidja >/dev/null 2>&1
t "SMIDJA_DB: the operator's path is honoured" grep -qx "Environment=CMD_DB=$T/elsewhere/smithy.db" "$UNIT"

# 3 — the real fault: the render was right, and the settle step then moved the home's path onto the pin
mkdir -p "$YMIR_HOME/RULES" "$YMIR_HOME/bin/engine" "$T/pin"; touch "$YMIR_HOME/bin/engine/ymir-install.sh"
ln -s "$ROOT/bin" "$T/pin/bin"
export YMIR_RUNTIME_DIR="$T/pin" YMIR_UNIT_DIR="$HOME/.config/systemd/user" YMIR_UNITS_NO_SYSTEMCTL=1 YMIR_UNITS_NO_ROLE_PROBE=1
for db in "" "$YMIR_HOME/elsewhere/smithy.db"; do
  want="${db:-$YMIR_HOME/smidja/smidja.db}"; label="${db:+SMIDJA_DB in the home}"; label="${label:-default}"
  rm -f "$UNIT"
  out="$(SMIDJA_DB="$db" bash "$ROOT/bin/fleet/fleet-ensure.sh" unit smidja 2>&1)"
  t "settled, $label: the settle step ran" grep -q 'units: smidja settled on the pin' <<<"$out"
  t "settled, $label: CMD_DB stays in the home" grep -qx "Environment=CMD_DB=$want" "$UNIT"
done

printf 'test_fleet_smidja_db: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
