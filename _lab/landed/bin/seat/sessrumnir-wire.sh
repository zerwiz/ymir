#!/usr/bin/env bash
# sessrumnir-wire.sh — the seat wire: talk to a Sessrúmnir seat, and read its last answer.
#
# Sessrúmnir (apps/sessrumnir) is the desktop seat over the pi and omp agents. Its
# headless shell already serves a bridge on one port, and a bridge call is
# `POST /api/<channel>`. Until now no door spoke those channels, so a voice or an
# agent could see a worker in herdr but had no way to reach a seat someone opened by
# hand — the gap plan 231 names ("rödd have no tools to talk to eindris … why cant
# rödd talk to … the eindris in herdr").
#
#   sessrumnir-wire.sh seats                     every seat the shell holds, and its state
#   sessrumnir-wire.sh send <seat|active> <line> one line into that seat's own session
#   sessrumnir-wire.sh read [<seat|active>] [--chars N]  the last answer it gave
#   sessrumnir-wire.sh status                    is the shell answering at all
#   sessrumnir-wire.sh --self-test               prove all three verbs against a fixture
#
# THE SHELL IS THE AUTHORITY, AND ITS SILENCE IS SAID PLAINLY. A seat only answers
# while the app is running; when nothing answers this door refuses with the address it
# tried and the one command that raises the shell. It never reports a line as sent when
# nobody received it (the false green this house has paid for twice).
#
# Exit: 0 done · 3 the shell is not answering · 2 usage · 1 the door itself failed.
set -u
VERSION="1.0.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"
RAISER="$ROOT/apps/sessrumnir/bin/sessrumnir-web.sh"

# Rule 07 — one resolver, one documented default: the shell's own fixed port.
# Read at call time, so a test (and a human) can point the door at another shell.
bridge_url() { printf '%s' "${SESSRUMNIR_BRIDGE:-http://127.0.0.1:${SESSRUMNIR_PORT:-3890}}"; }
TIMEOUT="${SESSRUMNIR_WIRE_TIMEOUT:-20}"
CHARS_DEFAULT="${SESSRUMNIR_WIRE_CHARS:-900}"

EXIT_NO_SHELL=3
EXIT_USAGE=2

usage() { sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//'; }

die()  { printf 'error: %s\n' "$*" >&2; exit "$EXIT_USAGE"; }
no_shell() {
  printf 'sessrumnir-wire[1]{state,bridge,why}:\n  "no shell","%s","nothing answered there — a seat only answers while the app is running"\n' "$(bridge_url)" >&2
  printf 'help: %s start   (then: %s seats)\n' "$RAISER" "$0" >&2
  exit "$EXIT_NO_SHELL"
}

# _post <channel> <json-array-of-args> → prints "<http_code>\n<body>".
# A silent shell yields code 000 and an empty body; the CALLER decides that the shell
# is down (a `no_shell` raised inside a command substitution would only leave the
# subshell, and the refusal would be swallowed — the fault this test exists to catch).
_post() {
  local channel="$1" args_json="$2" out code body
  out="$(curl -sS -m "$TIMEOUT" -o /dev/stdout -w '\n%{http_code}' \
      -X POST -H 'Content-Type: application/json' \
      --data "$args_json" "$(bridge_url)/api/$channel" 2>/dev/null)" || out="000"
  [ -n "$out" ] || out="000"
  code="${out##*$'\n'}"
  body="${out%$'\n'*}"
  [ "$out" = "000" ] && code="000" && body=""
  printf '%s\n%s\n' "$code" "$body"
}

_assert_ok() {  # <code> <body> <what>
  local code="$1" body="$2" what="$3"
  case "$code" in
    2*) return 0 ;;
    000|"") no_shell ;;
  esac
  printf 'sessrumnir-wire[1]{verb,failed,detail}:\n  "%s","%s","%s"\n' "$what" "$code" "$(printf '%s' "$body" | head -c 300)" >&2
  exit 1
}

verb_status() {
  local out code
  out="$(_post 'workspace:get-active' '[]')"
  code="${out%%$'\n'*}"; out="${out#*$'\n'}"
  _assert_ok "$code" "$out" status
  printf 'sessrumnir-wire[2]{state,bridge}:\n  "up","%s"\n' "$(bridge_url)"
  printf '%s' "$out" | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: d={}
print("active: %s" % (d.get("name") or d.get("id") or "none"))
'
}

verb_seats() {
  local out code
  out="$(_post 'seat:list' '[]')"
  code="${out%%$'\n'*}"; out="${out#*$'\n'}"
  _assert_ok "$code" "$out" seats
  printf '%s' "$out" | python3 -c '
import json,sys
d=json.load(sys.stdin)
seats = d if isinstance(d,list) else (d.get("seats") or [])
if not seats:
    print("sessrumnir-wire[1]{state,detail}:\n  \"no seats\",\"the shell answers but holds no workspace — open one in Sessrúmnir\"")
    raise SystemExit(0)
print("sessrumnir-wire[%d]{seat,path,state,pid,active}:" % len(seats))
for s in seats:
    q=lambda v: chr(34)+str(v if v is not None else "").replace(chr(34),chr(39))+chr(34)
    print("  %s,%s,%s,%s,%s" % (q(s.get("name") or s.get("id")), q(s.get("path")),
          q(s.get("status") or "unknown"), q(s.get("pid") or "-"),
          q("yes" if s.get("active") else "no")))
'
}

verb_send() {
  local seat="${1:-}"; shift || true
  local line="${*:-}"
  [ -n "$seat" ] && [ -n "$line" ] || die "send needs a seat and one line"
  local out code
  out="$(_post 'seat:prompt' "$(python3 -c 'import json,sys;print(json.dumps([sys.argv[1],sys.argv[2]]))' "$seat" "$line")")"
  code="${out%%$'\n'*}"; out="${out#*$'\n'}"
  _assert_ok "$code" "$out" send
  printf 'sessrumnir-wire[2]{seat,state}:\n  "%s","sent"\n' "$seat"
}

verb_read() {
  local seat="active" chars="$CHARS_DEFAULT"
  while [ $# -gt 0 ]; do
    case "$1" in
      --chars) chars="${2:-$CHARS_DEFAULT}"; shift 2 ;;
      *) seat="${1:-active}"; shift ;;
    esac
  done
  local out code
  out="$(_post 'seat:last-answer' "$(python3 -c 'import json,sys;print(json.dumps([sys.argv[1],int(sys.argv[2])]))' "$seat" "$chars")")"
  code="${out%%$'\n'*}"; out="${out#*$'\n'}"
  _assert_ok "$code" "$out" read
  printf '%s' "$out" | python3 -c '
import json,sys
d=json.load(sys.stdin)
text=(d.get("text") or "").strip()
if not text:
    print("sessrumnir-wire[1]{state,detail}:\n  \"no answer\",\"%s\"" % (d.get("detail") or "that seat has no answer recorded yet"))
    raise SystemExit(0)
print("sessrumnir-wire[3]{seat,answered_at,chars}:")
print("  \"%s\",\"%s\",\"%d\"" % (d.get("seat") or "active", d.get("at") or "", len(text)))
print(text)
'
}

# ── the fixture: prove the three verbs without the desktop app ────────────────
self_test() {
  local tmp port log pid rc=0
  tmp="$(mktemp -d)"; log="$tmp/fixture.log"
  port="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
  cat > "$tmp/fixture.py" <<'PY'
import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer

class H(BaseHTTPRequestHandler):
    def log_message(self, *a):  # silence
        pass
    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("content-length") or 0))
        try: args = json.loads(body or b"[]")
        except Exception: args = []
        ch = self.path.rsplit("/", 1)[-1]
        seats = [{"id": "ws-1", "name": "sessrumnir-wire-fixture", "path": "/tmp/fixture",
                  "active": True, "status": "running", "pid": 4242}]
        if ch == "workspace:get-active":
            out = {"id": "ws-1", "name": "fixture"}
        elif ch == "seat:list":
            out = seats
        elif ch == "seat:prompt":
            out = {"accepted": True, "seat": args[0] if args else "", "echo": args[1] if len(args) > 1 else ""}
        elif ch == "seat:last-answer":
            out = {"seat": "sessrumnir-wire-fixture", "at": "2026-11-09T03:00:00Z",
                   "text": "the answer a seat gave: " + json.dumps(args)[:120]}
        else:
            self.send_response(404); self.end_headers(); self.wfile.write(b'{"error":"unknown"}'); return
        payload = json.dumps(out).encode()
        self.send_response(200); self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(payload))); self.end_headers(); self.wfile.write(payload)

HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
PY
  python3 "$tmp/fixture.py" "$port" >"$log" 2>&1 &
  pid=$!
  trap 'kill "$pid" 2>/dev/null; rm -rf "$tmp"' RETURN
  local i=0
  while [ "$i" -lt 30 ]; do
    curl -sS -m 1 -o /dev/null "http://127.0.0.1:$port/" 2>/dev/null && break
    i=$((i+1)); sleep 0.1
  done

  SESSRUMNIR_BRIDGE="http://127.0.0.1:$port"
  local out
  out="$(verb_status 2>&1)" || rc=1
  case "$out" in *'"up"'*) printf '  ok   status answers the bridge\n' ;; *) printf '  not ok status answers the bridge: %s\n' "$out"; rc=1 ;; esac
  out="$(verb_seats 2>&1)" || rc=1
  case "$out" in *sessrumnir-wire-fixture*) printf '  ok   seats lists the workspace, its state and its pid\n' ;; *) printf '  not ok seats lists a seat: %s\n' "$out"; rc=1 ;; esac
  out="$(verb_send "sessrumnir-wire-fixture" "hello seat" 2>&1)" || rc=1
  case "$out" in *'"sent"'*) printf '  ok   send hands one line to a seat\n' ;; *) printf '  not ok send hands one line: %s\n' "$out"; rc=1 ;; esac
  out="$(verb_read "sessrumnir-wire-fixture" 2>&1)" || rc=1
  case "$out" in *"the answer a seat gave"*) printf '  ok   read returns the last answer\n' ;; *) printf '  not ok read returns the last answer: %s\n' "$out"; rc=1 ;; esac

  kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
  out="$(SESSRUMNIR_BRIDGE="http://127.0.0.1:$port" verb_seats 2>&1)"; local code=$?
  [ "$code" -eq "$EXIT_NO_SHELL" ] && printf '  ok   a silent shell is refused (exit %s), never faked as "sent"\n' "$EXIT_NO_SHELL" \
    || { printf '  not ok a silent shell is refused (got exit %s)\n' "$code"; rc=1; }
  case "$out" in *"nothing answered"*) printf '  ok   the refusal says the shell is not answering, and names the door\n' ;; *) printf '  not ok the refusal says why\n'; rc=1 ;; esac

  SESSRUMNIR_BRIDGE="http://127.0.0.1:$port"
  [ "$rc" -eq 0 ] && printf 'sessrumnir-wire self-test: all passed\n' || printf 'sessrumnir-wire self-test: FAILED\n'
  return "$rc"
}

case "${1:-}" in
  ""|-h|--help) usage ;;
  -v|--version) printf '%s\n' "$VERSION" ;;
  --self-test|self-test) self_test ;;
  status) shift; verb_status ;;
  seats) shift; verb_seats ;;
  send) shift; verb_send "$@" ;;
  read) shift; verb_read "$@" ;;
  raiser|door) printf '%s\n' "$RAISER" ;;
  *) printf 'error: unknown verb %s\nhelp: seats | send | read | status | --self-test\n' "$1" >&2; exit "$EXIT_USAGE" ;;
esac
