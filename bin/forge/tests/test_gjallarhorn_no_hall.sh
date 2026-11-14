#!/usr/bin/env bash
# test_gjallarhorn_no_hall.sh — a tunnel never publishes a hall.
#
# WHY (plan 275 item 30, 2026-11-14): his word — *"this feature of opening online must go
# away with the logins we have. we are not hosting the 3 apps online.. they are local. craig
# found that were opening ports out."* The halls already listen on loopback only; what
# survived from the hosted era was a tunnel config pointing at the gate (:3889). So the
# door refuses any ingress that dials a hall port, and the shipped templates carry none.
#
# The claims this test holds:
#   1. `check` refuses a config that points at the gate, and names the line;
#   2. `check` refuses every hall port in the set (3888 3889 4322 8437 8787 4602 4603);
#   3. `check` passes a config that points at a frontier surface (:8761, :2586, :3891);
#   4. `start` refuses the same config BEFORE cloudflared is looked for;
#   5. the templates this repo ships name no hall port at all.
#
# Usage: test_gjallarhorn_no_hall.sh
# Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
DOOR="$ROOT/bin/forge/gjallarhorn-tunnel.sh"

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

# make <file> <service-url> — a one-ingress tunnel config
make() { printf 'tunnel: ymir\ningress:\n  - hostname: probe.example.org\n    service: %s\n  - service: http_status:404\n' "$2" > "$1"; }

printf 'gjallarhorn — the halls are local\n'

make "$T/gate.yml" "http://127.0.0.1:3889"
out="$(YMIR_TUNNEL_CONFIG="$T/gate.yml" bash "$DOOR" check 2>&1)"; rc=$?
if [ "$rc" -ne 0 ]; then ok "a config at the gate is refused"; else bad "a config at the gate is refused" "$out"; fi
if printf '%s' "$out" | grep -q 'probe.example.org http://127.0.0.1:3889 (a hall port)'; then
  ok "the refusal names the hostname, the service and the line"
else bad "the refusal names the offending ingress" "$out"; fi

allports=0
for p in 3888 3889 4322 8437 8787 4602 4603; do
  make "$T/p.yml" "http://127.0.0.1:$p"
  if YMIR_TUNNEL_CONFIG="$T/p.yml" bash "$DOOR" check >/dev/null 2>&1; then
    allports=$((allports+1)); bad "hall port $p is refused" "check said it was clean"
  fi
done
[ "$allports" -eq 0 ] && ok "every hall port in the set is refused (3888 3889 4322 8437 8787 4602 4603)"

frontier=0
for p in 8761 2586 3891; do
  make "$T/f.yml" "http://127.0.0.1:$p"
  if YMIR_TUNNEL_CONFIG="$T/f.yml" bash "$DOOR" check >/dev/null 2>&1; then :; else
    frontier=$((frontier+1)); bad "a frontier surface on :$p passes" "check refused it"
  fi
done
[ "$frontier" -eq 0 ] && ok "a frontier surface (:8761, :2586, :3891) passes"

make "$T/gate.yml" "http://127.0.0.1:3889"
out="$(YMIR_TUNNEL_CONFIG="$T/gate.yml" bash "$DOOR" start 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'points at a hall'; then
  ok "start refuses before cloudflared is even looked for"
else bad "start refuses a hall config" "$out"; fi

# 5 — the shipped templates carry no hall port
shipped=0
for f in "$ROOT"/midgard/infrastructure/ingress/*.yml; do
  [ -f "$f" ] || continue
  # only an `service:` line can publish a port; the header comment may name the halls
  if grep -E '^\s*service:\s*https?://' "$f" | grep -qE ':(3888|3889|4322|8437|8787|4602|4603)([^0-9]|$)'; then
    shipped=$((shipped+1)); bad "$(basename "$f") publishes no hall" "$(grep -E '^\s*service:' "$f" | head -3 | tr '\n' ' ')"
  fi
done
[ "$shipped" -eq 0 ] && ok "no shipped ingress template publishes a hall"

printf 'gjallarhorn halls: %s ok / %s fail\n' "$pass" "$fail"
[ "$fail" = 0 ]
