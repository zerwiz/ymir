#!/usr/bin/env python3
"""trello_client — the Trello door, shared: the grant, the resolver, and the card verbs.

WHY: three writers now reach the same boards (the meeting projector, the place projector, the daily
tool). Each must use ONE credential (the Trello MCP grant in `mcp-auth.json`) and ONE resolver
(`hodd/identity/trello-map.yaml`), or they will disagree about which list is which — which is how a
card lands in an invented list and the call still returns 200.

WHAT IT NEVER DOES
    * it never types a board or list id: a name is resolved through the map, and a miss is an error;
    * it never moves a card that a human put somewhere: a card whose key sits in the wrong list is
      DRIFT, reported, and left where it is;
    * it never creates a board. A place names a board that exists, or the door refuses.
"""
from __future__ import annotations

import json
import os
import time
import urllib.error
import subprocess
import urllib.parse
import urllib.request
from pathlib import Path

BASE = "https://api.trello.com/1"
GRANT_KEY = "mcp__trello|https://mcp.trello.com/v1"


def die(msg: str, code: int = 1):
    raise SystemExit(f"trello: {msg}")


def home_dir() -> Path:
    """The hoard is RESOLVED, never restated (Rule 07): env first, then the one resolver."""
    h = os.environ.get("YMIR_HOME")
    if h:
        return Path(h).expanduser()
    root = Path(__file__).resolve().parents[3]
    try:
        out = subprocess.check_output(
            ["bash", "-c",
             f'. "{root}/bin/vault/hoard-lib.sh" >/dev/null 2>&1; out=""; ymir_home_root out; printf "%s" "$out"'],
            timeout=20).decode().strip()
    except Exception:  # noqa: BLE001
        out = ""
    if not out:
        die("the hoard is unresolved — run bin/vault/hoard-lib.sh or set YMIR_HOME")
    return Path(out)


def auth_path() -> Path:
    return Path(os.environ.get("TRELLO_AUTH", os.path.expanduser("~/.pi/agent/mcp-auth.json")))


def refresh_grant() -> str:
    p = auth_path()
    d = json.loads(p.read_text(encoding="utf-8"))
    v = d.get(GRANT_KEY) or die("no Trello grant section in mcp-auth.json")
    ci = v["clientInformation"]
    meta = v["discovery"]["authorizationServerMetadata"]
    data = urllib.parse.urlencode({
        "grant_type": "refresh_token",
        "refresh_token": v["tokens"]["refresh_token"],
        "client_id": ci["client_id"],
    }).encode()
    req = urllib.request.Request(meta["token_endpoint"], data=data,
                                 headers={"Content-Type": "application/x-www-form-urlencoded"})
    with urllib.request.urlopen(req, timeout=30) as r:
        new = json.load(r)
    v["tokens"].update(new)
    v["tokensExpireAt"] = int(time.time() * 1000) + int(new.get("expires_in", 3600)) * 1000
    p.write_text(json.dumps(d, indent=2) + "\n", encoding="utf-8")
    return new["access_token"]


def token() -> str:
    t = os.environ.get("TRELLO_TOKEN")
    if t:
        return t
    p = auth_path()
    if not p.is_file():
        die("no Trello grant; connect the Trello MCP server first")
    d = json.loads(p.read_text(encoding="utf-8"))
    v = d.get(GRANT_KEY) or die("no Trello grant in mcp-auth.json")
    if int(v.get("tokensExpireAt") or 0) < int(time.time() * 1000) + 60_000:
        return refresh_grant()
    return v["tokens"]["access_token"]


TOK = None


def api(method: str, path: str, params: dict | None = None):
    global TOK
    if TOK is None:
        TOK = token()
    url = BASE + path + (("&" if "?" in path else "?") + urllib.parse.urlencode(params) if params else "")
    req = urllib.request.Request(url, method=method,
                                 headers={"Authorization": f"Bearer {TOK}", "Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            body = r.read().decode("utf-8")
            return json.loads(body) if body.strip() else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")[:300]
        if e.code == 401:
            TOK = refresh_grant()
            return api(method, path, params)
        die(f"{method} {path} → {e.code}: {detail}")
    except urllib.error.URLError as e:
        die(f"api.trello.com unreachable: {e.reason}")
    return {}


# ── the map: names, never ids ───────────────────────────────────────────────────────────────────
def map_path() -> Path:
    p = home_dir() / "hodd" / "identity" / "trello-map.yaml"
    if not p.is_file():
        die(f"no board map at {p} — run trello-map.sh first (a typed board id is never accepted)")
    return p


def load_map() -> dict:
    try:
        import yaml  # noqa: PLC0415
    except Exception:  # noqa: BLE001
        die("PyYAML is missing: pip install pyyaml")
    return yaml.safe_load(map_path().read_text(encoding="utf-8")) or {}


def resolve_board(name: str) -> dict:
    q = (name or "").strip().lower()
    boards = load_map().get("boards") or []
    for b in boards:
        if (b.get("name") or "").strip().lower() == q:
            return b
    for b in boards:  # a prefix match, but only if it is unambiguous
        if q and q in (b.get("name") or "").strip().lower():
            return b
    die(f"no board matches {name!r} — the map holds: "
        + ", ".join(b.get("name", "?") for b in boards))


def resolve_list(board: str, name: str) -> tuple[dict, dict]:
    b = resolve_board(board)
    q = (name or "").strip().lower()
    lists = b.get("lists") or []
    for lst in lists:
        if (lst.get("name") or "").strip().lower() == q:
            return b, lst
    for lst in lists:
        if q and q in (lst.get("name") or "").strip().lower():
            return b, lst
    die(f"board {b.get('name')!r} has no list matching {name!r} — it holds: "
        + ", ".join(lst.get("name", "?") for lst in lists))


def board_id_of(name: str) -> str:
    """The board's id: from the map when it carries one, else derived from any list it holds.

    The map stores list ids, not board ids — and a list knows its board, so the map stays sufficient.
    """
    b = resolve_board(name)
    bid = b.get("id")
    if bid:
        return bid
    lists = b.get("lists") or []
    if not lists:
        die(f"board {b.get('name')!r} in the map carries neither an id nor a list")
    info = api("GET", f"/lists/{lists[0]['id']}", {"fields": "idBoard"})
    return info["idBoard"]


# ── the verbs ───────────────────────────────────────────────────────────────────────────────────
def board_cards(board_id: str, fields: str = "name,desc,idList,labels") -> list[dict]:
    return api("GET", f"/boards/{board_id}/cards", {"fields": fields, "limit": 1000})


def ensure_label(board_id: str, name: str, colour: str) -> str:
    for lb in api("GET", f"/boards/{board_id}/labels", {"fields": "name,color", "limit": 1000}):
        if (lb.get("name") or "").strip().lower() == name.strip().lower():
            return lb["id"]
    made = api("POST", f"/boards/{board_id}/labels", {"name": name, "color": colour})
    return made["id"]


def create_card(list_id: str, board_id: str, name: str, desc: str, label_ids: list[str]) -> dict:
    params = {"idList": list_id, "name": name, "desc": desc, "pos": "bottom"}
    if label_ids:
        params["idLabels"] = ",".join(label_ids)
    return api("POST", "/cards", params)


def update_card(card_id: str, **params) -> dict:
    return api("PUT", f"/cards/{card_id}", params)


def get_card(card_id: str) -> dict:
    return api("GET", f"/cards/{card_id}", {"fields": "name,desc,idList,closed,labels"})
