#!/usr/bin/env bash
# calendar-write.sh — make a meeting, or move one: the write door Mánagandr never had.
#
# Mánagandr (calendar-ask.sh) READS his calendar and refuses to write: "the only write
# is the local cache". That left the one thing he asks for — "rödd need to be able to
# make and move meetings in my calendar" (plan 231) — with no door at all.
#
#   calendar-write.sh create --title T --when <ISO> [--minutes N] [--attendees a@x,b@y] [--meet] [--dry-run]
#   calendar-write.sh move <event-id> --to <ISO> [--minutes N] [--notify] [--dry-run]
#   calendar-write.sh scopes                 what the grant actually carries, named
#   calendar-write.sh --self-test            both branches, against a fixture Google
#
# THE GRANT IS MEASURED, NEVER ASSUMED. Google's write scope (`calendar.events`) is
# not in his current grant (the connect door measured it on 2026-11-08). So every
# write first asks the TOKEN what it may do; if `calendar.events` is absent this door
# REFUSES, names the scope, and says how to re-mint the grant. It never falls back to
# a local calendar that looks like success, and never reports an event it did not make.
#
# HOW THE WRITE HAPPENS. `create` is handed to the one existing write door
# (systems/snotra/services/calendar/calendar-invite.sh), which already binds the
# operator's word to the exact event body before any attendee is mailed. `move` has no
# such door, so it lives here — and a move that mails anyone also needs the word.
#
# Endpoints are configuration, never constants (RULES/07): YMIR_CALENDAR_API_BASE and
# YMIR_OAUTH_TOKEN_URL, whose defaults are Google's own.
#
# Exit: 0 done · 3 REFUSED (no scope, or no word) — nothing was written · 2 usage · 1 failed.
set -u
VERSION="1.0.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"
CAL_API="${YMIR_CALENDAR_API_BASE:-https://www.googleapis.com/calendar/v3}"
OAUTH_URL="${YMIR_OAUTH_TOKEN_URL:-https://oauth2.googleapis.com/token}"
TOKENINFO_URL="${YMIR_OAUTH_TOKENINFO_URL:-https://oauth2.googleapis.com/tokeninfo}"
INVITE_DOOR="${YMIR_CALENDAR_INVITE_DOOR:-$ROOT/systems/snotra/services/calendar/calendar-invite.sh}"
APPROVE="$ROOT/systems/snotra/services/approve/snotra-approve.sh"
TZ_NAME="${SO_TZ:-Europe/Helsinki}"

# The two scopes that permit writing events, in the order Google reports them.
SCOPE_EVENTS="https://www.googleapis.com/auth/calendar.events"
SCOPE_FULL="https://www.googleapis.com/auth/calendar"

EXIT_REFUSED=3
EXIT_USAGE=2

usage() { sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'; }
die() { printf 'calendar-write: error: %s\n' "$*" >&2; exit 1; }
usage_die() { printf 'calendar-write: %s\nhelp: create | move | scopes | --self-test\n' "$*" >&2; exit "$EXIT_USAGE"; }

# ── credentials: env first (a test's fixture), then the vault by KEY ──────────
resolve_creds() {
  CID="${YMIR_CALENDAR_CLIENT_ID:-}"; CSEC="${YMIR_CALENDAR_CLIENT_SECRET:-}"; RT="${YMIR_CALENDAR_REFRESH_TOKEN:-}"
  if [ -z "$CID" ] || [ -z "$CSEC" ] || [ -z "$RT" ]; then
    [ -n "${YMIR_HOME:-}" ] || { [ -r "$ROOT/bin/vault/hoard-lib.sh" ] && . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null; }
    [ -n "${YMIR_HOME:-}" ] || ymir_home_root YMIR_HOME 2>/dev/null || true
    local sec="${YMIR_HOME:-}/hodd/secrets" val
    val="$(age -d -i "$sec/age.key" "$sec/platform.env.age" 2>/dev/null || true)"
    get() { printf '%s\n' "$val" | sed -n "s/^$1=//p" | head -1 | sed "s/^['\"]//; s/['\"]$//"; }
    [ -n "$CID" ]  || CID="$(get GOOGLE_MCP_CLIENT_ID)"
    [ -n "$CSEC" ] || CSEC="$(get GOOGLE_MCP_CLIENT_SECRET)"
    [ -n "$RT" ]   || RT="$(get SNOTRA_GOOGLE_REFRESH_TOKEN)"
  fi
  [ -n "$CID" ] && [ -n "$CSEC" ] && [ -n "$RT" ] || {
    printf 'calendar-write[1]{state,why}:\n  "no grant","the vault holds no calendar grant — connect one with bin/mail/connect.sh google"\n' >&2
    exit "$EXIT_REFUSED"; }
}

access_token() {
  local out
  out="$(curl -sS -m 25 -X POST "$OAUTH_URL" \
      -d "client_id=$CID" -d "client_secret=$CSEC" -d "refresh_token=$RT" \
      -d "grant_type=refresh_token" 2>/dev/null)" || return 1
  printf '%s' "$out" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("access_token",""))
except Exception: print("")'
}

grant_scopes() {  # prints one scope per line, measured from the token itself
  local token="$1"
  curl -sS -m 20 "$TOKENINFO_URL?access_token=$token" 2>/dev/null | python3 -c 'import json,sys
try: print("\n".join(str(json.load(sys.stdin).get("scope") or "").split()))
except Exception: pass'
}

# ── the scope gate: refuse by name, or pass ──────────────────────────────────
require_write_scope() {
  local token="$1" scopes
  scopes="$(grant_scopes "$token")"
  if printf '%s\n' "$scopes" | grep -qx "$SCOPE_EVENTS" || printf '%s\n' "$scopes" | grep -qx "$SCOPE_FULL"; then
    return 0
  fi
  printf 'calendar-write[3]{state,missing_scope,measured,grant}:\n'
  printf '  "REFUSED","%s","%s","%s"\n' "$SCOPE_EVENTS" \
    "$(printf '%s' "$scopes" | tr '\n' ' ' | sed 's/  */ /g')" "SNOTRA_GOOGLE_REFRESH_TOKEN"
  printf 'nothing was created and nothing was moved. The grant carries no write scope for the calendar, so\n' >&2
  printf 'this door will not pretend a local file is his calendar.\n' >&2
  printf 'to re-mint the grant WITH it:  bin/mail/connect.sh google   (one sign-in, calendar.events included)\n' >&2
  exit "$EXIT_REFUSED"
}

add_minutes() {  # <iso> <minutes> → ISO end
  local start="$1" minutes="$2" epoch
  epoch="$(date -d "$start" +%s 2>/dev/null)" || return 1
  [ -n "$epoch" ] || return 1
  date -d "@$((epoch + minutes * 60))" -Iseconds
}

verb_scopes() {
  resolve_creds
  local token; token="$(access_token)" || die "could not refresh the access token"
  [ -n "$token" ] || die "could not refresh the access token (the grant is dead — bin/mail/connect.sh google --check)"
  local scopes; scopes="$(grant_scopes "$token")"
  printf 'calendar-write[2]{scope,carried}:\n'
  printf '  "%s","%s"\n' "$SCOPE_EVENTS" "$(printf '%s\n' "$scopes" | grep -qx "$SCOPE_EVENTS" && echo yes || echo no)"
  printf '  "%s","%s"\n' "$SCOPE_FULL" "$(printf '%s\n' "$scopes" | grep -qx "$SCOPE_FULL" && echo yes || echo no)"
  printf 'measured from the token itself (%s)\n' "$TOKENINFO_URL"
}

verb_create() {
  local title="" when="" minutes=30 attendees="" meet=0 dry=0
  while [ $# -gt 0 ]; do case "$1" in
    --title) title="${2-}"; shift 2 ;;
    --when|--start) when="${2-}"; shift 2 ;;
    --minutes) minutes="${2-30}"; shift 2 ;;
    --attendees) attendees="${2-}"; shift 2 ;;
    --meet) meet=1; shift ;;
    --dry-run) dry=1; shift ;;
    *) usage_die "unknown option: $1" ;;
  esac; done
  [ -n "$title" ] && [ -n "$when" ] || usage_die "create needs --title and --when <ISO date-time>"
  local end; end="$(add_minutes "$when" "$minutes")" || usage_die "--when must be an ISO date-time (2026-11-10T14:00:00)"
  resolve_creds
  local token; token="$(access_token)" || die "could not refresh the access token"
  [ -n "$token" ] || die "could not refresh the access token (bin/mail/connect.sh google --check)"
  require_write_scope "$token"
  [ -x "$INVITE_DOOR" ] || die "the write door is absent: $INVITE_DOOR"
  # ONE write door: the invite door owns the approval gate and the mail law.
  local argv=(create --title "$title" --start "$when" --end "$end")
  [ -n "$attendees" ] && argv+=(--attendees "$attendees")
  [ "$meet" = 1 ] && argv+=(--meet)
  [ "$dry" = 1 ] && argv+=(--dry-run)
  printf 'calendar-write[2]{verb,through,when,end}:\n  "create","calendar-invite.sh","%s","%s"\n' "$when" "$end"
  local rc=0
  YMIR_CALENDAR_API_BASE="$CAL_API" YMIR_OAUTH_TOKEN_URL="$OAUTH_URL" \
    bash "$INVITE_DOOR" "${argv[@]}" || rc=$?
  [ "$rc" -eq 0 ] || exit "$rc"
}

verb_move() {
  local id="" to="" minutes=30 notify=0 dry=0
  while [ $# -gt 0 ]; do case "$1" in
    --to) to="${2-}"; shift 2 ;;
    --minutes) minutes="${2-30}"; shift 2 ;;
    --notify) notify=1; shift ;;
    --dry-run) dry=1; shift ;;
    -*) usage_die "unknown option: $1" ;;
    *) [ -n "$id" ] && usage_die "one event at a time"; id="$1"; shift ;;
  esac; done
  [ -n "$id" ] && [ -n "$to" ] || usage_die "move needs <event-id> and --to <ISO date-time>"
  local end; end="$(add_minutes "$to" "$minutes")" || usage_die "--to must be an ISO date-time"
  resolve_creds
  local token; token="$(access_token)" || die "could not refresh the access token"
  [ -n "$token" ] || die "could not refresh the access token (bin/mail/connect.sh google --check)"
  require_write_scope "$token"

  api() { local method="$1" path="$2" body="${3-}"
    local a=(-sS -m 30 -X "$method" -H "Authorization: Bearer $token" -H 'Content-Type: application/json' -w '\n%{http_code}')
    [ -n "$body" ] && a+=(-d "$body")
    curl "${a[@]}" "$CAL_API$path"; }

  # the old time is reported so he can check the move, not taken on trust
  local before code body old_start
  before="$(api GET "/calendars/primary/events/$id")"; code="${before##*$'\n'}"; body="${before%$'\n'*}"
  case "$code" in
    200) ;;
    404) printf 'calendar-write: no event %s on the primary calendar\n' "$id" >&2; exit 1 ;;
    *) die "could not read event $id (HTTP $code)" ;;
  esac
  old_start="$(printf '%s' "$body" | python3 -c 'import json,sys
d=json.load(sys.stdin); print(((d.get("start") or {}).get("dateTime")) or ((d.get("start") or {}).get("date")) or "")')"

  local send_updates="none" key="evt-${id}-move" payload_file="" why=""
  if [ "$notify" = 1 ]; then
    payload_file="$(mktemp)"
    printf '{"event":"%s","move_to":"%s","notify":true}' "$id" "$to" > "$payload_file"
    why="$(bash "$APPROVE" gate event "$key" --bytes "$payload_file" 2>&1)" || {
      bash "$APPROVE" hold "$key" "$payload_file" >/dev/null 2>&1 || true
      printf 'calendar-write: REFUSED — the event was not moved and no attendee was mailed.\n' >&2
      printf '  the word was not good enough: %s\n' "$why" >&2
      printf '  to release it: %s approve-event %s  &&  move %s --to %s --notify\n' "$APPROVE" "$key" "$id" "$to" >&2
      rm -f "$payload_file"; exit "$EXIT_REFUSED"; }
    send_updates="all"
  fi

  if [ "$dry" = 1 ]; then
    printf 'calendar-write[3]{verb,event,from,to}:\n  "move","%s","%s","%s"\n' "$id" "$old_start" "$to"
    printf 'dry run — nothing was patched; mail:%s\n' "$send_updates"
    [ -n "$payload_file" ] && rm -f "$payload_file"
    return 0
  fi

  local payload out new_code new_body
  payload="$(python3 -c 'import json,sys
print(json.dumps({"start":{"dateTime":sys.argv[1],"timeZone":sys.argv[3]},"end":{"dateTime":sys.argv[2],"timeZone":sys.argv[3]}}))' "$to" "$end" "$TZ_NAME")"
  out="$(api PATCH "/calendars/primary/events/$id?sendUpdates=$send_updates" "$payload")"
  new_code="${out##*$'\n'}"; new_body="${out%$'\n'*}"
  [ -n "$payload_file" ] && rm -f "$payload_file"
  case "$new_code" in
    200) ;;
    *) die "move failed (HTTP $new_code): $(printf '%s' "$new_body" | head -c 300)" ;;
  esac
  [ "$send_updates" = "all" ] && bash "$APPROVE" consume event "$key" >/dev/null 2>&1 || true
  printf 'calendar-write[4]{verb,event,from,to,mail}:\n  "move","%s","%s","%s","%s"\n' "$id" "$old_start" "$to" "$send_updates"
}

# ── the self-test: both branches, a fixture Google, no network ────────────────
self_test() {
  local tmp port pid rc=0
  tmp="$(mktemp -d)"
  port="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
  cat > "$tmp/fixture.py" <<'PY'
import json, sys, urllib.parse
from http.server import BaseHTTPRequestHandler, HTTPServer

SCOPED = sys.argv[2] == "scoped"
STATE = {"patched": []}

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _send(self, code, obj):
        b = json.dumps(obj).encode()
        self.send_response(code); self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        if u.path == "/tokeninfo":
            scope = "openid https://www.googleapis.com/auth/gmail.readonly"
            if SCOPED: scope += " https://www.googleapis.com/auth/calendar.events"
            return self._send(200, {"scope": scope})
        if u.path.startswith("/calendar/v3/calendars/primary/events/"):
            return self._send(200, {"id": u.path.rsplit("/", 1)[-1],
                                    "start": {"dateTime": "2026-11-10T09:00:00+01:00"}})
        self._send(404, {"error": "unknown"})
    def do_POST(self):
        self.rfile.read(int(self.headers.get("content-length") or 0))
        if self.path == "/token": return self._send(200, {"access_token": "fixture-token"})
        if self.path.endswith("/events"): return self._send(200, {"id": "fixture-event"})
        self._send(404, {"error": "unknown"})
    def do_PATCH(self):
        body = self.rfile.read(int(self.headers.get("content-length") or 0))
        STATE["patched"].append(json.loads(body))
        self._send(200, {"id": "fixture-event", "start": json.loads(body)["start"]})

HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
PY
  run_fixture() {  # <scoped|unscoped>
    python3 "$tmp/fixture.py" "$port" "$1" >"$tmp/fixture.log" 2>&1 &
    FIXPID=$!
    local i=0
    while [ "$i" -lt 40 ]; do
      curl -sS -m 1 -o /dev/null "http://127.0.0.1:$port/tokeninfo" 2>/dev/null && break
      i=$((i+1)); sleep 0.1
    done
  }
  stop_fixture() { kill "${FIXPID:-0}" 2>/dev/null; wait "${FIXPID:-0}" 2>/dev/null; }

  export YMIR_OAUTH_TOKEN_URL="http://127.0.0.1:$port/token"
  export YMIR_OAUTH_TOKENINFO_URL="http://127.0.0.1:$port/tokeninfo"
  export YMIR_CALENDAR_API_BASE="http://127.0.0.1:$port/calendar/v3"
  export YMIR_CALENDAR_CLIENT_ID="fixture-client"
  export YMIR_CALENDAR_CLIENT_SECRET="fixture-secret"
  export YMIR_CALENDAR_REFRESH_TOKEN="fixture-refresh"

  # a stand-in for the one write door, so the delegation is proved without the vault
  cat > "$tmp/invite-door" <<'SH'
#!/usr/bin/env bash
printf 'invite-door argv: %s\n' "$*" >> "${INVITE_LOG}"
SH
  chmod +x "$tmp/invite-door"
  export YMIR_CALENDAR_INVITE_DOOR="$tmp/invite-door"
  export INVITE_LOG="$tmp/invite.log"

  # ── without the scope: refuse, naming calendar.events, writing nothing ──
  run_fixture unscoped
  local out code
  out="$(bash "$0" create --title "test meeting" --when 2026-11-10T14:00:00 2>&1)"; code=$?
  [ "$code" -eq "$EXIT_REFUSED" ] && printf '  ok   without the scope, create REFUSES (exit %s)\n' "$EXIT_REFUSED" \
    || { printf '  not ok without the scope create refuses (exit %s)\n' "$code"; rc=1; }
  case "$out" in *calendar.events*) printf '  ok   the refusal names calendar.events and the way to re-mint it\n' ;;
    *) printf '  not ok the refusal names calendar.events: %s\n' "$out"; rc=1 ;; esac
  [ -s "$INVITE_LOG" ] && { printf '  not ok nothing was handed to the write door\n'; rc=1; } \
    || printf '  ok   nothing was handed to the write door\n'
  out="$(bash "$0" move fixture-event --to 2026-11-11T10:00:00 2>&1)"; code=$?
  [ "$code" -eq "$EXIT_REFUSED" ] && printf '  ok   without the scope, move REFUSES too\n' \
    || { printf '  not ok without the scope move refuses (exit %s)\n' "$code"; rc=1; }
  stop_fixture

  # ── with the scope: create delegates to the one write door, move patches ──
  run_fixture scoped
  out="$(bash "$0" create --title "test meeting" --when 2026-11-10T14:00:00 --attendees a@x 2>&1)"; code=$?
  [ "$code" -eq 0 ] && printf '  ok   with the scope, create runs\n' || { printf '  not ok create runs: %s\n' "$out"; rc=1; }
  case "$(cat "$INVITE_LOG" 2>/dev/null)" in
    *"--title test meeting"*) printf '  ok   create is handed to the one write door with its title and times\n' ;;
    *) printf '  not ok create reaches the write door: %s\n' "$(cat "$INVITE_LOG" 2>/dev/null)"; rc=1 ;;
  esac
  out="$(bash "$0" move fixture-event --to 2026-11-11T10:00:00 2>&1)"; code=$?
  [ "$code" -eq 0 ] && printf '  ok   with the scope, a move runs\n' || { printf '  not ok move runs: %s\n' "$out"; rc=1; }
  case "$out" in
    *"2026-11-10T09:00:00+01:00"*) printf '  ok   the move reports the OLD time so he can check it\n' ;;
    *) printf '  not ok the move reports the old time: %s\n' "$out"; rc=1 ;;
  esac
  case "$out" in *'"none"'*) printf '  ok   a move mails nobody unless his word is standing\n' ;;
    *) printf '  not ok a move mails nobody by default: %s\n' "$out"; rc=1 ;; esac
  stop_fixture

  unset YMIR_OAUTH_TOKEN_URL YMIR_OAUTH_TOKENINFO_URL YMIR_CALENDAR_API_BASE \
        YMIR_CALENDAR_CLIENT_ID YMIR_CALENDAR_CLIENT_SECRET YMIR_CALENDAR_REFRESH_TOKEN \
        YMIR_CALENDAR_INVITE_DOOR
  rm -rf "$tmp"
  [ "$rc" -eq 0 ] && printf 'calendar-write self-test: all passed\n' || printf 'calendar-write self-test: FAILED\n'
  return "$rc"
}

case "${1:-}" in
  ""|-h|--help) usage ;;
  -v|--version) printf '%s\n' "$VERSION" ;;
  --self-test|self-test) self_test ;;
  scopes) shift; verb_scopes ;;
  create) shift; verb_create "$@" ;;
  move) shift; verb_move "$@" ;;
  *) usage_die "unknown verb $1" ;;
esac
