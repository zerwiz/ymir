#!/usr/bin/env bash
# test_nornir_mend.sh — the board dedupes a row declared twice, shows a skip as a skip, and names an unreachable machine.
set -uo pipefail
ROOT="$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
pass=0; fail=0
ok() { printf '  ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail+1)); }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

printf '@heart Mon 09:00 bin/x.sh\n@heart Mon 09:00 bin/x.sh\n@dev 10:00 bin/skipme.sh\n' >"$T/cron.yaml"
printf '2026-11-22T01:00:00Z cron run: bin/skipme.sh\n2026-11-22T01:00:01Z cron SKIP not-here: bin/skipme.sh\n' >"$T/cron.log"
out="$(YMIR_HOME="$T" NORNIR_CRON_FILE="$T/cron.yaml" NORNIR_CRON_LOG="$T/cron.log" python3 "$ROOT/bin/time/nornir-jobs.py" --json)"
n=$(printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["counts"]["jobs"], d["counts"]["failing"], [j.get("skipped") for j in d["jobs"] if j["command"]=="bin/skipme.sh"][0])')
[ "$n" = "2 0 True" ] && ok "duplicate row is one job; a door skip is a skip, not a failure ($n)" || bad "board counts: $n"

rc=$(bash -c ". '$ROOT/bin/forge/warden-lib.sh' 2>/dev/null; echo \$WARDEN_RC_NOT_HERE")
[ "$rc" = "78" ] && ok "warden not-this-machine code is 78" || bad "WARDEN_RC_NOT_HERE=$rc"

cat >"$T/fleet.json" <<'J'
{"hosts":{"a":{"user":"u","tailnet":"a.example","state":"dark","dark_since":"2026-10-26"},"b":{"tailnet":"b.example"},"localhost":{}}}
J
f="$(YMIR_HOME="$T" NORNIR_FLEET_FILE="$T/fleet.json" NORNIR_FLEET_SEEN="$T/seen.json" python3 "$ROOT/bin/time/nornir-fleet.py")"
if printf '%s' "$f" | grep -q 'offline (last seen 2026-10-26)' && printf '%s' "$f" | grep -q 'no road' && ! printf '%s' "$f" | grep -q localhost; then
  ok "offline and no-road rows named"; else bad "fleet board: $f"; fi

grep -q 'BROKK_CRON_LOCK_GRACE' "$ROOT/bin/time/nornir-cron-start.sh" && grep -q 'cron SKIP not-here' "$ROOT/bin/time/nornir-cron-start.sh" \
  && ok "scheduler carries the lock grace and the skip verdict" || bad "scheduler edits missing"

printf '%s passed, %s failed\n' "$pass" "$fail"; [ "$fail" = 0 ]
