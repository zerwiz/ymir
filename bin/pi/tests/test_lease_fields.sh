#!/usr/bin/env bash
# test_lease_fields.sh — the arm lease carries many key=value fields after state= (seat= charter= host=
# machine= fleetrole= fleet= pin= pin_behind= identity= missing=). A reader takes ONE space-delimited
# token, never the rest of the line: lease_alive() (syn-watch-arm.sh) and seat-wire.sh must both see
# state=<dir> exactly, with the identity fields present.
set -uo pipefail
ROOT="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
t() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then pass=$((pass+1)); echo "  ok   $d"; else fail=$((fail+1)); echo "  FAIL $d"; fi; }

STATE="$T/state"; mkdir -p "$STATE"; LEASE="$STATE/.arm.lease"
st="$(awk '{print $22}' /proc/$$/stat)"
printf 'pid=%s starttime=%s state=%s seat=Hoenir charter=work host=heimdall machine=heimdall fleetrole=dev fleet=rodd pin=3b1ba7a0 pin_behind=0 identity=ok missing=\n' "$$" "$st" "$STATE" >"$LEASE"

gleipnir_pid_alive() { kill -0 "$1" 2>/dev/null; }
eval "$(sed -n '/^lease_alive() {/,/^}/p;/^lease_part() {/,/^}/p' "$ROOT/bin/pi/syn-watch-arm.sh")"
t "lease_alive: a lease with the identity fields is alive" lease_alive
t "lease_part: state is one token" test "$(lease_part state)" = "$STATE"
t "lease_part: a later field reads whole" test "$(lease_part pin_behind)" = "0"
printf 'pid=%s starttime=%s state=%s/other seat=x\n' "$$" "$st" "$STATE" >"$LEASE"
if lease_alive; then fail=$((fail+1)); echo "  FAIL lease_alive: another state refused"; else pass=$((pass+1)); echo "  ok   lease_alive: another state refused"; fi

printf 'pid=%s starttime=%s state=%s seat=Hoenir host=heimdall identity=ok missing=\n' "$$" "$st" "$STATE" >"$LEASE"
dir="$(awk '{ for (i = 1; i <= NF; i++) if (index($i, "state=") == 1) { print substr($i, 7); exit } }' "$LEASE")"
t "seat-wire: the state token is exactly the dir" test "$dir" = "$STATE"
pat="s/.* state"; pat="${pat}=//p"
t "no greedy state= reader remains" bash -c '! grep -rnF --exclude=test_lease_fields.sh -e "$1" "$0/bin" "$0/src"' "$ROOT" "$pat"
printf 'test_lease_fields: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
