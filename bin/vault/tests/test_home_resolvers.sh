#!/usr/bin/env bash
# test_home_resolvers.sh — the two resolvers that keep the operator's own realm and heart
# out of the public repository (RULES/04, RULES/25).
#
# The repository ships to strangers, so it may not spell `svartalfaheim/<our realm>/…`
# nor name this fleet's heart. Both are READ from the home instead, and a home that
# records neither answers empty rather than inventing one. This test proves exactly that:
#
#   · one ledger under the home            → found (whatever realm it sits in)
#   · a home with no ledger                → rc 1, empty (the caller says what to set)
#   · a home with two ledgers              → rc 2 (ambiguous; name one), never a guess
#   · an explicit $YMIR_PLAN_DIR           → wins over the discovery
#   · the fleet registry's `heart`         → read; `$YMIR_HEART` wins over it
#   · no registry / no heart key           → rc 1, empty
#
# Usage: bash bin/vault/tests/test_home_resolvers.sh
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$HERE/../hoard-lib.sh"
pass=0; fail=0
ok()  { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
echo "test_home_resolvers"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

# ── ymir_plan_dir ────────────────────────────────────────────────────────────────────
one="$T/one/home"; mkdir -p "$one/svartalfaheim/alpha/projects/ymir/plans" "$one/svartalfaheim/beta"
out="$(YMIR_HOME="$one" bash -c '. "$1"; ymir_plan_dir d; printf "%s|%s" "$?" "$d"' _ "$LIB")"
[ "${out%%|*}" = 0 ] && [ "${out#*|}" = "$one/svartalfaheim/alpha/projects/ymir/plans" ] \
  && ok "the single ledger is discovered, whatever realm it sits in" \
  || bad "the ledger was not discovered: $out"

none="$T/none/home"; mkdir -p "$none/svartalfaheim/alpha"
out="$(YMIR_HOME="$none" bash -c '. "$1"; d=KEEP; ymir_plan_dir d; printf "%s|%s" "$?" "$d"' _ "$LIB")"
[ "${out%%|*}" = 1 ] && [ "${out#*|}" = KEEP ] \
  && ok "a home with no ledger answers 1 and touches nothing" \
  || bad "no-ledger home: $out"

two="$T/two/home"; mkdir -p "$two/svartalfaheim/a/projects/ymir/plans" "$two/svartalfaheim/b/projects/ymir/plans"
out="$(YMIR_HOME="$two" bash -c '. "$1"; d=KEEP; ymir_plan_dir d; printf "%s|%s" "$?" "$d"' _ "$LIB")"
[ "${out%%|*}" = 2 ] && [ "${out#*|}" = KEEP ] \
  && ok "two ledgers are ambiguous (2), never a guess" \
  || bad "ambiguous home: $out"

out="$(YMIR_HOME="$none" YMIR_PLAN_DIR="$T/named" bash -c '. "$1"; ymir_plan_dir d; printf "%s|%s" "$?" "$d"' _ "$LIB")"
[ "${out#*|}" = "$T/named" ] && ok "\$YMIR_PLAN_DIR wins over the discovery" || bad "override ignored: $out"

# the older shape is read only when the newer one has nothing
old="$T/old/home"; mkdir -p "$old/svartalfaheim/alpha/workspace/ymir/plans"
out="$(YMIR_HOME="$old" bash -c '. "$1"; ymir_plan_dir d; printf "%s|%s" "$?" "$d"' _ "$LIB")"
[ "${out#*|}" = "$old/svartalfaheim/alpha/workspace/ymir/plans" ] \
  && ok "the older workspace/ ledger shape is still read" || bad "legacy shape: $out"

# the resolver this file is about must answer on THIS machine too — a path it cannot
# name is a drift, not a default
here=""
here="$(YMIR_HOME="$one" bash -c '. "$1"; ymir_home_root h; printf %s "$h"' _ "$LIB")"
[ "$here" = "$one" ] && ok "ymir_home_root answers the home it was given" \
  || bad "ymir_home_root did not answer: $here"

# ── ymir_fleet_heart ────────────────────────────────────────────────────────────────
reg="$T/fleet/home"; mkdir -p "$reg/hodd/data"
printf '{ "heart": "heart-host", "hosts": { "heart-host": { "roles": ["heart"] } } }\n' > "$reg/hodd/data/fleet.json"
out="$(YMIR_HOME="$reg" bash -c 'unset YMIR_HEART; . "$1"; ymir_fleet_heart h; printf "%s|%s" "$?" "$h"' _ "$LIB")"
[ "${out%%|*}" = 0 ] && [ "${out#*|}" = "heart-host" ] \
  && ok "the heart is read from the home's fleet registry" || bad "heart from registry: $out"

out="$(YMIR_HEART="a-chosen-host" YMIR_HOME="$reg" bash -c '. "$1"; ymir_fleet_heart h; printf "%s|%s" "$?" "$h"' _ "$LIB")"
[ "${out#*|}" = "a-chosen-host" ] && ok "\$YMIR_HEART wins over the registry" || bad "heart override: $out"

empty="$T/empty/home"; mkdir -p "$empty/hodd/data"
out="$(YMIR_HOME="$empty" bash -c 'unset YMIR_HEART; . "$1"; h=KEEP; ymir_fleet_heart h; printf "%s|%s" "$?" "$h"' _ "$LIB")"
[ "${out%%|*}" = 1 ] && [ "${out#*|}" = KEEP ] \
  && ok "no registry answers 1 and invents no host" || bad "no-registry home: $out"

nokey="$T/nokey/home"; mkdir -p "$nokey/hodd/data"
printf '{ "hosts": {} }\n' > "$nokey/hodd/data/fleet.json"
out="$(YMIR_HOME="$nokey" bash -c 'unset YMIR_HEART; . "$1"; h=KEEP; ymir_fleet_heart h; printf "%s|%s" "$?" "$h"' _ "$LIB")"
[ "${out%%|*}" = 1 ] && [ "${out#*|}" = KEEP ] \
  && ok "a registry with no heart answers 1" || bad "heartless registry: $out"

# The repository must not spell the operator's realm or hosts — and NEITHER MAY THIS TEST.
# So the words are read from his deny list, the same door bin/gates/agnostic-audit.sh uses
# (`$YMIR_HOME/hodd/identity/public-deny.txt`). A home with no list is a clean skip, said aloud,
# because a test that silently checks nothing is a green that means nothing (RULES/18, RULES/25).
check_home="${YMIR_HOME:-}"
[ -n "$check_home" ] || check_home="$(bash -c '. "$1"; ymir_home_root h; printf %s "$h"' _ "$LIB" 2>/dev/null || true)"
deny="${YMIR_DENY_LIST:-${check_home:+$check_home/hodd/identity/public-deny.txt}}"
if [ -r "$deny" ]; then
  named=0
  while IFS= read -r w; do
    w="${w%%#*}"; w="$(printf '%s' "$w" | tr -d '[:blank:]')"
    [ -n "$w" ] || continue
    if grep -qF -- "$w" "$LIB"; then named=$((named + 1)); fi
  done < "$deny"
  [ "$named" -eq 0 ] && ok "hoard-lib.sh names not one word from the home's deny list" \
    || bad "hoard-lib.sh names $named word(s) from the home's deny list"
else
  printf '  skip the deny-list check — no %s on this machine (a clean skip, said aloud)\n' "$deny"
fi

printf 'test_home_resolvers: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
