#!/usr/bin/env bash
# garmr.test.sh — the hound's own tests. A redactor without tests is a leak with a delay.
#
#   bash .agents/tests/garmr.test.sh
#
# Exit 0 all pass · 1 a failure named on stderr.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GARMR="$ROOT/bin/ward/garmr"
TMP="$(mktemp -d)"
export YMIR_HOME="$TMP/home"   # the resolver must have an answer; the tests never read it
mkdir -p "$YMIR_HOME/config"
trap 'rm -rf "$TMP"' EXIT
fails=0
pass() { printf '  PASS %s\n' "$1"; }
fail() { printf '  FAIL %s — %s\n' "$1" "$2" >&2; fails=$((fails + 1)); }

echo "garmr.test — the redactor (Rule 26: report the kind, never the value)"
out="$(PYTHONPATH="$GARMR" python3 - <<'PY'
from redact import redact_text, redact_argv, redact_path
cases = {
 "bearer":  ("Authorization: Bearer abcdef123456", "abcdef123456"),
 "url":     ("https://x/y?access_token=deadbeef99&z=1", "deadbeef99"),
 "assign":  ("GITHUB_TOKEN=ghp_abcdefghijklmnopqrst", "ghp_abcdefghijklmnopqrst"),
 "shape":   ("key sk-abcdef1234567890 end", "sk-abcdef1234567890"),
 "flag":    (" ".join(redact_argv(["--token", "hunter2", "--url", "http://x"])), "hunter2"),
}
for name,(text,secret) in cases.items():
    out = redact_text(text) if name != "flag" else text
    print(f"{name}:{'LEAK' if secret in out else 'ok'}")
path = redact_path("/home/heimdall/Documents/ymirhome/hodd/data/snotra/2026-10-20.json")
print("path:" + ("LEAK" if "snotra" in path else "hashed"))
PY
)"
for kind in bearer url assign shape flag path; do
  case "$out" in
    *"$kind:ok"*|*"$kind:hashed"*) pass "redactor $kind" ;;
    *) fail "redactor $kind" "value or path survived: $out" ;;
  esac
done

echo "garmr.test — the rules (a fact arrives with its severity)"
out="$(PYTHONPATH="$GARMR" python3 - <<'PY'
from rules import evaluate
cfg = {"allow": {"sensitive_readers": ["snotra-detect.sh"],
                 "program_dirs": ["/usr/"], "writable_dirs": ["/tmp/"],
                 "listen_ports": [22], "peer_hosts": ["127.0.0.1"]}}
checks = {
  "stranger_reads": evaluate({"kind":"sensitive_open","comm":"curl","pid":1,"uid":1000,"target":"<sensitive:abc>"}, cfg)["severity"],
  "reader_reads":   evaluate({"kind":"sensitive_open","comm":"snotra-detect.sh","pid":1,"uid":1000,"target":"<sensitive:abc>"}, cfg)["severity"],
  "tmp_exec":       evaluate({"kind":"exec","comm":"x","pid":1,"uid":1000,"exe":"/tmp/x.sh","target":"/tmp/x.sh"}, cfg)["severity"],
  "usr_exec":       evaluate({"kind":"exec","comm":"ls","pid":1,"uid":1000,"exe":"/usr/bin/ls","target":"/usr/bin/ls"}, cfg)["severity"],
  "new_listener":   evaluate({"kind":"listener","comm":"node","pid":1,"addr":"0.0.0.0:9999"}, cfg)["severity"],
  "known_listener": evaluate({"kind":"listener","comm":"sshd","pid":1,"addr":"0.0.0.0:22"}, cfg)["severity"],
}
for name, sev in checks.items():
    print(f"{name}={sev}")
PY
)"
assert_sev() { case "$out" in *"$1=$2"*) pass "rule $1 → $2" ;; *) fail "rule $1" "expected $2 in: $out" ;; esac; }
assert_sev stranger_reads CRITICAL
assert_sev reader_reads INFO
assert_sev tmp_exec HIGH
assert_sev usr_exec INFO
assert_sev new_listener HIGH
assert_sev known_listener INFO

echo "garmr.test — the senses (a fixture audit log, no root needed)"
cat > "$TMP/audit.log" <<'EOF'
type=SYSCALL msg=audit(1792581000.100:1): arch=c000003e syscall=59 success=yes exit=0 pid=1234 uid=1000 comm="curl" exe="/usr/bin/curl" key="ymir-exec"
type=EXECVE msg=audit(1792581000.100:1): argc=3 a0="curl" a1="-H" a2="Authorization:Bearer_secretvalue"
type=PROCTITLE msg=audit(1792581000.100:1): proctitle=6375726C002D48
type=SYSCALL msg=audit(1792581001.200:2): arch=c000003e syscall=257 success=yes exit=3 pid=4321 uid=1000 comm="python3" exe="/usr/bin/python3" key="ymir-sensitive"
type=PATH msg=audit(1792581001.200:2): item=0 name="/home/heimdall/Documents/ymirhome/hodd/data/snotra/2026-10-20.json"
type=SYSCALL msg=audit(1792581002.300:3): arch=c000003e syscall=62 success=yes exit=0 pid=999 uid=1000 comm="bash" key="ymir-browserkill" a0=1a2b a1=f
EOF
out="$(PYTHONPATH="$GARMR" GARMR_STATE_DIR="$TMP/state" python3 "$GARMR/hound.py" --audit-file "$TMP/audit.log" --stdout 2>/dev/null)"
case "$out" in *'"kind": "exec"'*) pass "sense exec parsed" ;; *) fail "sense exec" "no exec finding: $out" ;; esac
case "$out" in *'"kind": "sensitive_open"'*) pass "sense sensitive parsed" ;; *) fail "sense sensitive" "no sensitive finding" ;; esac
case "$out" in *sensitive:*) pass "sensitive path hashed" ;; *) fail "sensitive path" "path was not hashed" ;; esac
case "$out" in *snotra*) fail "leak in findings" "a sensitive path reached the findings" ;; *) pass "no sensitive path in findings" ;; esac
case "$out" in *secretvalue*) fail "leak in argv" "a bearer token reached the findings" ;; *) pass "argv redacted in findings" ;; esac
case "$out" in *'"kind": "kill"'*) pass "sense kill parsed" ;; *) fail "sense kill" "no kill finding" ;; esac

echo "garmr.test — the judgement (rules only, no model, nothing written)"
cat > "$TMP/findings.jsonl" <<'EOF'
{"ts":"2026-10-21T03:12:00+0300","sense":"audit","kind":"sensitive_open","pid":"1234","uid":"1000","comm":"curl","exe":"/usr/bin/curl","target":"<sensitive:abc123>"}
{"ts":"2026-10-21T03:13:00+0300","sense":"ss","kind":"listener","pid":"4242","comm":"node","addr":"0.0.0.0:9999"}
EOF
out="$(PYTHONPATH="$GARMR" GARMR_STATE_DIR="$TMP/state2" python3 "$GARMR/brain.py" --file "$TMP/findings.jsonl" --once --dry-run 2>&1)"
case "$out" in *"CRITICAL:"*) pass "judgement raises CRITICAL" ;; *) fail "judgement CRITICAL" "$out" ;; esac
case "$out" in *"HIGH:"*) pass "judgement raises HIGH" ;; *) fail "judgement HIGH" "$out" ;; esac
[ -f "$TMP/state2/judged.jsonl" ] && fail "dry-run wrote" "judged.jsonl exists after --dry-run" || pass "dry-run writes nothing"


echo "garmr.test — the ladder (a stub endpoint stands in for a reasoner)"
cat > "$TMP/home/config/guardian.yaml" <<'YAML'
escalate:
  on: high
  online: opencode-go/deepseek-v4.1-flash
  budget:
    online_calls_per_day: 5
YAML
cat > "$TMP/stub.py" <<'PY'
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
class H(BaseHTTPRequestHandler):
    def do_POST(self):
        self.rfile.read(int(self.headers.get('content-length', 0)))
        body = {"choices": [{"message": {"content": "STUB: looked like an exfiltration attempt; check the parent shell."}}]}
        self.send_response(200)
        self.send_header('content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(body).encode())
    def log_message(self, *a):
        pass
HTTPServer(('127.0.0.1', 18441), H).serve_forever()
PY
python3 "$TMP/stub.py" & STUB=$!
sleep 1
FINDING='{"ts":"2026-10-21T03:12:00+0300","kind":"sensitive_open","pid":"1234","uid":"1000","comm":"curl","target":"<sensitive:abc123>"}'
out="$(YMIR_HOME="$TMP/home" GARMR_STATE_DIR="$TMP/state3" GARMR_ESCALATE_BASE="http://127.0.0.1:18441/v1" \
  GARMR_ESCALATE_TIMEOUT=10 python3 "$GARMR/escalate.py" --finding "$FINDING" --severity CRITICAL 2>&1)"; rc=$?
kill "$STUB" 2>/dev/null
case "$out" in *'"rung": "online"'*) pass "ladder reaches the online rung" ;; *) fail "ladder online" "$out" ;; esac
case "$out" in *STUB*) pass "the reasoner's answer is returned" ;; *) fail "ladder answer" "$out" ;; esac
case "$out" in *'"payload_bytes"'*) pass "the payload size is recorded" ;; *) fail "ladder payload" "$out" ;; esac
out2="$(YMIR_HOME="$TMP/home" GARMR_STATE_DIR="$TMP/state4" GARMR_ESCALATE_BASE="http://127.0.0.1:1/v1" \
  GARMR_ESCALATE_TIMEOUT=2 python3 "$GARMR/escalate.py" --finding "$FINDING" --severity CRITICAL 2>&1)"
case "$out2" in *'"degraded": true'*) pass "an unreachable ladder degrades loudly" ;; *) fail "ladder degrade" "$out2" ;; esac

echo
if [ "$fails" -eq 0 ]; then
  echo "garmr.test: all assertions pass"
  exit 0
fi
echo "garmr.test: $fails failure(s)" >&2
exit 1
