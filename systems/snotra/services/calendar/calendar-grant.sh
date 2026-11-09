#!/usr/bin/env bash
# calendar-grant.sh — ONE reading of the calendar grant: the vault key, the token, the scopes, the API.
#
# Sourced by the calendar doors that WRITE (`calendar-invite.sh`, `calendar-write.sh`) so there is
# one resolver, one refresh, one scope measurement and one curl shape in the house (Rule 07: a
# configuration is resolved, never restated).
#
# THE GRANT IS THE CONNECT DOOR'S. `bin/mail/connect.sh google` writes the refresh token into the
# vault by key and measures what it may do via the tokeninfo door; this library reads the SAME key
# (`SNOTRA_GOOGLE_REFRESH_TOKEN`, which is `gna_connect.DEFAULT_GATE_GRANT_KEY`) through the SAME
# vault door (`bin/vault/hodd.sh emit`). A second grant would be a second truth.
#
# THE SCOPE IS NAMED, NEVER ASSUMED. Google's write scope is `calendar.events`. A grant that
# carries only `calendar.events.readonly` can read the day and cannot make or move a meeting, and
# the door must say THAT, in those words, instead of failing with a bare 403 later (plan 231 §2).
#
# Env (Rule 07 — one documented default each):
#   YMIR_CALENDAR_API_BASE     https://www.googleapis.com/calendar/v3
#   YMIR_OAUTH_TOKEN_URL       https://oauth2.googleapis.com/token
#   YMIR_OAUTH_TOKENINFO_URL   https://oauth2.googleapis.com/tokeninfo   (the connect door's own)
#   YMIR_GATE_GRANT_KEY        SNOTRA_GOOGLE_REFRESH_TOKEN
#   YMIR_GOOGLE_CLIENT_KEY     GOOGLE_MCP_CLIENT_ID
#   YMIR_GOOGLE_SECRET_KEY     GOOGLE_MCP_CLIENT_SECRET
#   YMIR_CALENDAR_ID           primary
#
# Nothing here prints a secret: a value is read into a variable and never echoed.
# shellcheck shell=bash

# the repo root — the same walk every door in this folder does
_cal_root() {
  local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ "$d" != "/" ]; do
    [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  ( cd "$d/../../../../" && pwd )
}
CAL_ROOT="$(_cal_root)"
# shellcheck source=../../../vault/hoard-lib.sh
[ -n "${YMIR_HOARD_LIB_LOADED:-}" ] || . "$CAL_ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
if [ -z "${YMIR_HOME:-}" ] && command -v ymir_home_root >/dev/null 2>&1; then
  ymir_home_root YMIR_HOME 2>/dev/null || true
fi

CAL_API_BASE="${YMIR_CALENDAR_API_BASE:-https://www.googleapis.com/calendar/v3}"
CAL_TOKEN_URL="${YMIR_OAUTH_TOKEN_URL:-https://oauth2.googleapis.com/token}"
CAL_TOKENINFO_URL="${YMIR_OAUTH_TOKENINFO_URL:-https://oauth2.googleapis.com/tokeninfo}"
CAL_GRANT_KEY="${YMIR_GATE_GRANT_KEY:-SNOTRA_GOOGLE_REFRESH_TOKEN}"
CAL_CLIENT_KEY="${YMIR_GOOGLE_CLIENT_KEY:-GOOGLE_MCP_CLIENT_ID}"
CAL_SECRET_KEY="${YMIR_GOOGLE_SECRET_KEY:-GOOGLE_MCP_CLIENT_SECRET}"
CAL_CALENDAR_ID="${YMIR_CALENDAR_ID:-primary}"
CAL_WRITE_SCOPE="https://www.googleapis.com/auth/calendar.events"

# ── the vault, BY REFERENCE ─────────────────────────────────────────────────────────────────
# One read, cached in a variable for the life of the process. The text is never printed; only
# the value a caller asked for leaves this function, into that caller's variable.
# CALENDAR_SECRETS_FILE points at a KEY=value file instead of the vault, and exists only so the
# proofs can resolve keys without one. Nothing else sets it, and no value is ever written here.
calendar_vault_load() {
  [ -n "${CAL_VAULT_LOADED:-}" ] && return 0
  local override="${CALENDAR_SECRETS_FILE:-}"
  if [ -n "$override" ]; then
    [ -r "$override" ] || { CAL_VAULT_WHY="CALENDAR_SECRETS_FILE is set but unreadable ($override)"; return 1; }
    CAL_VAULT_TEXT="$(cat "$override")"; CAL_VAULT_LOADED=1; return 0
  fi
  command -v bash >/dev/null 2>&1 || { CAL_VAULT_WHY="bash is not on PATH"; return 1; }
  local door="$CAL_ROOT/bin/vault/hodd.sh"
  [ -r "$door" ] || { CAL_VAULT_WHY="the vault door is missing ($door)"; return 1; }
  CAL_VAULT_TEXT="$(bash "$door" emit secrets/platform.env 2>/dev/null)" || {
    CAL_VAULT_WHY="the vault did not open (bin/vault/hodd.sh emit secrets/platform.env)"; return 1; }
  CAL_VAULT_LOADED=1
  return 0
}

# calendar_vault_value <KEY-NAME> -> the value on stdout, or non-zero with CAL_VAULT_WHY set.
calendar_vault_value() {
  local name="$1"
  calendar_vault_load || return 1
  printf '%s' "${CAL_VAULT_TEXT:-}" | CAL_KEY_NAME="$name" python3 /dev/fd/3 3<<'PY'
import os, re, sys
name = os.environ["CAL_KEY_NAME"]
for line in sys.stdin.read().splitlines():
    m = re.match(r"^(?:export\s+)?([A-Za-z0-9_]+)=(.*)$", line.strip())
    if not m or m.group(1) != name:
        continue
    v = m.group(2)
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "'\"":
        v = v[1:-1]
    print(v)
    break
PY
}

# ── the token ───────────────────────────────────────────────────────────────────────────────
# calendar_refresh_grant -> 0 and CAL_TOKEN set; non-zero with CAL_TOKEN_WHY (never a value).
calendar_refresh_grant() {
  CAL_TOKEN=""; CAL_TOKEN_WHY=""
  local cid csec rt body
  # Ask the vault in THIS shell first. A read that fails inside a command substitution sets its
  # reason in that subshell, where the parent can never see it — measured 2026-11-09 while
  # reconciling Rödd's hands: `calendar-grant.sh: line 99: CAL_VAULT_WHY: unbound variable`, under
  # `set -u`, at the exact moment the door needed to say why it could not read the grant.
  calendar_vault_load || { CAL_TOKEN_WHY="${CAL_VAULT_WHY:-the vault did not open}"; return 1; }
  cid="$(calendar_vault_value "$CAL_CLIENT_KEY")" || { CAL_TOKEN_WHY="${CAL_VAULT_WHY:-the vault holds no $CAL_CLIENT_KEY}"; return 1; }
  csec="$(calendar_vault_value "$CAL_SECRET_KEY")" || { CAL_TOKEN_WHY="${CAL_VAULT_WHY:-the vault holds no $CAL_SECRET_KEY}"; return 1; }
  rt="$(calendar_vault_value "$CAL_GRANT_KEY")" || { CAL_TOKEN_WHY="${CAL_VAULT_WHY:-the vault holds no $CAL_GRANT_KEY}"; return 1; }
  [ -n "$cid" ] && [ -n "$csec" ] && [ -n "$rt" ] || {
    CAL_TOKEN_WHY="the vault holds no $CAL_CLIENT_KEY / $CAL_SECRET_KEY / $CAL_GRANT_KEY"
    return 1; }
  # the refresh token rides a file, never argv: `ps` must not be able to read a grant
  local form; form="$(mktemp)"
  python3 - "$form" "$cid" "$csec" "$rt" <<'PY'
import sys, urllib.parse
path, cid, csec, rt = sys.argv[1:5]
open(path, "w").write(urllib.parse.urlencode(
    {"client_id": cid, "client_secret": csec, "refresh_token": rt, "grant_type": "refresh_token"}))
PY
  body="$(curl -sS -m 20 -X POST -H 'content-type: application/x-www-form-urlencoded' \
            --data-binary "@$form" "$CAL_TOKEN_URL" 2>/dev/null)"
  rm -f "$form"
  CAL_TOKEN="$(printf '%s' "$body" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("access_token",""))
except Exception: print("")' 2>/dev/null)"
  if [ -z "$CAL_TOKEN" ]; then
    CAL_TOKEN_WHY="the token endpoint refused: $(printf '%s' "$body" | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin); print(d.get("error",""), d.get("error_description",""))
except Exception: print("no readable answer")' 2>/dev/null | tr -s ' ' | sed 's/^ //; s/ $//')"
    return 1
  fi
  return 0
}

# ── the scopes, measured the way the connect door measures them ─────────────────────────────
# calendar_measure_scopes -> 0. Sets CAL_SCOPES (space separated) and CAL_SCOPES_MEASURED=1,
# or leaves CAL_SCOPES empty and CAL_SCOPES_MEASURED=0 with CAL_SCOPES_WHY.
calendar_measure_scopes() {
  CAL_SCOPES=""; CAL_SCOPES_MEASURED=0; CAL_SCOPES_WHY=""
  [ -n "${CAL_TOKEN:-}" ] || { CAL_SCOPES_WHY="no access token to measure"; return 1; }
  local out
  out="$(curl -sS -m 15 "${CAL_TOKENINFO_URL}?access_token=${CAL_TOKEN}" 2>/dev/null)"
  [ -n "$out" ] || { CAL_SCOPES_WHY="the tokeninfo door did not answer"; return 1; }
  CAL_SCOPES="$(printf '%s' "$out" | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin); print(str(d.get("scope") or ""))
except Exception: print("")' 2>/dev/null)"
  [ -n "$CAL_SCOPES" ] || { CAL_SCOPES_WHY="the tokeninfo door named no scope"; return 1; }
  CAL_SCOPES_MEASURED=1
  return 0
}

# calendar_has_scope <scope-url> -> 0 when the measured grant carries it.
calendar_has_scope() {
  [ "$CAL_SCOPES_MEASURED" = 1 ] || return 1
  local want="$1"
  case " $CAL_SCOPES " in
    *" $want "*) return 0 ;;
    # the full calendar scope includes every events verb
    *" https://www.googleapis.com/auth/calendar "*) return 0 ;;
  esac
  return 1
}

# calendar_require_write -> 0 when the grant may write, 3 when it measurably may not.
# UNMEASURED IS NOT REFUSED: if the measurement door is down, the write is attempted and
# Google's own 403 names the scope (see calendar_write_refusal). Never a silent local write.
calendar_require_write() {
  if [ "${CAL_SCOPES_MEASURED:-0}" != 1 ]; then
    calendar_measure_scopes || true
  fi
  [ "$CAL_SCOPES_MEASURED" = 1 ] || return 0
  calendar_has_scope "$CAL_WRITE_SCOPE" && return 0
  calendar_scope_refusal
  return 3
}

# the refusal, said once and in the words the operator can act on
calendar_scope_refusal() {
  {
    printf 'calendar: REFUSED — the grant cannot write to the calendar. Nothing was created or moved.\n'
    printf '  the scope this needs is  calendar.events  (https://www.googleapis.com/auth/calendar.events)\n'
    printf '  the grant holds: %s\n' "${CAL_SCOPES:-unmeasured}"
    printf '  to add it, re-consent once:  bin/mail/connect.sh google\n'
    printf '  (or: CALENDAR_WRITE=1 systems/snotra/services/calendar/calendar-auth.sh --store)\n'
    printf '  nothing is written to a local calendar: a meeting that exists only in a file is a lie.\n'
  } >&2
}

# the same refusal when Google is the one who says no (unmeasured scope, or a grant revoked
# between the token and the write)
calendar_api_refusal() {  # <http-code> <body>
  local code="$1" body="$2"
  case "$code" in
    403)
      case "$body" in
        *insufficientPermissions*|*insufficient_scope*|*ACCESS_TOKEN_SCOPE_INSUFFICIENT*)
          calendar_scope_refusal
          printf '  google answered: %s\n' "$(printf '%s' "$body" | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin); e=d.get("error") or {}
    print((e.get("message") if isinstance(e,dict) else "") or str(e))
except Exception: print("HTTP 403")' 2>/dev/null)"
          return 3 ;;
      esac ;;
  esac
  return 1
}

# ── the API ─────────────────────────────────────────────────────────────────────────────────
# calendar_api <METHOD> <PATH> [BODY-JSON] -> sets CAL_CODE and CAL_BODY. The path is appended
# to the base, query string and all. The body rides a file, never argv.
calendar_api() {
  local method="$1" path="$2" body="${3-}" tmp="" out
  [ -n "${CAL_TOKEN:-}" ] || return 1
  if [ -n "$body" ]; then
    tmp="$(mktemp)"; printf '%s' "$body" >"$tmp"
    out="$(curl -sS -m 40 -X "$method" -H "Authorization: Bearer $CAL_TOKEN" \
             -H 'Content-Type: application/json' --data-binary "@$tmp" \
             -w '\n%{http_code}' "$CAL_API_BASE$path" 2>/dev/null)"
    rm -f "$tmp"
  else
    out="$(curl -sS -m 40 -X "$method" -H "Authorization: Bearer $CAL_TOKEN" \
             -w '\n%{http_code}' "$CAL_API_BASE$path" 2>/dev/null)"
  fi
  CAL_CODE="${out##*$'\n'}"
  CAL_BODY="${out%$'\n'*}"
  [ -n "$CAL_CODE" ] || { CAL_CODE="000"; CAL_BODY="the calendar API did not answer"; return 1; }
  return 0
}

# calendar_zone — the machine's IANA zone, resolved (Rule 07): YMIR_TZ, then $TZ, then the
# file the OS points at. Never a constant, and never an offset standing in for a name.
calendar_zone() {
  local z="${YMIR_TZ:-${TZ:-}}"
  if [ -z "$z" ] && [ -L /etc/localtime ]; then
    z="$(readlink -f /etc/localtime 2>/dev/null)"
    case "$z" in */zoneinfo/*) z="${z##*/zoneinfo/}" ;; *) z="" ;; esac
  fi
  if [ -z "$z" ] && command -v timedatectl >/dev/null 2>&1; then
    z="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
  fi
  printf '%s' "$z"
}

# ── a `when` a voice can say, resolved once ─────────────────────────────────────────────────
# calendar_when <spec> [<duration>] -> JSON on stdout: {"start","end","tz"} (RFC3339, Zoned).
#   <spec> may be an ISO instant with an offset, an ISO local instant, "YYYY-MM-DD HH:MM",
#   "today 14:00", "tomorrow 09:30", "monday 10:00", or just "14:00".
#   <duration> is 45m, 1h30m, 90 (minutes); default 60m. Exits 2 on a spec it cannot read.
calendar_when() {
  CAL_WHEN_SPEC="${1-}" CAL_WHEN_DURATION="${2:-60m}" CAL_WHEN_TZ="$(calendar_zone)" \
  python3 /dev/fd/3 3<<'PY'
import datetime as dt, json, os, re, sys

spec = (os.environ.get("CAL_WHEN_SPEC") or "").strip()
dur = (os.environ.get("CAL_WHEN_DURATION") or "60m").strip().lower()
zone = (os.environ.get("CAL_WHEN_TZ") or "").strip()
try:
    from zoneinfo import ZoneInfo
    tz = ZoneInfo(zone) if zone else dt.datetime.now().astimezone().tzinfo
except Exception:
    tz = dt.datetime.now().astimezone().tzinfo
    zone = ""

now = dt.datetime.now(tz)

def fail(msg):
    sys.stderr.write(f"calendar: cannot read the time {spec!r} — {msg}\n")
    sys.stderr.write('help: give an instant ("2026-11-12 14:00", "2026-11-12T14:00:00+01:00", '
                     '"tomorrow 09:30", "monday 10:00") and a --duration like 45m or 1h30m\n')
    raise SystemExit(2)

def duration():
    if not dur:
        return dt.timedelta(minutes=60)
    if re.fullmatch(r"\d+(\.\d+)?", dur):
        return dt.timedelta(minutes=float(dur))
    total = dt.timedelta(0)
    seen = False
    for num, unit in re.findall(r"(\d+(?:\.\d+)?)([hm])", dur):
        seen = True
        total += dt.timedelta(hours=float(num)) if unit == "h" else dt.timedelta(minutes=float(num))
    if not seen:
        fail("the duration must look like 45m, 1h30m or 90")
    return total

WEEKDAYS = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]

def parse(s):
    low = s.lower()
    # an ISO instant, offset or not, with a space or a T
    m = re.fullmatch(r"(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2}))?\s*(Z|[+-]\d{2}:?\d{2})?", s)
    if m:
        y, mo, d, h, mi, sec, off = m.groups()
        base = dt.datetime(int(y), int(mo), int(d), int(h), int(mi), int(sec or 0))
        if off:
            sign = 1 if off[0] == "+" else -1
            body = off[1:].replace(":", "")
            delta = dt.timedelta(hours=int(body[:2]), minutes=int(body[2:4] or 0))
            return base.replace(tzinfo=dt.timezone.utc) - sign * delta
        return base.replace(tzinfo=tz)
    # "today 14:00" / "tomorrow 09:30" / "monday 10:00"
    m = re.fullmatch(r"(today|tomorrow|" + "|".join(WEEKDAYS) + r")\s+(\d{1,2}):(\d{2})", low)
    if m:
        day, h, mi = m.group(1), int(m.group(2)), int(m.group(3))
        if day == "today":
            d0 = now.date()
        elif day == "tomorrow":
            d0 = now.date() + dt.timedelta(days=1)
        else:
            ahead = (WEEKDAYS.index(day) - now.weekday()) % 7 or 7
            d0 = now.date() + dt.timedelta(days=ahead)
        return dt.datetime(d0.year, d0.month, d0.day, h, mi, tzinfo=tz)
    # "14:00" — today, or tomorrow if it has already gone
    m = re.fullmatch(r"(\d{1,2}):(\d{2})", low)
    if m:
        h, mi = int(m.group(1)), int(m.group(2))
        cand = now.replace(hour=h, minute=mi, second=0, microsecond=0)
        return cand if cand > now else cand + dt.timedelta(days=1)
    # a bare date — 09:00 that morning
    m = re.fullmatch(r"(\d{4})-(\d{2})-(\d{2})", s)
    if m:
        y, mo, d = (int(g) for g in m.groups())
        return dt.datetime(y, mo, d, 9, 0, tzinfo=tz)
    fail('it is not a date or a time this door can read')

start = parse(spec)
end = start + duration()
if end <= start:
    fail("the end is not after the start")
# show the instant on HIS clock, and keep the zone name for Google
try:
    start, end = start.astimezone(tz), end.astimezone(tz)
except Exception:
    pass
print(json.dumps({"start": start.isoformat(timespec="seconds"),
                  "end": end.isoformat(timespec="seconds"),
                  "tz": zone or str(tz),
                  "now": dt.datetime.now(tz).isoformat(timespec="seconds")}))
PY
}
