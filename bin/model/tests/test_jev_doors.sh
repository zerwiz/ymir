#!/usr/bin/env bash
# The ward for bin/model/jev-doors.sh — the door register that told four lies in a row.
#
# WHY: on 2026-11-09 the register reported every registered decision door `down`. None of
# the doors was the fault. The script asked `bin/bridge/seat-host.sh` for the machine — a
# script that does not exist in the tree — so every URL was hollow (`http://:8099`), and it
# probed with a body the engine refuses (`400 … "criteria" must be a non-empty object`),
# counting only `200`. A standing door answering real traffic read as absent.
#
# So this ward checks the three things that were wrong: the probe is a VALID question, the
# states NAME what answered instead of collapsing to `down`, and a missing host is said
# plainly. It also asserts the live door when the heart is reachable, and says `skip`
# otherwise — a borrowed observation must never be painted as a green of its own.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
ok=0; fail=0; skip=0
t() { local n=$1; shift; if "$@" >/tmp/.jt.$$ 2>&1; then ok=$((ok+1)); printf 'ok   %s\n' "$n"; else fail=$((fail+1)); printf 'FAIL %s\n' "$n"; head -5 /tmp/.jt.$$; fi; }
s() { skip=$((skip+1)); printf 'skip %s\n' "$1"; }

t "the door script parses" bash -n "$root/bin/model/jev-doors.sh"

t "the probe carries criteria (a body the engine refuses proves nothing)" bash -c \
  "grep -q '\"criteria\"' '$root/bin/model/jev-doors.sh'"

t "the probe never posts the criteria-less 'noul ok?' body" bash -c \
  "! grep -v '^[[:space:]]*#' '$root/bin/model/jev-doors.sh' | grep -q '\"type\": *\"noul\", *\"instructions\": *\"ok?\"'"

t "the states name what answered (route-missing · unauthorized · wrong-endpoint)" bash -c \
  "grep -q 'route-missing' '$root/bin/model/jev-doors.sh' && grep -q 'unauthorized' '$root/bin/model/jev-doors.sh' && grep -q 'wrong-endpoint' '$root/bin/model/jev-doors.sh'"

t "no host resolver that does not exist" bash -c \
  "! grep -v '^[[:space:]]*#' '$root/bin/model/jev-doors.sh' | grep -q 'bridge/seat-host.sh'"

t "a bogus host yields no false 'up'" bash -c \
  "JEV_DOOR_HOST=no-such-seat.invalid bash '$root/bin/model/jev-doors.sh' list | grep -vq '\"up\"'"

t "openjev has no port, so it is no-door, not down" bash -c \
  "JEV_DOOR_HOST=127.0.0.1 bash '$root/bin/model/jev-doors.sh' list | grep 'OpenJev' | grep -q 'no-door'"

# The live assertion: only when the machine that holds the doors answers at all.
host="$(grep -m1 '^host:' "$root/../config/jev-doors.yaml" 2>/dev/null | cut -d: -f2- | tr -d ' \"')"
host="${host:-127.0.0.1}"
if curl -s -m 3 -o /dev/null "http://$host:8099/health" 2>/dev/null; then
  t "the router door answers the register as 'up'" bash -c \
    "JEV_DOOR_HOST=$host bash '$root/bin/model/jev-doors.sh' list | grep 'Julia-1' | grep -q '\"up\"'"
else
  s "the door host ($host:8099) did not answer — not asserted"
fi

printf 'jev doors: %s ok / %s fail / %s skip\n' "$ok" "$fail" "$skip"
rm -f /tmp/.jt.$$
[ "$fail" = 0 ]
