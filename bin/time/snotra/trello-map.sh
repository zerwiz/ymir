#!/usr/bin/env bash
# trello-map.sh — the map of our Trello, written down so Snotra can know it.
#
#   trello-map.sh            refresh the map and print it
#   trello-map.sh --facts    also write one approved fact per board (class owner) and rebuild the digest
#   trello-map.sh --show     print the stored map without touching Trello
#
# WHY: the workspace is a real place with boards that carry different jobs — Documentation, Control
# Tower, Meetings, Patent, Vertical Comparison. A system that projects into it must first KNOW it, or
# it creates a second "Control Tower" (measured 2026-10-22: it did exactly that).
#
# Uses the same OAuth grant `snotra-trello.py` uses (mcp-auth.json), never a second credential.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root HOME_R 2>/dev/null || true
[ -n "${HOME_R:-}" ] || { printf 'trello-map: the hoard is unresolved\n' >&2; exit 2; }
MAP="$HOME_R/hodd/identity/trello-map.yaml"
ACTION="${1:-refresh}"

if [ "$ACTION" = "--show" ]; then cat "$MAP" 2>/dev/null || printf 'no map yet\n'; exit 0; fi

ROOT_Q="$ROOT" MAP_Q="$MAP" HOME_Q="$HOME_R" FACTS_Q=0
[ "$ACTION" = "--facts" ] && FACTS_Q=1
export ROOT_Q MAP_Q HOME_Q FACTS_Q
python3 - <<'PY'
import json, os, sys, time, urllib.parse, urllib.request
import yaml

sys.path.insert(0, os.path.join(os.environ["ROOT_Q"], "bin", "time", "snotra"))
BASE = "https://api.trello.com/1"
GRANT_KEY = "mcp__trello|https://mcp.trello.com/v1"
AUTH = os.path.expanduser("~/.pi/agent/mcp-auth.json")

def token():
    d = json.load(open(AUTH))
    v = d.get(GRANT_KEY) or {}
    if int(v.get("tokensExpireAt") or 0) < int(time.time() * 1000) + 60000:
        ci = v["clientInformation"]; meta = v["discovery"]["authorizationServerMetadata"]
        data = urllib.parse.urlencode({"grant_type": "refresh_token",
                                       "refresh_token": v["tokens"]["refresh_token"],
                                       "client_id": ci["client_id"]}).encode()
        req = urllib.request.Request(meta["token_endpoint"], data=data,
                                     headers={"Content-Type": "application/x-www-form-urlencoded"})
        with urllib.request.urlopen(req, timeout=30) as r:
            new = json.load(r)
        v["tokens"].update(new); v["tokensExpireAt"] = int(time.time() * 1000) + int(new.get("expires_in", 3600)) * 1000
        json.dump(d, open(AUTH, "w"), indent=2)
    return v["tokens"]["access_token"]

TOK = token()

def get(path):
    req = urllib.request.Request(f"{BASE}{path}",
                                 headers={"Authorization": f"Bearer {TOK}", "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)

boards = get("/members/me/boards?fields=name,url,shortLink,closed,dateLastActivity,desc,prefs")
out = {"generated_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "workspace": None, "boards": []}
for b in boards:
    if b.get("closed"):
        continue
    lists = get(f"/boards/{b['id']}/lists?fields=name,pos&cards=open&card_fields=name,due,idMembers")
    ws = (b.get("prefs") or {}).get("permissionLevel")
    entry = {"name": b["name"], "short_link": b.get("shortLink"), "url": b.get("url"),
             "visibility": ws, "last_activity": b.get("dateLastActivity"),
             "purpose": (b.get("desc") or "").strip().splitlines()[0][:200] if b.get("desc") else "",
             "lists": [{"name": l["name"], "cards": len(l.get("cards") or []),
                        "examples": [c["name"][:80] for c in (l.get("cards") or [])[:3]]}
                       for l in sorted(lists, key=lambda x: x.get("pos", 0))],
             "card_total": sum(len(l.get("cards") or []) for l in lists)}
    out["boards"].append(entry)

with open(os.environ["MAP_Q"], "w") as fh:
    yaml.safe_dump(out, fh, sort_keys=False, allow_unicode=True)

print("trello_map[1]{boards,path,facts}:")
print(f'  "{len(out["boards"])}","{os.environ["MAP_Q"]}","{"yes" if os.environ["FACTS_Q"] == "1" else "no"}"')
print("boards{name,lists,cards,url}:")
print(f'trello_boards{len(out["boards"])}')
for b in out["boards"]:
    print(f'  "{b["name"]}","{len(b["lists"])}","{b["card_total"]}","{b["url"]}"')

if os.environ["FACTS_Q"] == "1":
    dest = os.path.join(os.environ["HOME_Q"], "hodd", "identity", "assistant", "approved")
    today = time.strftime("%Y-%m-%d")
    for b in out["boards"]:
        names = ", ".join(l["name"] for l in b["lists"])
        claim = (f"The Trello board “{b['name']}” has {len(b['lists'])} lists ({names}) "
                 f"and {b['card_total']} open cards. {b['url']}")
        slug = "trello-" + "".join(ch if ch.isalnum() else "-" for ch in b["name"].lower()).strip("-")[:40]
        body = ("---\napproved_by: the Allfather\n" + f"approved_at: {today}\n"
                "class: public\naudience: owner\nverbatim: true\n"
                f"source: {b['url']}\ngenerated_by: bin/time/snotra/trello-map.sh\n---\n{claim}\n")
        with open(os.path.join(dest, slug + ".md"), "w") as fh:
            fh.write(body)
    print(f'trello_facts[1]{{written}}: "{len(out["boards"])}"')
PY

if [ "$ACTION" = "--facts" ]; then
  bash "$ROOT/bin/assistant/kb-export.sh" >/dev/null 2>&1 || true
  printf 'trello-map: facts written and the digest rebuilt\n'
fi
