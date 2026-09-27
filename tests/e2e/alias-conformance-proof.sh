#!/usr/bin/env bash
# alias-conformance-proof.sh — the plan 51 alias gate, proven offline.
#
# A proof is a command, not a claim. This drives `bin/model-alias-check.sh`
# against fixtures, so it needs no rail and no network, and asserts:
#   1. a healthy registry whose every named alias the rail serves  -> pass, 0
#   2. a registry naming an alias NO rail serves                   -> FAIL, names the seat + alias
#   3. a rail preset RENAMED while a seat still names the old name -> FAIL, the rename road is refused
#   4. an unreachable seat is reported `offline`, never a FAIL     -> pass
#
#   tests/e2e/alias-conformance-proof.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHECK="$ROOT/bin/model-alias-check.sh"
[ -x "$CHECK" ] || { printf 'proof[1]{gate,result}:\n  "missing","%s"\n' "$CHECK"; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
SEAT="aliasproof"

# A rail's written presets: three names the fleet relies on.
cat >"$TMP/rail.ini" <<'INI'
[*]
temp = 0

[qwen3.6-35b-a3b@iq3_s]
n-gpu-layers = 999

[qwen3.6-35b-a3b@q4_k_s]
n-gpu-layers = 999

[nomic-embed-text-v1.5]
n-gpu-layers = 999
INI

# A rail with one preset RENAMED — the drift the gate exists to refuse.
sed 's/^\[qwen3.6-35b-a3b@iq3_s\]$/[qwen3.6-35b-a3b@iq3_s-v2]/' "$TMP/rail.ini" >"$TMP/rail-renamed.ini"

# A fleet that also names a seat which cannot be reached.
cat >"$TMP/fleet.json" <<'JSON'
{"heart": "aliasproof",
 "hosts": {"aliasproof": {"roles": ["dev"], "lan": "127.0.0.1"},
           "ghostseat":  {"roles": ["dev"], "tailnet": "203.0.113.1"}}}
JSON
printf '{}\n' >"$TMP/no-fleet.json"

registry() {  # <file> <alias...>
  local f="$1"; shift
  python3 - "$f" "$@" <<'PY'
import json, sys
models = [{"id": a, "name": a, "contextWindow": 8192, "maxTokens": 1024} for a in sys.argv[2:]]
json.dump({"providers": {"llama-swap": {"baseUrl": "http://127.0.0.1:8080/v1",
                                         "api": "openai-completions", "models": models}}}, open(sys.argv[1], "w"))
PY
}

run_local() {  # <registry> <rail-ini>
  YMIR_ALIAS_REGISTRY="$1" YMIR_RAIL_PRESET="$2" YMIR_ALIAS_NO_LIVE=1 \
  YMIR_HOST="$SEAT" YMIR_FLEET_REGISTRY="$TMP/no-fleet.json" \
  bash "$CHECK" --local 2>/dev/null
}

fails=0
row() { printf '  "%s","%s","%s"\n' "$1" "$2" "$3"; }

printf 'alias_conformance_proof[4]{case,result,note}:\n'

# 1. healthy — every named alias the rail serves
registry "$TMP/ok.json" "qwen3.6-35b-a3b@iq3_s" "nomic-embed-text-v1.5"
out="$(run_local "$TMP/ok.json" "$TMP/rail.ini")"; rc=$?
if [ "$rc" = 0 ] && printf '%s' "$out" | grep -q '"pass"'; then row healthy-registry PASS "exit 0"
else row healthy-registry FAIL "rc=$rc"; fails=1; fi

# 2. a registry naming an alias no rail serves
registry "$TMP/broken.json" "qwen3.6-35b-a3b@iq3_s" "qwen3.6-35b-a3b@ghost-quant"
out="$(run_local "$TMP/broken.json" "$TMP/rail.ini")"; rc=$?
if [ "$rc" = 1 ] \
   && printf '%s' "$out" | grep -q "\"$SEAT\",\"llama-swap\",\"qwen3.6-35b-a3b@ghost-quant\"" \
   && printf '%s' "$out" | grep -q '"FAIL"'; then row unserved-alias PASS "exit 1, names seat+alias"
else row unserved-alias FAIL "rc=$rc"; fails=1; fi

# 3. the rename road: the rail renamed the preset a seat still names
registry "$TMP/rename.json" "qwen3.6-35b-a3b@iq3_s"
out="$(run_local "$TMP/rename.json" "$TMP/rail-renamed.ini")"; rc=$?
if [ "$rc" = 1 ] \
   && printf '%s' "$out" | grep -q "\"$SEAT\",\"llama-swap\",\"qwen3.6-35b-a3b@iq3_s\"" \
   && printf '%s' "$out" | grep -q '"FAIL"'; then row renamed-rail-preset PASS "exit 1, the rename is refused"
else row renamed-rail-preset FAIL "rc=$rc"; fails=1; fi

# 4. an unreachable seat is `offline`, never a FAIL; the reachable one still passes
out="$(YMIR_ALIAS_REGISTRY="$TMP/ok.json" YMIR_RAIL_PRESET="$TMP/rail.ini" YMIR_ALIAS_NO_LIVE=1 \
       YMIR_HOST="$SEAT" YMIR_FLEET_REGISTRY="$TMP/fleet.json" YMIR_ALIAS_TIMEOUT=1 \
       bash "$CHECK" 2>/dev/null)"; rc=$?
if [ "$rc" = 0 ] && printf '%s' "$out" | grep -q '"pass"' \
   && printf '%s' "$out" | grep -q '"ghostseat","seat unreachable"'; then
  row offline-honesty PASS "ghostseat offline, verdict pass"
else row offline-honesty FAIL "rc=$rc"; fails=1; fi

if [ "$fails" = 0 ]; then
  printf 'alias_conformance_proof_verdict[1]{verdict}:\n  "PASS"\n'
  exit 0
fi
printf 'alias_conformance_proof_verdict[1]{verdict}:\n  "FAIL"\n'
exit 1
