#!/usr/bin/env bash
# draft-age.sh — a draft cannot grow old quietly.
#
# The house writes letters it does not send: a follow-up saved as a draft, a reply
# half-worded at midnight, a note to a partner that never left. A draft is the one piece
# of correspondence that fails in silence — nobody is waiting for it, so nothing reminds
# anyone, and a two-day-old draft is already a late promise. This door reads the drafts
# Gmail still holds, gives every one of them its age in days, and REFUSES to be quiet
# when one has aged past the limit.
#
# Usage:
#   draft-age.sh                 # every draft, oldest first, with its age in days
#   draft-age.sh --days 5        # another limit (default 2, or YMIR_DRAFT_MAX_DAYS)
#   draft-age.sh --brief         # one line for the 07:00 daily briefing
#   draft-age.sh --json          # the same answer, as JSON
#   draft-age.sh --limit 50      # how many drafts to inspect (default 200)
#   draft-age.sh -h | -v
#
# Exit: 0 nothing has aged — an empty outbox and a NAMED skip are both 0 · 1 a draft is
# older than the limit, and every aged one is named · 2 usage · 3 the mailbox could not
# be read (the reason is named; it is never reported as zero drafts).
#
# Configuration, never constants (Rule 07):
#   YMIR_GMAIL_API_BASE     default https://gmail.googleapis.com/gmail/v1
#   YMIR_OAUTH_TOKEN_URL    default https://oauth2.googleapis.com/token
#   YMIR_DRAFT_MAX_DAYS     the limit when --days is not given (default 2)
# The Google grant is the letters door's own (GOOGLE_MCP_CLIENT_ID ·
# GOOGLE_MCP_CLIENT_SECRET · SNOTRA_GOOGLE_REFRESH_TOKEN), read from the vault; an
# environment value of the same name wins, so a test can stand a stub in front of it.
#
# READ-ONLY. This door issues GETs and the one token POST. It cannot send, and it cannot
# discard: naming a draft is the whole act, and the choice of write-or-drop is the
# operator's. bin/mail/tests/test_draft_age.py proves the stub saw no send.
#
# The age is the draft message's own instant (internalDate, else its Date header), so a
# draft that was edited yesterday is a day old — the age of the letter, not of the idea.
set -u
VERSION="1.0.0"

usage() { sed -n '2,36p' "$0" | sed 's/^# \{0,1\}//'; }
case "${1-}" in
  -h|--help) usage; exit 0 ;;
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$ROOT/bin/vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
HOME_DIR="${YMIR_HOME:-}"
[ -n "$HOME_DIR" ] || { ymir_home_root HOME_DIR 2>/dev/null || true; }
SEC="${HOME_DIR:+$HOME_DIR/hodd/secrets}"

DAYS="${YMIR_DRAFT_MAX_DAYS:-2}"
LIMIT=200
MODE="table"
while [ $# -gt 0 ]; do case "$1" in
  --days) DAYS="${2-}"; shift 2 ;;
  --days=*) DAYS="${1#--days=}"; shift ;;
  --limit) LIMIT="${2-}"; shift 2 ;;
  --limit=*) LIMIT="${1#--limit=}"; shift ;;
  --brief) MODE="brief"; shift ;;
  --json) MODE="json"; shift ;;
  --table) MODE="table"; shift ;;
  *) printf 'draft-age: unknown argument %s\n' "$1" >&2; exit 2 ;;
esac; done
case "$DAYS" in ''|*[!0-9]*) printf 'draft-age: --days "%s" is not a number of days\n' "$DAYS" >&2; exit 2 ;; esac
case "$LIMIT" in ''|*[!0-9]*) printf 'draft-age: --limit "%s" is not a number\n' "$LIMIT" >&2; exit 2 ;; esac

GMAIL_API="${YMIR_GMAIL_API_BASE:-https://gmail.googleapis.com/gmail/v1}"
GMAIL_API="${GMAIL_API%/}"
OAUTH_URL="${YMIR_OAUTH_TOKEN_URL:-https://oauth2.googleapis.com/token}"

# ── the grant ────────────────────────────────────────────────────────────────────────
# The vault door decides how to decrypt; a plaintext record on this machine is the same
# record, so it is the fallback and never the winner. An environment value wins over both,
# which is the seam a test uses — it stands a stub endpoint in front of the same door.
VAULT_TEXT=""
if [ -n "${SEC:-}" ]; then
  VAULT_TEXT="$(bash "$ROOT/bin/vault/hodd.sh" emit secrets/platform.env 2>/dev/null || true)"
  [ -n "$VAULT_TEXT" ] || VAULT_TEXT="$(cat "$SEC/platform.env" 2>/dev/null || true)"
fi
cred() {  # <KEY> — env, then the vault (both `KEY=` and `export KEY=` forms)
  local k=$1 v="${!1:-}"
  [ -n "$v" ] && { printf '%s' "$v"; return 0; }
  [ -n "$VAULT_TEXT" ] || return 0
  printf '%s\n' "$VAULT_TEXT" | sed -n "s/^export ${k}=//p; s/^${k}=//p" | head -1 | sed "s/^['\"]//; s/['\"]\$//"
}

skip() {  # <why> — a skip is NAMED, never a zero that reads as a clean outbox
  case "$MODE" in
    brief) printf 'drafts: SKIP — %s, so no draft was read\n' "$1" ;;
    json) printf '{"state":"skipped","reason":"no-grant","detail":%s}\n' "$(printf '%s' "$1" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read().strip()))')" ;;
    *) printf 'draft-age{state,limit_days,drafts,aged}:\n  "skipped",%s,"-","-"\n' "$DAYS"
       printf 'SKIP no-grant: %s, so no draft was read\n' "$1" ;;
  esac
  exit 0
}

CID="$(cred GOOGLE_MCP_CLIENT_ID)"
CSEC="$(cred GOOGLE_MCP_CLIENT_SECRET)"
RT="$(cred SNOTRA_GOOGLE_REFRESH_TOKEN)"
[ -n "$CID" ] && [ -n "$CSEC" ] || skip "the vault carries no Google client on this seat"
[ -n "$RT" ] || skip "the vault carries no Google refresh token on this seat"

TOKEN="$(curl -sS -m 20 -X POST "$OAUTH_URL" \
  --data-urlencode "client_id=$CID" --data-urlencode "client_secret=$CSEC" \
  --data-urlencode "refresh_token=$RT" --data-urlencode "grant_type=refresh_token" 2>/dev/null \
  | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("access_token",""))
except Exception: print("")' 2>/dev/null)"
[ -n "$TOKEN" ] || { printf 'draft-age: UNABLE — the refresh token did not mint an access token (the grant was refused by %s)\n' "$OAUTH_URL" >&2; exit 3; }

# ── the drafts, and how long they have waited ────────────────────────────────────────
DRAFT_API="$GMAIL_API" DRAFT_TOKEN="$TOKEN" DRAFT_DAYS="$DAYS" DRAFT_LIMIT="$LIMIT" DRAFT_MODE="$MODE" \
python3 - <<'PY'
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from email.utils import parsedate_to_datetime

API = os.environ["DRAFT_API"].rstrip("/")
TOKEN = os.environ["DRAFT_TOKEN"]
DAYS = int(os.environ["DRAFT_DAYS"])
LIMIT = int(os.environ["DRAFT_LIMIT"])
MODE = os.environ["DRAFT_MODE"]
NOW = time.time()
SECONDS_PER_DAY = 86400.0


def describe(exc):
    if isinstance(exc, urllib.error.HTTPError):
        body = ""
        try:
            body = exc.read().decode("utf-8", "replace")[:200]
        except Exception:
            pass
        return "HTTP %s%s" % (exc.code, (": " + body) if body else "")
    return str(exc)


def get(path):
    req = urllib.request.Request(API + path, headers={"Authorization": "Bearer " + TOKEN})
    with urllib.request.urlopen(req, timeout=45) as handle:
        return json.loads(handle.read().decode("utf-8") or "{}")


def fmt(age):
    """A number of days a person reads: 5, 2.5, 0.4."""
    return ("%g" % age) if age is not None else "?"


def emit_table(state, rows, aged, unreadable, limit_days, extra=""):
    print("draft-age{state,limit_days,drafts,aged}:")
    print('  "%s",%d,%d,%d' % (state, limit_days, len(rows), len(aged)))
    print("drafts[%d]{id,age_days,subject}:" % len(rows))
    for r in rows:
        print('  "%s",%s,"%s"' % (r["id"], fmt(r["age_days"]), r["subject"].replace('"', "'")))
    print("aged[%d]{id,age_days,subject}:" % len(aged))
    for r in aged:
        print('  "%s",%s,"%s"' % (r["id"], fmt(r["age_days"]), r["subject"].replace('"', "'")))
    if unreadable:
        print("unreadable[%d]{id,why}:" % len(unreadable))
        for did, why in unreadable:
            print('  "%s","%s"' % (did, why.replace('"', "'")))
    if extra:
        print(extra)


def emit_brief(state, rows, aged, unreadable, limit_days, why=""):
    tail = " (%d could not be read)" % len(unreadable) if unreadable else ""
    if state == "unable":
        print("drafts: UNABLE — %s%s" % (why, tail))
    elif state == "empty":
        print("drafts: none — nothing is written and left unwritten")
    elif state == "aged":
        names = " · ".join('"%s" (%s days)' % (r["subject"], fmt(r["age_days"])) for r in aged)
        print("drafts: %d of %d older than %d days — %s%s" % (len(aged), len(rows), limit_days, names, tail))
    else:
        oldest = rows[0] if rows else None
        where = (' (oldest "%s", %s days)' % (oldest["subject"], fmt(oldest["age_days"]))) if oldest else ""
        print("drafts: %d unwritten, none older than %d days%s%s" % (len(rows), limit_days, where, tail))


drafts = []
page = None
failure = ""
while True:
    query = {"maxResults": "100"}
    if page:
        query["pageToken"] = page
    try:
        doc = get("/users/me/drafts?" + urllib.parse.urlencode(query))
    except Exception as exc:  # noqa: BLE001 — every failure is named, none is swallowed
        failure = describe(exc)
        break
    for draft in doc.get("drafts") or []:
        drafts.append(draft)
        if len(drafts) >= LIMIT:
            break
    page = doc.get("nextPageToken")
    if not page or len(drafts) >= LIMIT:
        break

if failure and not drafts:
    if MODE == "json":
        print(json.dumps({"state": "unable", "reason": failure, "drafts": [], "aged": []}))
    elif MODE == "brief":
        emit_brief("unable", [], [], [], DAYS, failure)
    else:
        print("draft-age{state,limit_days,drafts,aged}:")
        print('  "unable",%d,"-","-"' % DAYS)
        print("UNABLE: the drafts list could not be read — %s" % failure)
    sys.exit(3)

rows = []
unreadable = []
for draft in drafts:
    did = draft.get("id", "")
    mid = (draft.get("message") or {}).get("id") or did
    try:
        msg = get("/users/me/messages/" + urllib.parse.quote(mid) +
                  "?format=metadata&metadataHeaders=Subject&metadataHeaders=To")
    except Exception as exc:  # noqa: BLE001 — a draft that cannot be read is named, not dropped
        unreadable.append((did or mid, describe(exc)))
        continue
    headers = {h.get("name", "").lower(): h.get("value", "")
               for h in ((msg.get("payload") or {}).get("headers") or [])}
    subject = (headers.get("subject") or "").strip() or "(no subject)"
    when = None
    raw = msg.get("internalDate")
    if raw:
        try:
            when = int(raw) / 1000.0
        except (TypeError, ValueError):
            when = None
    if when is None and headers.get("date"):
        try:
            when = parsedate_to_datetime(headers["date"]).timestamp()
        except Exception:  # noqa: BLE001 — an unparseable Date is an unknown age, not an age of zero
            when = None
    age_days = None if when is None else round(max(NOW - when, 0.0) / SECONDS_PER_DAY, 1)
    rows.append({"id": did, "subject": subject, "age_days": age_days,
                 "to": (headers.get("to") or "").strip(), "when": when})

if not rows and unreadable:
    why = "no draft could be read (%s)" % "; ".join("%s %s" % (d, w) for d, w in unreadable)
    if MODE == "json":
        print(json.dumps({"state": "unable", "reason": why, "drafts": [], "aged": [], "unreadable": unreadable}))
    elif MODE == "brief":
        emit_brief("unable", [], [], [], DAYS, why)
    else:
        print("draft-age{state,limit_days,drafts,aged}:")
        print('  "unable",%d,"-","-"' % DAYS)
        print("UNABLE: %s" % why)
    sys.exit(3)

rows.sort(key=lambda r: (-1 if r["age_days"] is None else r["age_days"]), reverse=True)
# "older than the limit" is measured on the exact instant, so a draft of 2 days and 3 hours
# is aged under a 2-day limit even though its printed age rounds to 2.2 days as people read it.
aged = []
for row in rows:
    if row["when"] is None:
        continue
    elapsed = NOW - row["when"]
    if elapsed > DAYS * SECONDS_PER_DAY:
        aged.append(row)

if aged:
    state, code = "aged", 1
elif not rows:
    state, code = "empty", 0
else:
    state, code = "clean", 0

if MODE == "json":
    print(json.dumps({
        "state": state,
        "limit_days": DAYS,
        "inspected": len(drafts),
        "drafts": [{"id": r["id"], "age_days": r["age_days"], "subject": r["subject"], "to": r["to"]} for r in rows],
        "aged": [{"id": r["id"], "age_days": r["age_days"], "subject": r["subject"]} for r in aged],
        "unreadable": [{"id": d, "why": w} for d, w in unreadable],
    }))
elif MODE == "brief":
    emit_brief(state, rows, aged, unreadable, DAYS)
else:
    emit_table(state, rows, aged, unreadable, DAYS)
    if aged:
        print("AGED: %d draft%s older than %d days — write it or discard it; a draft cannot grow old quietly"
              % (len(aged), "" if len(aged) == 1 else "s", DAYS))
sys.exit(code)
PY
RC=$?
# The exit code is the alarm: 0 nothing has aged (an empty outbox and a named skip are
# both 0), 1 an aged draft (the table and the brief have both named it), 3 unreadable.
exit "$RC"
