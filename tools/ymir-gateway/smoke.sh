#!/usr/bin/env bash
# smoke.sh — one door that proves the gateway works, safe by default.
#
# WHY SAFE BY DEFAULT: the smoke test I wrote earlier in this project called every tool with `{}` and
# wrote 28 junk plans and 28 junk memories into the operator's vault (0.1.105). A test that can
# damage something is not a test. So this one:
#
#   · runs OFFLINE by default — no network, no agent, no model
#   · never writes outside its own directory
#   · touches the local rail ONLY when asked (YMIR_LIVE=1) and the key is already exported
#
#   bash tools/ymir-gateway/smoke.sh              # offline; what a gate should run
#   YMIR_LIVE=1 bash tools/ymir-gateway/smoke.sh  # also prove the real rail answers
#
# The key is read by REFERENCE from the environment or the seat's auth file — never printed, never
# written here, never committed.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE" || exit 2

LIVE="${YMIR_LIVE:-0}"
fail=0
declare -a rows=()

run() {
  local name="$1"; shift
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ]; then
    rows+=("  \"$name\",\"PASS\",\"\"")
  else
    rows+=("  \"$name\",\"FAIL\",\"$(printf '%s' "$out" | grep -E 'FAIL|Error|error:' | head -1 | cut -c1-80)\"")
    fail=$((fail + 1))
  fi
}

# 1 · the seam parses and loads at all
for f in session.mjs acp.mjs pi.mjs; do
  run "parse:$f" node --experimental-strip-types --input-type=module -e "await import('./$f')"
done

# 2 · session identity: ids, tokens, cross-device resume
run "session-identity" node session.test.mjs

# 3 · both brains through the ONE seam, offline
run "brains-offline" node brains.test.mjs

# 4 · the real local rail, only when asked
if [ "$LIVE" = "1" ]; then
  if [ -z "${LLAMA_SWAP_API_KEY:-}" ] && [ -r "$HOME/.pi/agent/auth.json" ]; then
    # by REFERENCE, never printed
    LLAMA_SWAP_API_KEY="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('llama-swap',{}).get('key',''))" \
      "$HOME/.pi/agent/auth.json" 2>/dev/null)"
    export LLAMA_SWAP_API_KEY
  fi
  if [ -n "${LLAMA_SWAP_API_KEY:-}" ]; then
    run "brains-live" env YMIR_LIVE=1 node brains.test.mjs
  else
    rows+=("  \"brains-live\",\"SKIP\",\"no key available by reference — not fetched, not guessed\"")
  fi
else
  rows+=("  \"brains-live\",\"SKIP\",\"not asked for (YMIR_LIVE=1)\"")
fi

# 5 · the adopted SDK must be installed, because we adopted it on purpose
if [ -d "$HERE/node_modules/@agentclientprotocol/sdk" ] || node -e "require.resolve('@agentclientprotocol/sdk')" 2>/dev/null; then
  rows+=("  \"acp-sdk\",\"PASS\",\"\"")
else
  rows+=("  \"acp-sdk\",\"MISSING\",\"npm i @agentclientprotocol/sdk — P1 adopted it deliberately\"")
fi

printf 'gateway_smoke[%d]{gate,verdict,detail}:\n' "${#rows[@]}"
printf '%s\n' "${rows[@]}"

if [ "$fail" -gt 0 ]; then
  printf 'gateway-smoke: %s gate(s) failed\n' "$fail" >&2
  exit 1
fi
exit 0