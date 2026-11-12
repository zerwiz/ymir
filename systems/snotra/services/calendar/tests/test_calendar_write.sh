#!/usr/bin/env bash
# test_calendar_write.sh — the write door's proofs, offline, against a local fixture.
#
# Plan 231 §2/R2. The door under test is the real `calendar-write.sh`; Google is stood in for by
# `tests/calendar_fixture.py` and the endpoints are configuration (Rule 07). Nothing here talks
# to Google, and nothing here mocks the door.
#
# The five things that must hold:
#   1. without `calendar.events` the door REFUSES, names the scope, and posts nothing;
#   2. with it, `create` posts the event it said it would, at the instant it said;
#   3. `move` patches the meeting and reports the OLD time so it can be checked;
#   4. two meetings matching a spoken title is a refusal that lists them — never a guess;
#   5. an unmeasurable scope is not a green: Google's own 403 becomes the named refusal.
#
#   bash systems/snotra/services/calendar/tests/test_calendar_write.sh
# Exit: 0 every proof held · 1 a proof failed.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CAL_DIR="$(cd "$HERE/.." && pwd)"
DOOR="$CAL_DIR/calendar-write.sh"
WRITE_SCOPE="https://www.googleapis.com/auth/calendar.events"
READ_SCOPE="https://www.googleapis.com/auth/calendar.events.readonly"

TMP="$(mktemp -d)"
PIDS=()
cleanup() { for p in "${PIDS[@]:-}"; do [ -n "$p" ] && kill "$p" 2>/dev/null; done; rm -rf "$TMP"; }
trap cleanup EXIT

FAILED=0
pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; FAILED=1; }

# a fixture on a free port; sets PORT and STATE
fixture() {  # <label> [fixture flags...]
  local label="$1"; shift
  local port_file="$TMP/port-$label" state="$TMP/state-$label.json"
  : >"$state"
  python3 "$HERE/calendar_fixture.py" --port-file "$port_file" --state "$state" "$@" &
  PIDS+=("$!")
  for _ in $(seq 1 100); do [ -s "$port_file" ] && break; sleep 0.05; done
  [ -s "$port_file" ] || { printf 'fixture %s never answered\n' "$label" >&2; exit 1; }
  PORT="$(cat "$port_file")"; STATE="$state"
}

# the vault is a KEY=value file for the proofs (the door reads the real one otherwise)
SECRETS="$TMP/secrets.env"
cat >"$SECRETS" <<EOF
GOOGLE_MCP_CLIENT_ID=fixture-client
GOOGLE_MCP_CLIENT_SECRET=fixture-secret
SNOTRA_GOOGLE_REFRESH_TOKEN=fixture-refresh
EOF

door() {  # <args...> — the real door, pointed at the fixture
  CALENDAR_SECRETS_FILE="$SECRETS" \
  YMIR_OAUTH_TOKEN_URL="http://127.0.0.1:$PORT/token" \
  YMIR_OAUTH_TOKENINFO_URL="http://127.0.0.1:$PORT/tokeninfo" \
  YMIR_CALENDAR_API_BASE="http://127.0.0.1:$PORT/calendar/v3" \
  YMIR_TZ="Europe/Stockholm" \
  bash "$DOOR" "$@"
}

writes() { python3 - "$STATE" <<'PY'
import json, sys
try:
    rows = json.load(open(sys.argv[1]))
except Exception:
    print(0); raise SystemExit(0)
print(sum(1 for r in rows if r["kind"] in ("create", "patch")))
PY
}

# ── 1 · no scope, no write ───────────────────────────────────────────────────────────────────
printf 'the scope is the gate\n'
fixture readonly --scope "$READ_SCOPE"
out="$(door create --title "Proof meeting" --when "2030-01-02 09:00" 2>&1)"; rc=$?
[ "$rc" = 3 ] && pass "read-only grant is refused (exit 3)" || fail "read-only grant exited $rc, wanted 3"
case "$out" in *calendar.events*) pass "the refusal names calendar.events" ;;
  *) fail "the refusal did not name the scope: $out" ;; esac
[ "$(writes)" = 0 ] && pass "nothing was posted" || fail "a write reached the API without the scope"

out="$(door status 2>&1)"; rc=$?
[ "$rc" = 3 ] && pass "status says read-only (exit 3)" || fail "status exited $rc, wanted 3"
case "$out" in *read-only*) pass "status names the state" ;; *) fail "status said: $out" ;; esac

# ── 2 · with the scope, create posts what it promised ───────────────────────────────────────
printf 'create, with the scope\n'
fixture write --scope "$WRITE_SCOPE"
out="$(door create --title "Proof meeting" --when "2030-01-02 09:00" --duration 45m 2>&1)"; rc=$?
[ "$rc" = 0 ] && pass "create succeeded (exit 0)" || fail "create exited $rc: $out"
case "$out" in *created*) pass "the door reported the created event" ;; *) fail "create said: $out" ;; esac
python3 - "$STATE" <<'PY' && pass "the posted body is 09:00→09:45 in the operator's zone" || fail "the posted body is wrong"
import json, sys
rows = json.load(open(sys.argv[1]))
body = [r["body"] for r in rows if r["kind"] == "create"][0]
s, e = body["start"], body["end"]
assert s["dateTime"].startswith("2030-01-02T09:00:00"), s
assert e["dateTime"].startswith("2030-01-02T09:45:00"), e
assert s["timeZone"] == "Europe/Stockholm", s
PY

# ── 3 · move patches, and reports the old time ──────────────────────────────────────────────
printf 'move, by title\n'
out="$(door move "Standup" --to "2030-01-02 14:00" --duration 30m 2>&1)"; rc=$?
[ "$rc" = 0 ] && pass "move succeeded (exit 0)" || fail "move exited $rc: $out"
case "$out" in *"08:00"*) pass "the answer carries the OLD start" ;; *) fail "move did not report the old time: $out" ;; esac
case "$out" in *"mail: none"*) pass "the door says nobody was mailed" ;; *) fail "the move claimed a mail it did not send: $out" ;; esac
python3 - "$STATE" <<'PY' && pass "the patch carried the new instant and sendUpdates=none" || fail "the patch body/query is wrong"
import json, sys
rows = json.load(open(sys.argv[1]))
patch = [r["body"] for r in rows if r["kind"] == "patch"][-1]
assert patch["path"].endswith("/events/ev-standup"), patch["path"]
assert "sendUpdates=none" in patch["query"], patch["query"]
assert patch["start"]["dateTime"].startswith("2030-01-02T14:00:00"), patch["start"]
PY

# ── 4 · two matches is a refusal that lists them ────────────────────────────────────────────
printf 'ambiguity is refused, never guessed\n'
before="$(writes)"
out="$(door move "Example4 review" --to "2030-01-03 15:00" 2>&1)"; rc=$?
[ "$rc" = 3 ] && pass "two matches is a refusal (exit 3)" || fail "two matches exited $rc, wanted 3"
case "$out" in *ev-two-a*) pass "the refusal lists the first match" ;; *) fail "no list: $out" ;; esac
case "$out" in *ev-two-b*) pass "the refusal lists the second match" ;; *) fail "no list: $out" ;; esac
[ "$(writes)" = "$before" ] && pass "nothing was patched" || fail "a guessed meeting was moved"

# ── 5 · an unmeasurable scope is not a green ────────────────────────────────────────────────
printf 'the vendor is the last word\n'
fixture blinded --tokeninfo-500 --api-403
out="$(door move "Standup" --to "2030-01-02 16:00" 2>&1)"; rc=$?
[ "$rc" = 3 ] && pass "Google's 403 becomes a refusal (exit 3)" || fail "403 exited $rc, wanted 3"
case "$out" in *calendar.events*) pass "the refusal names the scope Google demanded" ;;
  *) fail "the 403 refusal did not name the scope: $out" ;; esac

printf '\n'
[ "$FAILED" = 0 ] && { printf 'calendar-write: every proof held\n'; exit 0; }
printf 'calendar-write: a proof FAILED\n'; exit 1
