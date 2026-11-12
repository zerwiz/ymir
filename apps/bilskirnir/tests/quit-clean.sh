#!/usr/bin/env bash
# The shell must quit cleanly when its window is closed — while waiting for the hall (silent hall) and after
# it loaded (a stub hall). Passes when the process exits 0 within the limit and systemd-coredump gained no core.
# Headless (ozone headless), so it needs no display. Skips cleanly where electron is not installed (RULES/25).
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
EL="${ELECTRON_BIN:-$(command -v electron || ls /usr/lib/electron*/electron 2>/dev/null | head -1)}"
[ -x "${EL:-}" ] || { echo "quit-clean: no electron installed — skipped (a skip is a pass)"; exit 0; }
cores() { command -v coredumpctl >/dev/null && coredumpctl list --no-pager 2>/dev/null | grep -c electron || echo 0; }
fail=0
run() { # name, close_ms, boot_timeout, url
  local before after rc
  before="$(cores)"
  BILSKIRNIR_URL="$4" BILSKIRNIR_BOOT_TIMEOUT="$3" QUIT_CLOSE_MS="$2" \
    timeout 20 "$EL" --no-sandbox --ozone-platform=headless --disable-gpu "$here/quit-clean.js" >/dev/null 2>&1
  rc=$?
  sleep 1; after="$(cores)"
  if [ "$rc" -eq 0 ] && [ "$after" -eq "$before" ]; then echo "PASS $1 (exit 0, cores $before -> $after)"
  else echo "FAIL $1 (exit $rc, cores $before -> $after)"; fail=1; fi
}
run "closed while waiting for the hall" 800 10 "http://127.0.0.1:9"
# a stub hall that answers /api/health
port=$((20000 + RANDOM % 20000))
python3 -c "
import http.server,sys
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(s): s.send_response(200); s.send_header('content-type','text/html'); s.end_headers(); s.wfile.write(b'<title>x</title>ok')
    def log_message(*a): pass
http.server.HTTPServer(('127.0.0.1',$port),H).serve_forever()" & stub=$!
sleep 0.5
run "closed after the hall loaded" 2500 10 "http://127.0.0.1:$port"
kill "$stub" 2>/dev/null
exit "$fail"
