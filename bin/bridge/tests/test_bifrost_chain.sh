#!/usr/bin/env bash
# test_bifrost_chain.sh — the proof that Bifrost's model chain falls through, step by step.
#
# The chain (2026-11-21): every hosted service calls ONE door, and the door tries, in order, a
# hosted model, a llama.cpp rail on one machine, a rail on another, and a second hosted model.
# Any machine may be off, so each step must give way to the next when it is down, refuses,
# times out or rate-limits — and the door must say which step answered.
#
# This test raises four FAKE upstreams on loopback and a throwaway home whose chain names
# them (two by fleet host, to prove the address is read from the registry), then forces each
# step down in turn:
#   1. all up                     -> step 1 answers
#   2. step 1 refuses (429)       -> step 2 answers, and step 1 is passed over in the log
#   3. step 2 stopped             -> step 3 answers
#   4. step 3 answers 200+error   -> step 4 answers (a refusal in a 200 is not an answer)
#   5. all down                   -> 503 naming every step
#   6. a step marked down is skipped from cache, without a second request to it
#   7. a stream request is relayed with the answering step named
#   8. no key appears in anything the door prints
#
# Usage: test_bifrost_chain.sh        Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
BRIDGE="$ROOT/.agents/backend/model-bridge.py"
T=$(mktemp -d)
PIDS=()
cleanup() { for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done; rm -rf "$T"; }
trap cleanup EXIT

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

free_port() { python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()'; }

# A fake OpenAI-compatible upstream whose behaviour is read from a file on every request,
# so a test can change it without restarting: ok | 429 | 500 | error200 | hang.
cat > "$T/fake.py" <<'PY'
import json, sys, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
port, name, mode_file, hits = int(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]
def mode():
    try: return open(mode_file).read().strip()
    except Exception: return "ok"
class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _out(self, code, obj, ctype="application/json"):
        b = obj if isinstance(obj, bytes) else json.dumps(obj).encode()
        self.send_response(code); self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_GET(self):
        m = mode()
        if m in ("429", "500"): return self._out(int(m), {"error": {"message": m}})
        self._out(200, {"object": "list", "data": [{"id": name}]})
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers.get("Content-Length") or 0)) or b"{}")
        open(hits, "a").write(f"{name} {body.get('model')}\n")
        m = mode()
        if m == "hang": time.sleep(30)
        if m in ("429", "500"): return self._out(int(m), {"error": {"message": f"{name} says {m}"}})
        if m == "error200": return self._out(200, {"error": {"message": f"{name} refuses"}})
        if body.get("stream"):
            return self._out(200, f'data: {{"choices":[{{"delta":{{"content":"{name}"}}}}]}}\n\ndata: [DONE]\n\n'.encode(), "text/event-stream")
        self._out(200, {"choices": [{"message": {"role": "assistant", "content": f"answer from {name}"}}], "model": body.get("model")})
ThreadingHTTPServer(("127.0.0.1", port), H).serve_forever()
PY

declare -A PORT MODE
for s in hosted rail-a rail-b hosted2; do
  PORT[$s]=$(free_port); MODE[$s]="$T/$s.mode"; echo ok > "${MODE[$s]}"
  python3 "$T/fake.py" "${PORT[$s]}" "$s" "${MODE[$s]}" "$T/hits" >/dev/null 2>&1 & PIDS+=($!)
done

FAKE_KEY="sk-test-NOT-A-REAL-KEY-chain-0123456789"
mkdir -p "$T/home/config" "$T/home/data"
# Two steps are named by fleet HOST: their address must come from the registry.
cat > "$T/home/data/fleet.json" <<EOF
{"hosts": {"host-a": {"tailnet": "127.0.0.1"}, "host-b": {"lan": "127.0.0.1"}}}
EOF
cat > "$T/home/config/model-chain.json" <<EOF
{"steps": [
  {"name": "hosted", "provider": "openai-compatible", "base_url": "http://127.0.0.1:${PORT[hosted]}/v1", "key_env": "FAKE_HOSTED_KEY", "model": "free-one", "timeout": 4},
  {"name": "rail-a", "provider": "llamacpp", "host": "host-a", "port": ${PORT[rail-a]}, "model": "small-a", "timeout": 4},
  {"name": "rail-b", "provider": "llamacpp", "host": "host-b", "port": ${PORT[rail-b]}, "model": "small-b", "timeout": 4},
  {"name": "hosted2", "provider": "openai-compatible", "base_url": "http://127.0.0.1:${PORT[hosted2]}/v1", "model": "free-two", "timeout": 4}
]}
EOF
: > "$T/empty.env"
BPORT=$(free_port)
env -i PATH="$PATH" HOME="$T/home" YMIR_SETTINGS_DIR="$T/home/config" YMIR_DATA_DIR="$T/home/data" \
  YMIR_CHAIN_HEALTH_TTL=2 FAKE_HOSTED_KEY="$FAKE_KEY" YMIR_VAULT_DOOR=/nonexistent YMIR_PI_AUTH=/nonexistent \
  python3 "$BRIDGE" --port "$BPORT" --env "$T/empty.env" >"$T/bridge.log" 2>&1 & PIDS+=($!)
for _ in $(seq 1 50); do (exec 3<>"/dev/tcp/127.0.0.1/$BPORT") 2>/dev/null && break; sleep 0.1; done

ask() {  # ask [stream] -> prints "<status> <step> <body>"
  local s=false; [ "${1:-}" = stream ] && s=true
  curl -s -m 20 -D "$T/h" -o "$T/b" -w '%{http_code}' "http://127.0.0.1:$BPORT/v1/chat/completions" \
    -H 'Content-Type: application/json' \
    -d "{\"model\":\"anything\",\"stream\":$s,\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]}" > "$T/code"
  printf '%s %s %s' "$(cat "$T/code")" "$(sed -n 's/^[Xx]-[Yy]mir-[Cc]hain-[Ss]tep: *//p' "$T/h" | tr -d '\r')" "$(cat "$T/b")"
}
settle() { sleep 2.2; }   # past the 2 s health window, so a restored step is probed again

echo "chain: four fake steps, forced down in turn"
grep -q "provider 'chain' on" "$T/bridge.log" && ok "the home's chain file is chosen with nothing named" \
  || bad "the home's chain file is chosen with nothing named" "$(cat "$T/bridge.log")"

r=$(ask); case "$r" in "200 hosted "*"answer from hosted"*) ok "1. all up -> step 1 (hosted) answers";; *) bad "1. all up -> step 1" "$r";; esac
grep -q "^hosted free-one$" "$T/hits" && ok "   the step's own model replaces the caller's" || bad "   the step's model" "$(cat "$T/hits")"

echo 429 > "${MODE[hosted]}"; settle
r=$(ask); case "$r" in "200 rail-a "*) ok "2. step 1 refuses 429 -> step 2 (rail-a, by fleet host) answers";; *) bad "2. 429 -> rail-a" "$r";; esac
grep -q "passed=\[hosted=" "$T/bridge.log" && ok "   the log names the step passed over" || bad "   log passed-over" "$(tail -3 "$T/bridge.log")"

: > "$T/hits"
r=$(ask); case "$r" in "200 rail-a "*) ok "6. a step marked down is skipped while cached";; *) bad "6. cached skip" "$r";; esac
grep -q "^hosted" "$T/hits" && bad "   step 1 was asked again inside its window" "$(cat "$T/hits")" || ok "   no second request to the step marked down"

kill "${PIDS[1]}" 2>/dev/null; settle
r=$(ask); case "$r" in "200 rail-b "*) ok "3. step 2 stopped -> step 3 (rail-b) answers";; *) bad "3. stopped -> rail-b" "$r";; esac

echo error200 > "${MODE[rail-b]}"; settle
r=$(ask); case "$r" in "200 hosted2 "*) ok "4. step 3 answers 200 with an error -> step 4 (hosted2) answers";; *) bad "4. error200 -> hosted2" "$r";; esac

echo ok > "${MODE[hosted]}"; settle
r=$(ask stream); case "$r" in "200 hosted "*'"content":"hosted"'*) ok "7. a stream is relayed, the answering step named";; *) bad "7. stream" "$r";; esac

echo 500 > "${MODE[hosted]}"; echo 500 > "${MODE[hosted2]}"; settle
r=$(ask); case "$r" in "503 "*"no model step answered"*) ok "5. all down -> 503 naming every step";; *) bad "5. all down" "$r";; esac
grep -q "NO STEP ANSWERED" "$T/bridge.log" && ok "   the log says no step answered" || bad "   log no-step" "$(tail -3 "$T/bridge.log")"

curl -s -m 10 "http://127.0.0.1:$BPORT/chain" > "$T/chain.json"
python3 -c "import json,sys;d=json.load(open('$T/chain.json'));assert d['provider']=='chain' and len(d['steps'])==4" 2>/dev/null \
  && ok "GET /chain reports the four steps" || bad "GET /chain" "$(cat "$T/chain.json")"

if grep -rq "$FAKE_KEY" "$T/bridge.log" "$T/chain.json"; then bad "8. a key leaked into the door's output"
else ok "8. no key appears in the log or /chain"; fi

printf 'chain: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
