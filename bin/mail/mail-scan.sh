#!/usr/bin/env bash
# mail-scan.sh — read-only: the last N hours of a mailbox, as compact JSON.
#
#   mail-scan.sh [--hours 24] [--max 40] [--account primary]
#
# It can only READ. There is no send, no draft, no modify in this file — the
# secretary's first law is that the sender does not exist in her hands.
set -uo pipefail

ROOT="${YMIR_TREE:-$HOME/ymir}"
HOURS=24; MAX=40
while [ $# -gt 0 ]; do case "$1" in
  --hours) HOURS="${2-}"; shift 2 ;;
  --max) MAX="${2-}"; shift 2 ;;
  --account) shift 2 ;;
  *) echo "usage: mail-scan.sh [--hours N] [--max N]" >&2; exit 2 ;;
esac; done

SEC="$(cd "$ROOT" && ./bin/vault/hodd.sh emit secrets/platform.env 2>/dev/null)"
get(){ printf '%s\n' "$SEC" | sed -n "s/^export $1=//p" | head -1 | sed "s/^['\"]//; s/['\"]$//"; }
CID="$(get GOOGLE_MCP_CLIENT_ID)"; CSEC="$(get GOOGLE_MCP_CLIENT_SECRET)"; RT="$(get SNOTRA_GOOGLE_REFRESH_TOKEN)"
[ -n "$CID" ] && [ -n "$CSEC" ] && [ -n "$RT" ] || { echo '{"error":"google credentials missing"}' >&2; exit 1; }

TOKEN="$(curl -sS -m 20 -X POST https://oauth2.googleapis.com/token \
  -d "client_id=$CID" -d "client_secret=$CSEC" -d "refresh_token=$RT" -d grant_type=refresh_token \
  | python3 -c 'import json,sys;print(json.load(sys.stdin).get("access_token",""))')"
[ -n "$TOKEN" ] || { echo '{"error":"token refresh failed"}' >&2; exit 1; }

# unread in the inbox, newest first — the desk's raw material
Q="is:unread in:inbox newer_than:${HOURS}h"
LIST="$(curl -sS -m 30 -G "https://gmail.googleapis.com/gmail/v1/users/me/messages" \
  -H "Authorization: Bearer $TOKEN" \
  --data-urlencode "q=$Q" --data-urlencode "maxResults=$MAX")"

LISTF="$(mktemp)"; trap 'rm -f "$LISTF"' EXIT
printf '%s' "$LIST" > "$LISTF"
LISTF="$LISTF" TOKEN="$TOKEN" python3 - <<'PY'
import json, os, sys, urllib.request

token = os.environ["TOKEN"]
data = json.load(open(os.environ["LISTF"]))
if "error" in data:
    print(json.dumps({"error": data["error"].get("message", "list failed")}))
    raise SystemExit(0)

def get(mid):
    url = ("https://gmail.googleapis.com/gmail/v1/users/me/messages/%s"
           "?format=metadata&metadataHeaders=From&metadataHeaders=Subject&metadataHeaders=Date" % mid)
    req = urllib.request.Request(url, headers={"Authorization": "Bearer " + token})
    with urllib.request.urlopen(req, timeout=20) as r:
        m = json.load(r)
    h = {x["name"]: x["value"] for x in m.get("payload", {}).get("headers", [])}
    return {
        "id": m.get("id"),
        "thread": m.get("threadId"),
        "from": h.get("From"),
        "subject": h.get("Subject"),
        "date": h.get("Date"),
        "snippet": (m.get("snippet") or "")[:240],
        "labels": m.get("labelIds", []),
    }

out = [get(m["id"]) for m in data.get("messages", [])]
print(json.dumps({"count": len(out), "messages": out}, ensure_ascii=False, indent=1))
PY
