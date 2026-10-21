#!/usr/bin/env bash
# inbox.sh — read the mail that matters to a collaborator, and prove you can answer it.
#
# The house can SEND mail (bin/time/snotra/mail-send.sh) and it could only READ replies
# through the meeting sign-off flow. This is the missing door: "has Andrej answered?"
# asked as a command instead of as an afternoon.
#
#   bin/people/inbox.sh [--from ADDRESS] [--to ADDRESS] [--days 7] [--limit 10] [--body]
#   bin/people/inbox.sh --unread [--from ADDRESS]
#
# It reads through the grant already in the vault (`SNOTRA_GOOGLE_REFRESH_TOKEN`), the same
# one the calendar write door uses. Read-only: it never sends, marks, or deletes anything.
#
# Exit: 0 ok (even when nothing matched) · 1 the grant could not be used · 2 usage.
set -u
VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

usage() { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; }

FROM=""; TO=""; DAYS=7; LIMIT=10; BODY=0; UNREAD=0
while [ $# -gt 0 ]; do
  case "$1" in
    --from) FROM="${2:-}"; shift 2 ;;
    --to) TO="${2:-}"; shift 2 ;;
    --days) DAYS="${2:-7}"; shift 2 ;;
    --limit) LIMIT="${2:-10}"; shift 2 ;;
    --body) BODY=1; shift ;;
    --unread) UNREAD=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --version|-v) printf '%s\n' "$VERSION"; exit 0 ;;
    *) printf 'error: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done

ROOT_DIR="$ROOT" FROM_Q="$FROM" TO_Q="$TO" DAYS_Q="$DAYS" LIMIT_Q="$LIMIT" BODY_Q="$BODY" UNREAD_Q="$UNREAD" \
python3 - <<'PY'
import base64, json, os, re, subprocess, sys, time, urllib.parse, urllib.request

ROOT = os.environ["ROOT_DIR"]

def vault():
    out = subprocess.run(["bash", os.path.join(ROOT, "bin", "vault", "hodd.sh"),
                          "emit", "secrets/platform.env"],
                         capture_output=True, text=True).stdout
    values = {}
    for line in out.splitlines():
        m = re.match(r"^export ([A-Za-z_][A-Za-z0-9_]*)=(.*)$", line)
        if m:
            values[m.group(1)] = m.group(2).strip("'\"")
    return values

v = vault()
rt = v.get("SNOTRA_GOOGLE_REFRESH_TOKEN") or v.get("GOOGLE_REFRESH_TOKEN", "")
cid = v.get("SNOTRA_GOOGLE_CLIENT_ID") or v.get("GOOGLE_MCP_CLIENT_ID", "")
csec = v.get("SNOTRA_GOOGLE_CLIENT_SECRET") or v.get("GOOGLE_MCP_CLIENT_SECRET", "")
if not (rt and cid and csec):
    print('inbox[1]{error}: "the gmail grant is incomplete in the vault (refresh token, client id/secret)"')
    sys.exit(1)

data = urllib.parse.urlencode({"client_id": cid, "client_secret": csec,
                               "refresh_token": rt, "grant_type": "refresh_token"}).encode()
try:
    with urllib.request.urlopen("https://oauth2.googleapis.com/token", data=data, timeout=20) as r:
        token = json.load(r).get("access_token", "")
except Exception as err:
    print(f'inbox[1]{{error}}: "token refresh failed: {err}"')
    sys.exit(1)
if not token:
    print('inbox[1]{error}: "no access token"')
    sys.exit(1)

q = []
if os.environ.get("FROM_Q"):
    q.append(f"from:{os.environ['FROM_Q']}")
if os.environ.get("TO_Q"):
    q.append(f"to:{os.environ['TO_Q']}")
if os.environ.get("UNREAD_Q") == "1":
    q.append("is:unread")
if not q:
    q.append("in:anywhere")
q.append(f"newer_than:{os.environ.get('DAYS_Q', '7')}d")
query = " ".join(q)

url = "https://gmail.googleapis.com/gmail/v1/users/me/messages?" + urllib.parse.urlencode(
    {"q": query, "maxResults": os.environ.get("LIMIT_Q", "10")})
req = urllib.request.Request(url, headers={"Authorization": "Bearer " + token})
try:
    with urllib.request.urlopen(req, timeout=30) as r:
        listing = json.load(r)
except Exception as err:
    print(f'inbox[1]{{error}}: "list failed: {err}"')
    sys.exit(1)

ids = [m["id"] for m in listing.get("messages", [])]
print(f'inbox[{len(ids)}]{{id,date,from,subject,snippet}}:"{query}"')
for mid in ids:
    detail_req = urllib.request.Request(
        f"https://gmail.googleapis.com/gmail/v1/users/me/messages/{mid}?format=full",
        headers={"Authorization": "Bearer " + token})
    with urllib.request.urlopen(detail_req, timeout=30) as r:
        msg = json.load(r)
    headers = {h["name"].lower(): h["value"] for h in msg.get("payload", {}).get("headers", [])}
    snippet = (msg.get("snippet") or "").replace('"', "'")[:120]
    print(f'  "{mid}","{headers.get("date","")}","{headers.get("from","")}",'
          f'"{headers.get("subject","")}","{snippet}"')
    if os.environ.get("BODY_Q") == "1":
        def walk(part):
            out = ""
            if part.get("body", {}).get("data"):
                out += base64.urlsafe_b64decode(part["body"]["data"] + "===").decode("utf8", "replace")
            for sub in part.get("parts", []) or []:
                out += walk(sub)
            return out
        text = walk(msg.get("payload", {}))[:2000]
        print("  --- body ---")
        for line in text.splitlines()[:25]:
            print("  " + line[:160])
PY
