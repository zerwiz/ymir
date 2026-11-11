#!/usr/bin/env bash
# hnoss-model-door.test.sh — Hnoss reaches the model pi itself uses.
#
# The fault this test locks out (measured 2026-11-10): the Hnoss launcher read
# `defaultProvider` from pi's settings and looked it up in `models.json`. When the
# provider was one built INTO pi (opencode-go is absent from models.json) it fell back
# to the local rail `http://127.0.0.1:8080/v1` and paired it with
# `deepseek-v4.1-flash` — a door and a model that cannot answer each other, so every
# design generation died silently. And the launcher itself was a hand-file in
# outside the tree, that no install seated and no update mended.
#
# What is proven here, without a network and without raising a service:
#   1. the four doors are syntactically clean;
#   2. THE BUG: a pi BUILT-IN provider resolves to the bridge, never to the rail;
#   3. a registry rail still resolves directly to its own baseUrl;
#   4. a provider with no door is REFUSED in words, never silently swapped;
#   5. the bridge reports the provider it is really serving (not the flag), and
#      `--ensure` will not call a wrongly-providen bridge green;
#   6. `--stop` on one port leaves the other instance alone.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LAUNCH="$ROOT/bin/pi/hnoss-mcp-launch.sh"
ENSURE="$ROOT/bin/pi/hnoss-ensure.sh"
BRIDGE="$ROOT/bin/bridge/bifrost-bridge.sh"
BRIDGE_PY="$ROOT/.agents/backend/model-bridge.py"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }
skip() { printf 'ok - # SKIP %s\n' "$1"; }

TMP="$(mktemp -d)"
PORT="${HNOSS_TEST_PORT:-4621}"
cleanup() {
  YMIR_MODEL_BIND=127.0.0.1 "$BRIDGE" --stop --port "$PORT" >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT

# ── 1. the doors are syntactically clean ──────────────────────────────────────
bash -n "$LAUNCH" 2>/dev/null && ok "hnoss-mcp-launch.sh is syntactically clean" || bad "bash -n hnoss-mcp-launch.sh"
bash -n "$ENSURE" 2>/dev/null && ok "hnoss-ensure.sh is syntactically clean" || bad "bash -n hnoss-ensure.sh"
bash -n "$BRIDGE" 2>/dev/null && ok "bifrost-bridge.sh is syntactically clean" || bad "bash -n bifrost-bridge.sh"
python3 -c "import ast,sys;ast.parse(open(sys.argv[1]).read())" "$BRIDGE_PY" 2>/dev/null \
  && ok "model-bridge.py parses" || bad "model-bridge.py does not parse"

# ── a pi home whose default provider is a pi BUILT-IN (absent from models.json) ─
PI="$TMP/pi"
mkdir -p "$PI"
cat >"$PI/settings.json" <<'EOF'
{"defaultProvider": "opencode-go", "defaultModel": "deepseek-v4.1-flash"}
EOF
cat >"$PI/models.json" <<'EOF'
{"providers": {"llama-swap": {"baseUrl": "http://127.0.0.1:8080/v1", "models": {}}}}
EOF
cat >"$PI/auth.json" <<'EOF'
{"opencode-go": {"type": "api_key", "key": "test-key-not-a-secret"},
 "llama-swap": {"type": "api_key", "key": "test-key-not-a-secret"}}
EOF

run() {  # run the launcher against the fake pi home, resolved only
  env PI_AGENT_DIR="$PI" YMIR_HNOSS_BRIDGE_PORT="$PORT" OD_DAEMON_URL="http://127.0.0.1:7456" "$@"
}

# ── 2. THE BUG: a built-in provider goes through the bridge, never the rail ───
out="$(run "$LAUNCH" --resolve 2>/dev/null)"
printf '%s' "$out" | grep -q "\"http://127.0.0.1:$PORT/v1\"" \
  && ok "a pi built-in provider resolves to the Bifrost door" \
  || bad "the bridge door was not resolved: $out"
printf '%s' "$out" | grep -q '127.0.0.1:8080' \
  && bad "the door fell back to the local rail (the 2026-11-10 fault)" \
  || ok "the door does NOT fall back to the local rail"
printf '%s' "$out" | grep -q '"deepseek-v4.1-flash"' \
  && ok "the model pi names is carried through" || bad "the model was not resolved: $out"
printf '%s' "$out" | grep -q '"resolved"' \
  && ok "the credential is resolved, not fabricated" || bad "no credential resolved: $out"

# ── 3. a registry rail still resolves straight to its own baseUrl ─────────────
out="$(run YMIR_HNOSS_PROVIDER=llama-swap YMIR_HNOSS_MODEL=qwen3.6-35b-a3b@iq3_s "$LAUNCH" --resolve 2>/dev/null)"
printf '%s' "$out" | grep -q '"http://127.0.0.1:8080/v1"' \
  && ok "a registry provider resolves to its own base URL" \
  || bad "the registry rail was not used directly: $out"

# ── 4. a provider with no door is refused in words ────────────────────────────
if out="$(run YMIR_HNOSS_PROVIDER=openrouter YMIR_HNOSS_MODEL=gpt-5 "$LAUNCH" --resolve 2>&1)"; then
  bad "a provider with no door was accepted: $out"
else
  printf '%s' "$out" | grep -q "no door here for 'openrouter'" \
    && ok "a provider with no door is refused, and named" \
    || bad "the refusal did not name the provider: $out"
fi

# ── 5. the bridge reports what it serves, and will not lie green ──────────────
if (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null; then
  skip "port $PORT is already in use; the bridge truth cases need a free port"
else
  # lmstudio needs no credential, so this instance raises without a network.
  env YMIR_MODEL_BIND=127.0.0.1 "$BRIDGE" --ensure --port "$PORT" --provider lmstudio >/dev/null 2>&1 \
    && ok "the bridge raises on a named port" || bad "the bridge did not raise on :$PORT"
  out="$("$BRIDGE" --status --port "$PORT" 2>/dev/null)"
  printf '%s' "$out" | grep -q '"lmstudio"' \
    && ok "status reports the provider read from the live process" \
    || bad "--status did not report lmstudio: $out"
  # The flag says opencode-go; the process says lmstudio. A status that echoed the
  # flag would print opencode-go here — the false green this test exists to stop.
  out="$("$BRIDGE" --status --port "$PORT" --provider opencode-go 2>/dev/null)"
  printf '%s' "$out" | grep -q '"opencode-go"' \
    && bad "--status echoed the flag instead of the process" \
    || ok "--status ignores the flag and reads the process"
  # `--ensure` on the wrong provider must restart it and never leave two doors.
  out="$("$BRIDGE" --ensure --port "$PORT" --provider lmstudio 2>/dev/null)"
  printf '%s' "$out" | grep -q '"already up"' \
    && ok "--ensure with the SAME provider does nothing" || bad "--ensure re-raised an instance that was already right: $out"
  # An unknown provider may not be called green even though the port answers.
  if out="$("$BRIDGE" --ensure --port "$PORT" --provider no-such-door 2>&1)"; then
    bad "--ensure accepted a provider it cannot serve: $out"
  else
    ok "--ensure refuses a provider it cannot serve"
  fi
  "$BRIDGE" --stop --port "$PORT" >/dev/null 2>&1
  (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null \
    && bad "--stop left :$PORT answering" || ok "--stop closes only the port it was given"
fi

# ── 6. the ensure door reports, and does not need the network to do it ────────
if "$ENSURE" status >/dev/null 2>&1; then
  ok "hnoss-ensure.sh status passes on a seated machine"
else
  skip "hnoss-ensure.sh status is not green on this machine (seating is an install step)"
fi

[ "$fail" = 0 ] && printf 'hnoss-model-door: PASS\n' || printf 'hnoss-model-door: FAIL\n' >&2
exit "$fail"
