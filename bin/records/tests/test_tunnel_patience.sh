#!/usr/bin/env bash
# test_tunnel_patience.sh — a slow origin is not an absent one, and a silent one still fails.
#
# WHY (2026-11-20). The round reported `7 up · 1 failing` with two surfaces at 000 — documents and the desk —
# and both answered 401 and 404 within the minute. AFFiNE cold takes longer than the ten seconds the check
# allowed, so a healthy surface was announced as broken every half hour. The check now asks a second time,
# with more patience, and only a second silence is a failure.
#
# The proof uses a host that cannot answer at all (RFC 5737 TEST-NET-1, blackholed by construction) so the
# retry path is exercised for real, and a second run with no surfaces proves the quiet line stays honest.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DOOR="$ROOT/bin/records/gimle-tunnels-check.sh"
pass=0; fail=0
t() { local n="$1"; shift; if "$@"; then printf '  ok   %s\n' "$n"; pass=$((pass+1)); else printf '  FAIL %s\n' "$n"; fail=$((fail+1)); fi; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/home/hodd/identity" "$T/cf"
cat >"$T/home/hodd/identity/services.yaml" <<YAML
services:
  - id: blackhole
    public_url: "https://192.0.2.1/"
YAML
printf 'ingress:\n  - hostname: 192.0.2.1\n    service: http://127.0.0.1:1\n' >"$T/cf/config.yml"

export YMIR_HOME="$T/home" CLOUDFLARED_DIR="$T/cf"
start=$(date +%s)
out="$(timeout 120 bash "$DOOR" 2>&1)"; rc=$?
took=$(( $(date +%s) - start ))

fails_honestly() { [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'two tries'; }
t "a host that never answers fails, and the row says it was asked twice"  fails_honestly
retried_waits()  { [ "$took" -ge 12 ]; }
t "the check waited past the first timeout before judging"               retried_waits

cat >"$T/home/hodd/identity/services.yaml" <<'YAML'
services:
  - id: nothing-public
    public_url: ""
YAML
quiet_ok() { timeout 60 bash "$DOOR" --quiet >"$T/q.out" 2>&1; rc=$?; [ "$rc" -eq 0 ] && grep -q '0 failing' "$T/q.out"; }
t "no public surface is a clean pass, not a failure"                      quiet_ok

printf 'tunnel-patience: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
