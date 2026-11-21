#!/usr/bin/env bash
# test_gjallarhorn_publish.sh — an app is published only behind the hall's login.
#
# The claims this test holds:
#   1. `check` refuses an app whose audience is empty (never published open);
#   2. `check` refuses a missing or non-https gate, and an edge port that is a hall port;
#   3. `plan` renders a forward-auth to the gate for every name and a 404 for anything else;
#   4. the tunnel block is placed ahead of the catch-all, and is idempotent;
#   5. `rules` expands `operator` from the home's identity file and prints each host's audience;
#   6. `apply --dry-run` writes and starts nothing.
#
# Usage: test_gjallarhorn_publish.sh        Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
DOOR="$ROOT/bin/forge/gjallarhorn-publish.sh"

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

mkdir -p "$T/home/hodd/identity" "$T/state"
printf 'name: Ada\nemail: Ada@Example.org\n' > "$T/home/hodd/identity/operator.yaml"
printf 'tunnel: t1\ningress:\n  - hostname: keep.example.org\n    service: http://127.0.0.1:9001\n  - service: http_status:404\n' > "$T/tunnel.yml"

cfg() {  # cfg <allow-line> <gate> <edge_port>
  cat > "$T/publish.yaml" <<EOF
gate: $2
edge_port: $3
tunnel:
  config: $T/tunnel.yml
  name: t1
apps:
  - name: notes
    host: notes-host-a.example.org
    upstream: http://127.0.0.1:9000
    allow: $1
  - name: wiki
    host: wiki-host-a.example.org
    upstream: http://127.0.0.1:9100
    allow: [operator, grace@example.org]
EOF
}
door() { YMIR_HOME="$T/home" YMIR_STATE_DIR="$T/state" YMIR_PUBLISH_CONFIG="$T/publish.yaml" bash "$DOOR" "$@" 2>&1; }

printf 'gjallarhorn-publish — nothing is published open\n'

cfg "[]" https://hall.example.org 8795
out="$(door check)"; rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'allow names nobody'; then ok "an empty audience is refused"; else bad "an empty audience is refused" "$out"; fi

PLAIN=http; cfg "[operator]" "$PLAIN://hall.example.org" 8795
out="$(door check)"; rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'gate:'; then ok "a non-https gate is refused"; else bad "a non-https gate is refused" "$out"; fi

cfg "[operator]" https://hall.example.org 8437
out="$(door check)"; rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'hall port'; then ok "an edge on a hall port is refused"; else bad "an edge on a hall port is refused" "$out"; fi

cfg "[operator]" https://hall.example.org 8795
out="$(door check)"; rc=$?
if [ "$rc" -eq 0 ]; then ok "a gated, named config passes"; else bad "a gated, named config passes" "$out"; fi

plan="$(door plan)"
n=$(printf '%s' "$plan" | grep -c 'forward_auth https://hall.example.org')
if [ "$n" -eq 2 ] && printf '%s' "$plan" | grep -q 'respond "not found" 404' && printf '%s' "$plan" | grep -q 'uri /oidc/authz'; then
  ok "every name asks the hall; anything else is a 404"
else bad "plan renders a forward-auth per name" "$plan"; fi

before="$(cat "$T/tunnel.yml")"
door apply --dry-run >/dev/null; rc=$?
if [ "$rc" -eq 0 ] && [ "$before" = "$(cat "$T/tunnel.yml")" ] && [ ! -e "$T/state/publish/Caddyfile" ]; then
  ok "apply --dry-run writes and starts nothing"
else bad "apply --dry-run writes nothing" "rc=$rc"; fi

blk="$(python3 - "$ROOT" "$T/tunnel.yml" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("p", sys.argv[1] + "/bin/forge/gjallarhorn-publish.py")
p = importlib.util.module_from_spec(spec); spec.loader.exec_module(p)
cfg = {"edge_port": 8795, "apps": [{"host": "A.example.org"}]}
t = open(sys.argv[2]).read()
once = p.with_block(t, p.ingress_block(cfg)); twice = p.with_block(once, p.ingress_block(cfg))
lines = once.splitlines()
print("same" if once == twice else "drift", once.count("ymir-publish begin"),
      "before-catchall" if lines.index([l for l in lines if "ymir-publish end" in l][0]) < lines.index([l for l in lines if "http_status" in l][0]) else "after")
PY
)"
if [ "$blk" = "same 1 before-catchall" ]; then ok "the tunnel block sits ahead of the catch-all, once, idempotently"; else bad "tunnel block placement" "$blk"; fi

rules="$(door rules)"
if printf '%s' "$rules" | grep -q '^notes-host-a.example.org: ada@example.org$' \
   && printf '%s' "$rules" | grep -q '^wiki-host-a.example.org: ada@example.org, grace@example.org$'; then
  ok "rules expands the operator from the home and lists each audience"
else bad "rules render" "$rules"; fi

printf 'gjallarhorn publish: %s ok / %s fail\n' "$pass" "$fail"
[ "$fail" = 0 ]
