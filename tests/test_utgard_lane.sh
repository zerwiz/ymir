#!/usr/bin/env bash
# test_utgard_lane.sh — best of N: one brief, many boxes, one board, one lease.
#
# What must hold:
#   * a lane is a set of boxes that differ in ONE declared way, and says which;
#   * the same brief and the same command reach every lane;
#   * the lanes queue on ONE lease, because the rail serves one model at a time;
#   * the board says what each lane did and how long it took, and it ends in the
#     operator's pick — no lane merges itself.
#
# A clean skip is a pass (RULES/25). The suite uses a stub upstream, so it never
# touches the real rail.
#
#   bash tests/test_utgard_lane.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOX="$ROOT/bin/forge/utgard-box.sh"
LANE="$ROOT/bin/forge/utgard-lane.sh"
ENGINE="${YMIR_CONTAINER_ENGINE:-docker}"
TAG="${UTGARD_BOX_IMAGE:-utgard-box:latest}"
NET="utgard-test-door-net"
STUB="stubrail"
PREFIX="utgardtest"

export UTGARD_BOX_PREFIX="$PREFIX"
export UTGARD_BOX_DOOR_NET="$NET"
export UTGARD_BOX_RAIL_TARGET="$STUB:8080"
export UTGARD_BOX_KEY="testkey-not-a-real-secret"
export UTGARD_BOX_IMAGE="$TAG"
LEASEDIR="$(mktemp -d)"
export UTGARD_LANE_LEASE="$LEASEDIR/lane.lock"

pass=0; fail=0; skip=0
ok()   { pass=$((pass+1)); printf 'ok   : %s\n' "$*"; }
bad()  { fail=$((fail+1)); printf 'FAIL : %s\n' "$*"; }
skip() { skip=$((skip+1)); printf 'skip : %s\n' "$*"; }
summary() { printf 'utgard-lane-tests: %s pass, %s fail, %s skip\n' "$pass" "$fail" "$skip"; }

command -v "$ENGINE" >/dev/null 2>&1 || { skip "no container engine ($ENGINE) — nothing to prove here"; summary; exit 0; }
"$ENGINE" info >/dev/null 2>&1 || { skip "the engine is installed but not reachable — no daemon"; summary; exit 0; }
"$ENGINE" image inspect "$TAG" >/dev/null 2>&1 || { skip "box image $TAG is absent — build it with: utgard box build"; summary; exit 0; }

TMP="$(mktemp -d)"
cleanup() {
  "$LANE" rm ln1 >/dev/null 2>&1 || true
  "$ENGINE" rm -f "$STUB" >/dev/null 2>&1 || true
  "$ENGINE" network rm "$NET" >/dev/null 2>&1 || true
  rm -rf "$TMP" "$LEASEDIR"
}
trap cleanup EXIT

cat > "$TMP/stub.py" <<'STUBPY'
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        body = json.dumps({"data": [{"id": "stub-model"}]}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *a): pass
HTTPServer(("0.0.0.0", 8080), H).serve_forever()
STUBPY

if ! "$ENGINE" network inspect "$NET" >/dev/null 2>&1; then
  "$ENGINE" network create "$NET" >/dev/null 2>&1 \
    || { skip "could not create a door network for the stub — nothing to prove"; summary; exit 0; }
fi
"$ENGINE" rm -f "$STUB" >/dev/null 2>&1 || true
if ! stub_err="$("$ENGINE" run -d --name "$STUB" --network "$NET" -v "$TMP/stub.py:/stub.py:ro" \
      "$TAG" python3 /stub.py 2>&1)"; then
  skip "could not raise the stub rail — the lane tests need it"
  printf '%s\n' "$stub_err" | sed 's/^/       engine: /' >&2
  summary; exit 0
fi
for _ in $(seq 1 20); do
  "$ENGINE" exec "$STUB" bash -lc 'timeout 1 bash -c "exec 3<>/dev/tcp/127.0.0.1/8080"' >/dev/null 2>&1 && break
  sleep 0.3
done

printf 'do the work\n' > "$TMP/brief.md"

# --- refusals first: a lane that is not a comparison is refused ---------------
"$LANE" new bad1 --brief "$TMP/brief.md" >/dev/null 2>&1 && bad "a lane with no --lane is refused" || ok "a lane with no --lane is refused"
"$LANE" new bad2 --lane 'a=stub-model' >/dev/null 2>&1 && bad "a lane with no brief is refused" || ok "a lane with no brief is refused"
"$LANE" new bad3 --brief "$TMP/brief.md" --lane 'noseparator' >/dev/null 2>&1 && bad "a malformed lane spec is refused" || ok "a malformed lane spec is refused"
UTGARD_LANE_TAILNET_TARGET="" "$LANE" new bad4 --brief "$TMP/brief.md" --lane 'a=stub-model@tailnet' >/dev/null 2>&1 \
  && bad "a tailnet lane with no target is refused" || ok "a tailnet lane with no target is refused (no address in a script)"

# --- new: three lanes, one brief, one declared difference --------------------
if out="$("$LANE" new ln1 --brief "$TMP/brief.md" \
      --lane 'harness-a=stub-model' \
      --lane 'harness-b=stub-model' \
      --lane 'model-two=stub-model' \
      --ttl 10m --budget 5 --command 'echo lane-hello; echo second-line' 2>&1)"; then
  ok "a lane of three boxes is raised"
else
  bad "a lane of three boxes is raised — output: ${out:0:200}"
  summary; exit 1
fi

count="$("$ENGINE" ps -a --filter "label=ymir.utgard.lane=ln1" --format '{{.Names}}' 2>/dev/null | wc -l | tr -d ' ')"
[ "$count" = "3" ] && ok "three boxes carry the lane label" || bad "three boxes carry the lane label (got $count)"
labels="$("$ENGINE" inspect --format '{{ index .Config.Labels "ymir.utgard.lane_label" }}{{ index .Config.Labels "ymir.utgard.lane_where" }}' "${PREFIX}-lane-ln1-0" 2>/dev/null)"
[ "$labels" = "harness-alocal" ] && ok "each box says which lane it is, and where its model lives" \
  || bad "each box says which lane it is (got '$labels')"
brief="$("$BOX" run "lane-ln1-0" -- 'cat /box/brief.md 2>/dev/null' 2>/dev/null)"
[ "$brief" = "do the work" ] && ok "the same brief reached the lane (a copy, not a mount)" \
  || bad "the same brief reached the lane (got '${brief:0:30}')"

# --- run: the lease, then every lane in turn ----------------------------------
runout="$("$LANE" run ln1 2>&1)"
case "$runout" in *"lane[2]{name,lease}"*) ok "the run names its lease" ;; *) bad "the run names its lease" ;; esac
[ -f "$UTGARD_LANE_LEASE" ] && ok "the rail lease is a real file, held for the run" || bad "the rail lease is a real file"
rows="$(printf '%s' "$runout" | grep -c '^  "[0-9]","')"
[ "$rows" = "3" ] && ok "all three lanes ran" || bad "all three lanes ran (got $rows rows)"

# --- board: what each lane did, and the pick is his ---------------------------
board="$("$LANE" board ln1 2>&1)"
case "$board" in *"board[6]{lane,label,model,where,wall_s,one_line}"*) ok "the board names what it compares" ;; *) bad "the board names what it compares" ;; esac
case "$board" in *"second-line"*) ok "the board carries each lane's own LAST line" ;; *) bad "the board carries each lane's own LAST line" ;; esac
case "$board" in *"HIS pick"*) ok "the board ends in the operator's pick, not a merge" ;; *) bad "the board ends in the operator's pick, not a merge" ;; esac
brows="$(printf '%s' "$board" | grep -c '^  "[0-9]","')"
[ "$brows" = "3" ] && ok "the board has a row per lane" || bad "the board has a row per lane (got $brows)"
case "$board" in *FAILED*) bad "a lane that succeeded is not marked failed" ;; *) ok "a lane that succeeded is not marked failed" ;; esac

# --- list, and teardown ------------------------------------------------------
"$LANE" list 2>/dev/null | grep -q '"ln1","3"' && ok "list shows the lane and its boxes" || bad "list shows the lane and its boxes"
"$LANE" rm ln1 >/dev/null 2>&1
left="$("$ENGINE" ps -a --filter "label=ymir.utgard.lane=ln1" --format '{{.Names}}' 2>/dev/null | wc -l | tr -d ' ')"
[ "$left" = "0" ] && ok "rm takes every box of the lane, and its door" || bad "rm takes every box of the lane (left $left)"

summary
[ "$fail" = 0 ]
