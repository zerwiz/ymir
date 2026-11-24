#!/usr/bin/env bash
# test_heart_doors.sh — a seat that is not the heart reaches the heart's record doors (skills,
# tickets, meetings) through the ssh forward first; the heart itself keeps loopback; snotra is
# behind the gateway on every harness. Fixture registry only: no live door is touched.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok()  { printf 'ok    %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL  %s\n' "$1"; fail=$((fail + 1)); }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

cat >"$TMP/fleet.json" <<'J'
{"heart": "host-a", "hosts": {"host-a": {"roles": ["heart"], "tailnet": "host-a.example.org"},
                              "host-b": {"roles": ["dev"], "tailnet": "host-b.example.org"}}}
J
resolve() { YMIR_FLEET_REGISTRY="$TMP/fleet.json" YMIR_HOST="$1" bash "$ROOT/bin/bridge/mcp-gateway.sh" resolve; }
first() { python3 -c 'import json,sys; print(json.load(sys.stdin)[sys.argv[1]]["urls"][0])' "$1"; }

DEV="$(resolve host-b)"; HEART="$(resolve host-a)"
check "a dev seat tries the skills door over ssh first"   '[ "$(printf %s "$DEV" | first bolthorn)" = "http://127.0.0.1:18319/mcp" ]'
check "a dev seat tries the ticket door over ssh first"   '[ "$(printf %s "$DEV" | first skuld)" = "http://127.0.0.1:18320" ]'
check "a dev seat tries the meeting door over ssh first"  '[ "$(printf %s "$DEV" | first snotra)" = "http://127.0.0.1:18321/mcp" ]'
check "the heart reaches its own doors on loopback"       '[ "$(printf %s "$HEART" | first skuld)" = "http://127.0.0.1:8320" ]'
check "the heart is never sent through a forward"         '! printf %s "$HEART" | grep -q 1832'
check "the offset is configuration"                       '[ "$(YMIR_HEART_DOOR_OFFSET=20000 resolve host-b | first skuld)" = "http://127.0.0.1:28320" ]'
check "the tailnet stays as a fallback"                   'printf %s "$DEV" | grep -q "host-a.example.org:8320"'

check "snotra is a record door for every harness"         'grep -q "^RECORD_DOORS = (\"well\", \"bolthorn\", \"skuld\", \"snotra\")" "$ROOT/bin/bridge/mcp-config-seat.py"'
check "fleet-ensure seats snotra on the gateway"          'grep -q "snotra = snotra_override or (\"%s/snotra\" % base)" "$ROOT/bin/fleet/fleet-ensure.sh"'
check "fleet-ensure no longer dials the heart's tailnet for snotra" '! grep -q "http://%s:8321/mcp" "$ROOT/bin/fleet/fleet-ensure.sh"'

H="$ROOT/bin/bridge/heart-doors.sh"
check "the door script parses"                            'bash -n "$H"'
check "the door forwards each port to port + offset"      'grep -q "\-L %s:127.0.0.1:%s" "$H"'
check "the door never opens a port to the network"        '! grep -qE "GatewayPorts|-R |0\.0\.0\.0" "$H"'
check "the door is a clean skip on the heart"             '[ "$(YMIR_HEART=$(hostname -s) bash "$H" status)" != "" ] && YMIR_HEART=$(hostname -s) bash "$H" status | grep -q "skip"'
check "with no heart the door refuses by name"            'YMIR_HEART= YMIR_FLEET_REGISTRY=/nonexistent YMIR_HOME="$TMP" bash "$H" status 2>&1 | grep -q "no heart"'
check "this test is registered in tests/run.sh"           'grep -q test_heart_doors.sh "$ROOT/tests/run.sh"'

printf '\nheart doors: %s ok, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
