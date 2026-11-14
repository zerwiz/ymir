#!/usr/bin/env bash
# test_bifrost_provider.sh — the door's proof for plan 275 item 22.
#
# WHAT BROKE (measured 2026-11-14 03:16): `bifrost.service` ran the bridge as
# `--provider lmstudio` because the env file carried no OPENCODE_GO_API_KEY, and LM Studio
# was retired on 2026-10-24. OmniChat then answered every message with
# `The well is local; no model backend answered (http://127.0.0.1:4603/v1 → 500)` while the
# bridge log said `curl: (7) Failed to connect to 127.0.0.1:1234`.
#
# The six claims this test holds:
#   1. a NAMED provider wins — even lmstudio, which is otherwise never chosen;
#   2. with no key anywhere and no rail, the door REFUSES and names both roads;
#   3. a key in the vault serves opencode-go (read through `bin/vault/hodd.sh`);
#   4. a key in pi's auth.json serves opencode-go, and pi is reported as the door;
#   5. a live rail with no key serves local-rail (never lmstudio);
#   6. the model list comes from the catalogue, so a model the house uses (v4.1) appears
#      even when the gateway cannot be reached;
#   7. the key itself never appears in any output the door prints.
#
# Everything runs against a throwaway home, a fake vault door, a fake auth file and a fake
# catalogue, so no real key, rail or house is touched.
#
# Usage: test_bifrost_provider.sh
# Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
DOOR="$ROOT/bin/bridge/bifrost-bridge.sh"
BRIDGE="$ROOT/.agents/backend/model-bridge.py"

T=$(mktemp -d)
trap 'bash "$DOOR" --stop --port 4698 >/dev/null 2>&1 || true
      bash "$DOOR" --stop --port 4699 >/dev/null 2>&1 || true
      [ -n "${RAIL_PID:-}" ] && kill "$RAIL_PID" 2>/dev/null
      [ -n "${UP_PID:-}" ] && kill "$UP_PID" 2>/dev/null
      rm -rf "$T"' EXIT

FAKE_KEY="sk-test-NOT-A-REAL-KEY-0123456789"
: > "$T/empty.env"
# the vault's own door prints `export KEY=value` lines (bin/vault/hodd.sh emit does); the
# fixture must PRINT, not merely export, or the bridge reads an empty vault.
{
  printf '#!/usr/bin/env bash\n'
  printf 'printf "export OPENCODE_GO_API_KEY=%%s\\n" %s\n' "'$FAKE_KEY'"
} > "$T/vault.sh"
chmod +x "$T/vault.sh"
printf '{"opencode-go":{"type":"api","key":"%s"}}\n' "$FAKE_KEY" > "$T/auth.json"
cat > "$T/catalog.sh" <<'CAT'
#!/usr/bin/env bash
printf 'catalog[2]{provider,model,context,max_out}:\n'
printf '  "opencode-go","deepseek-v4.1-flash","1M","384K"\n'
printf '  "llama-swap","qwen-test","128K","8K"\n'
CAT
chmod +x "$T/catalog.sh"

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

# run <outfile> <env…> -- <door args…>: every run is isolated from this shell's real home
run() {
  local out="$1"; shift
  local -a envs=()
  while [ "$1" != "--" ]; do envs+=("$1"); shift; done
  shift
  env -i HOME="$T" PATH=/usr/bin:/bin YMIR_HOME="$T" BROKK_ENV_FILE="$T/empty.env" \
    "${envs[@]}" bash "$DOOR" "$@" >"$out" 2>&1
}

printf 'bifrost provider (plan 275 item 22)\n'

# 1 — a NAMED provider wins, even the retired one
out="$T/1"; run "$out" YMIR_VAULT_DOOR=/nonexistent YMIR_PI_AUTH=/nonexistent -- \
  --resolve --port 4698 --provider lmstudio
if grep -q '"lmstudio","named by the operator"' "$out"; then ok "a NAMED provider wins (even lmstudio)"
else bad "a NAMED provider wins" "$(head -3 "$out")"; fi

# 2 — no key, no rail: refuse, and name both roads
out="$T/2"
if run "$out" YMIR_VAULT_DOOR=/nonexistent YMIR_PI_AUTH=/nonexistent YMIR_RAIL_BASE_URL=http://127.0.0.1:1/v1 -- \
     --start --port 4698; then
  bad "no key and no rail is a refusal" "the door started anyway: $(head -2 "$out")"
else
  if grep -q 'no provider to serve' "$out" && grep -q 'rail on :8080' "$out" && grep -q 'opencode-go' "$out"; then
    ok "no key and no rail is a refusal that names both roads"
  else bad "the refusal names both roads" "$(head -4 "$out")"; fi
  if grep -q 'provider lmstudio\|"lmstudio"' "$out"; then bad "lmstudio is never the fallback" "$(cat "$out")"
  else ok "lmstudio is never the fallback"; fi
fi

# 3 — the vault door serves opencode-go
out="$T/3"; run "$out" YMIR_VAULT_DOOR="$T/vault.sh" YMIR_PI_AUTH=/nonexistent -- --resolve --port 4698
if grep -q '"opencode-go","a key is readable (OPENCODE_GO_API_KEY in the vault)"' "$out"; then
  ok "a key in the vault serves opencode-go"
else bad "the vault key serves opencode-go" "$(head -3 "$out")"; fi
if grep -q "$FAKE_KEY" "$out"; then bad "the key is never printed" "the vault key appeared in the door's output"
else ok "the key is never printed"; fi

# 4 — pi's auth.json is the last key door, and it is REPORTED
out="$T/4"; run "$out" YMIR_VAULT_DOOR=/nonexistent YMIR_PI_AUTH="$T/auth.json" -- --resolve --port 4698
if grep -q "opencode-go in pi's auth.json" "$out"; then ok "pi's auth.json is a key door, and it is reported"
else bad "pi's auth.json is a key door" "$(head -3 "$out")"; fi

# 5 — a live rail, no key: local-rail, never lmstudio
python3 - "$T/rail.port" <<'PY' &
import json, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        body = json.dumps({"object": "list", "data": [{"id": "qwen-test", "object": "model"}]}).encode()
        self.send_response(200); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
    def log_message(self, *a):
        pass
srv = ThreadingHTTPServer(("127.0.0.1", 0), H)
open(sys.argv[1], "w").write(str(srv.server_address[1]))
srv.serve_forever()
PY
RAIL_PID=$!
for _ in $(seq 1 50); do [ -s "$T/rail.port" ] && break; sleep 0.1; done
RAIL_URL="http://127.0.0.1:$(cat "$T/rail.port" 2>/dev/null || echo 1)/v1"
out="$T/5"; run "$out" YMIR_VAULT_DOOR=/nonexistent YMIR_PI_AUTH=/nonexistent YMIR_RAIL_BASE_URL="$RAIL_URL" -- \
  --resolve --port 4698
if grep -q '"local-rail","no key, and the rail answers' "$out"; then ok "a live rail with no key serves local-rail"
else bad "a live rail serves local-rail" "$(head -3 "$out")"; fi

# 6 — the model list comes from the catalogue (v4.1 appears) when the gateway cannot answer
run "$T/6.start" YMIR_VAULT_DOOR="$T/vault.sh" YMIR_PI_AUTH=/nonexistent \
  YMIR_CATALOG_BIN="$T/catalog.sh" OPENCODE_GO_BASE_URL=http://127.0.0.1:1/v1 -- \
  --start --port 4699 --provider opencode-go >/dev/null 2>&1
models="$(curl -s --max-time 5 http://127.0.0.1:4699/v1/models || true)"
bash "$DOOR" --stop --port 4699 >/dev/null 2>&1 || true
if printf '%s' "$models" | grep -q 'deepseek-v4.1-flash'; then
  ok "the model list comes from the catalogue (v4.1 appears)"
else bad "the model list comes from the catalogue" "$(printf '%s' "$models" | head -c 300)"; fi

# 7 — a non-stream reply is DELIMITED and written once (plan 275 item 22: the proxy's
# read() never advanced, so one completion through the bridge produced a 13 GB download of
# the same JSON repeated — a client waiting for the end of a reply never got one).
python3 - "$T/up.port" "$T/reply.json" <<'PY' &
import json, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
portfile, replyfile = sys.argv[1], sys.argv[2]
reply = json.dumps({"id": "probe", "object": "chat.completion",
                    "choices": [{"index": 0, "finish_reason": "stop",
                                 "message": {"role": "assistant", "content": "the bridge answers"}}]}).encode()
open(replyfile, "wb").write(reply)
class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def do_POST(self):
        n = int(self.headers.get("Content-Length") or 0)
        self.rfile.read(n)
        self.send_response(200); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(reply))); self.end_headers(); self.wfile.write(reply)
    def do_GET(self):
        body = json.dumps({"object": "list", "data": [{"id": "probe-model", "object": "model"}]}).encode()
        self.send_response(200); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
    def log_message(self, *a):
        pass
srv = ThreadingHTTPServer(("127.0.0.1", 0), H)
open(portfile, "w").write(str(srv.server_address[1]))
srv.serve_forever()
PY
UP_PID=$!
for _ in $(seq 1 50); do [ -s "$T/up.port" ] && break; sleep 0.1; done
UP_URL="http://127.0.0.1:$(cat "$T/up.port" 2>/dev/null || echo 1)/v1"
run "$T/7.start" YMIR_MODEL_BASE_URL="$UP_URL" YMIR_VAULT_DOOR=/nonexistent YMIR_PI_AUTH=/nonexistent -- \
  --start --port 4698 --provider openai-compatible >/dev/null 2>&1
curl -sS --max-time 10 -o "$T/7.body" -D "$T/7.head" \
  -H 'content-type: application/json' -d '{"model":"probe-model","messages":[{"role":"user","content":"hi"}]}' \
  "http://127.0.0.1:4698/v1/chat/completions" >/dev/null 2>&1
bash "$DOOR" --stop --port 4698 >/dev/null 2>&1 || true
kill "$UP_PID" 2>/dev/null || true
if cmp -s "$T/7.body" "$T/reply.json"; then ok "a non-stream reply is the upstream body, exactly once"
else bad "a non-stream reply is written once" "$(wc -c <"$T/7.body" 2>/dev/null) bytes vs $(wc -c <"$T/reply.json") expected"; fi
if grep -qi '^content-length: ' "$T/7.head" 2>/dev/null; then ok "the reply declares its own length, so the client knows where it ends"
else bad "the reply declares a length" "$(head -5 "$T/7.head" 2>/dev/null | tr '\n' ' ')"; fi

printf 'bifrost provider: %s ok / %s fail\n' "$pass" "$fail"
[ "$fail" = 0 ]
