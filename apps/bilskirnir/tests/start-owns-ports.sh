#!/usr/bin/env bash
# start.sh keeps only its own pieces. Stub servers on free ports stand in for a stale dev server from
# another tree: a stranger must be named and refused (or, when it is another Bilskirnir tree, lowered),
# a server that answers but does not serve the face must not count as up, and our own is kept.
set -uo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; PIDS=()
cleanup() { for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done; rm -rf "$T"; }
trap cleanup EXIT
fail=0; ok() { echo "ok   $1"; }; bad() { echo "FAIL $1"; fail=1; }
free_port() { python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1])'; }

# A stub that answers /api/health with 200 and serves "/" as the face (FACE=1) or 404 (FACE=0), from a given cwd.
stub() { # dir port face
  mkdir -p "$1"
  ( cd "$1" && exec python3 -c '
import sys,http.server
face=sys.argv[2]=="1"
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(s):
        if s.path=="/api/health": s.send_response(200); s.end_headers(); s.wfile.write(b"ok")
        elif s.path=="/" and face: s.send_response(200); s.end_headers(); s.wfile.write(b"<!doctype html><div id=root></div>")
        else: s.send_response(404); s.end_headers(); s.wfile.write(b"Not Found")
    def log_message(*a): pass
http.server.HTTPServer(("127.0.0.1",int(sys.argv[1])),H).serve_forever()' "$2" "$3" ) &
  PIDS+=($!); sleep 0.6
}

# A fake app tree: a copy of start.sh beside a stub setup.sh and a .env.
mkapp() { # root port
  mkdir -p "$1/apps/bilskirnir/data/run" "$1/apps/bilskirnir/web/dist" "$1/engine"
  cp "$SRC/start.sh" "$1/apps/bilskirnir/start.sh"
  printf '#!/bin/sh\nexit 0\n' > "$1/apps/bilskirnir/setup.sh"; chmod +x "$1/apps/bilskirnir/setup.sh"
  printf '<!doctype html>' > "$1/apps/bilskirnir/web/dist/index.html"
  printf 'PORT=%s\nHERMES_HOME_PRIMARY=%s\nHERMES_BIN=/nonexistent-hermes\n' "$2" "$1/engine" > "$1/apps/bilskirnir/.env"
  printf 'API_SERVER_PORT=%s\n' "$(free_port)" > "$1/engine/.env"
}

# 1 · a foreign process (not a Bilskirnir tree) holds the port, answers /api/health, no face → refused, named, not killed
P1="$(free_port)"; mkapp "$T/a" "$P1"; stub "$T/stranger" "$P1" 0; SP=$!
out="$("$T/a/apps/bilskirnir/start.sh" --headless 2>&1)"; rc=$?
[ "$rc" != 0 ] && ok "stranger: start refuses (rc $rc)" || bad "stranger: start did not refuse"
echo "$out" | grep -q "STRANGER" && echo "$out" | grep -q "pid ${PIDS[-1]}" && ok "stranger: named by pid" || bad "stranger: not named — $out"
echo "$out" | grep -q "kill ${PIDS[-1]}" && ok "stranger: the lowering command is given" || bad "stranger: no kill command"
kill -0 "${PIDS[-1]}" 2>/dev/null && ok "stranger: not killed" || bad "stranger: was killed"
echo "$out" | grep -q "already answers" && bad "stranger: claimed 'kept'" || ok "stranger: never 'kept'"

# 2 · --check calls the same stranger out and exits 1
out="$("$T/a/apps/bilskirnir/start.sh" --check 2>&1)"; rc=$?
[ "$rc" = 1 ] && echo "$out" | grep -q "NOT served" && ok "check: face not served → exit 1" || bad "check: $rc — $out"

# 3 · a sibling Bilskirnir tree (cwd under */apps/bilskirnir/*) of this user is lowered; the port frees
P3="$(free_port)"; mkapp "$T/b" "$P3"; stub "$T/old/apps/bilskirnir/server" "$P3" 0; OLD=${PIDS[-1]}
claim_out="$(BASH_SOURCE_TEST=1 bash -c '
  APP="'"$T"'/b/apps/bilskirnir"; RUN="$APP/data/run"; ENGINE="'"$T"'/b/engine"
  say() { printf "%s %s\n" "$1" "$2"; }
  eval "$(sed -n "/^listeners()/,/^alive()/p" "'"$SRC"'/start.sh" | sed "\$d")"
  claim server '"$P3"' "the server"; echo "rc=$?"' 2>&1)"
echo "$claim_out" | grep -q "another Bilskirnir tree" && echo "$claim_out" | grep -q "rc=1" && ok "sibling: lowered, port free (rc 1)" || bad "sibling: $claim_out"
sleep 0.3; kill -0 "$OLD" 2>/dev/null && bad "sibling: still alive" || ok "sibling: process gone"

# 4 · our own server (cwd inside the app tree) that serves the face is kept
P4="$(free_port)"; mkapp "$T/c" "$P4"; stub "$T/c/apps/bilskirnir/server" "$P4" 1
out="$("$T/c/apps/bilskirnir/start.sh" --headless 2>&1)"; rc=$?
echo "$out" | grep -q "serves the face — kept (ours)" && [ "$rc" = 0 ] && ok "ours: kept, face served" || bad "ours: rc $rc — $out"
out="$("$T/c/apps/bilskirnir/start.sh" --check 2>&1 | grep -c STRANGER)"; [ "$out" = 0 ] && ok "ours: --check sees no stranger" || bad "ours: check flagged a stranger"

# 5 · ours, answering, but GET / is not the face → not "up"
P5="$(free_port)"; mkapp "$T/d" "$P5"; stub "$T/d/apps/bilskirnir/server" "$P5" 0
out="$("$T/d/apps/bilskirnir/start.sh" --headless 2>&1)"; rc=$?
[ "$rc" != 0 ] && echo "$out" | grep -q "not serving the face" && ok "no face: refused though the port answers" || bad "no face: rc $rc — $out"

exit "$fail"
