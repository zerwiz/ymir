#!/usr/bin/env python3
"""board_adapter_mcp.py — the generic `mcp` adapter of the board contract (plan 335, "the split").

Any board that speaks the contract over MCP is reached with a URL and a token REFERENCE, both read from the
project's `board:` block in the home's registry. Ymir contains no engine inside this file: the board behind the
URL decides what a place and a state are. The adapter, not its callers, turns a state GROUP into the board's own
state name (through the board's `list_states`).

The contract this adapter implements (the card shape is a plain dict):
    ensure_label(name)
    list_cards(label) -> [{"card", "title", "group", "labels"}]        # all pages, flagged when a page was full
    list_all() -> [{"card", "title", "group", "labels", "parent", "stamp"}]   # every card, paged to the end
    find_cards(label, text) -> same, narrowed by a title fragment
    get_card(card) -> {"card", "title", "group", "labels", "description", "stamp", "links", "children"}
    create_card(title, description, group, labels, parent=None, fmt=None, source=None) -> {"card", "diagrams"}
    update_card(card, title=None, description=None, group=None, fmt=None) -> {"diagrams"}
    add_link(card, url, title)
State groups: backlog · unstarted · started · review · done · cancelled.
A description may be `fmt="markdown"`: the board keeps the document's shape and draws what it can (diagrams); the
answer's `diagrams` names what it could not. A card may carry `[stamp: <word>]` in its description — the writer's
own fingerprint — and listings return it, so a writer can tell what it last wrote without reading every card.
Never prints or stores a token.
"""
import http.client
import json
import os
import re
import shlex
import subprocess
import time
import urllib.error
import urllib.request

GROUPS = ("backlog", "unstarted", "started", "review", "done", "cancelled")
_ENGINE_GROUP = {"completed": "done", "canceled": "cancelled"}  # a board's own spelling → the contract's
PAGE = 200  # the largest page a board lists
VISIBLE = 100  # measured 2026-11-20: a board may show only its newest 100 cards of a place, so a full list proves nothing
PACE = float(os.environ.get("YMIR_BOARD_PACE", "2.5"))  # seconds between writes: a board API may allow ~60 calls a minute, shared by everyone on its key
WRITE_TIMEOUT = 300  # a write that draws diagrams on the board's side may take a while


class BoardRefusal(Exception):
    pass


def resolve_token(ref, home, root):
    kind, _, name = (ref or "").partition(":")
    if kind == "env":
        v = os.environ.get(name, "")
    elif kind == "vault":
        out = subprocess.run(["bash", os.path.join(root, "bin/vault/hodd.sh"), "emit", "secrets/platform.env"],
                             capture_output=True, text=True, env=dict(os.environ, YMIR_HOME=home)).stdout
        m = re.search(rf"^export {re.escape(name)}=(.*)$", out, re.M)
        v = m.group(1).strip("\"' ") if m else ""
    elif kind == "claude-mcp":  # the seat's own MCP config
        cfg = os.environ.get("CLAUDE_CONFIG_JSON") or os.path.expanduser("~/.claude.json")
        try:
            srv = (json.load(open(cfg)).get("mcpServers") or {}).get(name) or {}
        except (OSError, ValueError):
            srv = {}
        v = next((x for k, x in (srv.get("headers") or {}).items() if k.lower() == "authorization"), "")
        if not v and srv.get("headersHelper"):
            # the harness's own helper prints the headers as JSON (an enrolled seat keeps its token in a 0600 file,
            # never in the config); asked the same way the harness asks it
            try:
                out = subprocess.run(shlex.split(srv["headersHelper"]), capture_output=True, text=True, timeout=30).stdout
                v = next((x for k, x in (json.loads(out or "{}") or {}).items() if k.lower() == "authorization"), "")
            except (OSError, ValueError, subprocess.SubprocessError):
                v = ""
        v = re.sub(r"^Bearer\s+", "", v, flags=re.I)
    else:
        raise BoardRefusal(f"token_from '{ref}' is not env:, vault: or claude-mcp:")
    if not v:
        raise BoardRefusal(f"the token named by '{ref}' is not there (its value is never printed)")
    return v


class McpBoard:
    def __init__(self, place, url, token):
        self.place, self.url, self.token, self.n = place, url, token, 0
        self._states = None
        self.page_full = False  # set when a list came back at the page limit: more may exist
        self.saturated = False  # set when a list shows as many cards as the board is known to reveal: older ones may be hidden
        self._wrote = 0.0
        self._last_count = None
        self._schemas = None

    # ── transport ────────────────────────────────────────────────────────────────────────────
    def _call(self, tool, args, timeout=60):
        self.n += 1
        body = json.dumps({"jsonrpc": "2.0", "id": self.n, "method": "tools/call",
                           "params": {"name": tool, "arguments": args}}).encode()
        hdr = {"Authorization": f"Bearer {self.token}", "Content-Type": "application/json",
               "Accept": "application/json, text/event-stream", "User-Agent": "ymir-board-mcp/1.0"}
        last = ""
        for attempt in range(8):
            wait = 4.0 * (attempt + 1)
            try:
                raw = urllib.request.urlopen(urllib.request.Request(self.url, body, hdr), timeout=timeout).read().decode()
            except urllib.error.HTTPError as e:
                last = f"HTTP {e.code}"
                if e.code not in (429, 500, 502, 503, 504, 520, 521, 522, 523, 524, 530):  # 52x/530: the tunnel in front blinked
                    raise BoardRefusal(f"{tool}: {last}")
                time.sleep(wait)
                continue
            except (urllib.error.URLError, TimeoutError, http.client.HTTPException, ConnectionError) as e:
                # a page cut short on the way (IncompleteRead through a tunnel) is a hiccup: ask again
                last = str(e)
                time.sleep(wait)
                continue
            if raw.lstrip().startswith(("event:", "data:")):
                raw = next((l[5:].strip() for l in raw.splitlines() if l.startswith("data:")), "{}")
            msg = json.loads(raw)
            res = msg.get("result") or {}
            text = "".join(c.get("text", "") for c in res.get("content", []))
            if res.get("isError") or "error" in msg:
                last = text or str(msg.get("error"))
                if re.search(r"\b(429|50[0-4])\b", last):  # the board's own rate limit or a hiccup: wait and retry
                    time.sleep(wait)
                    continue
                raise BoardRefusal(f"{tool}: {last}")
            try:
                return json.loads(text) if text else {}
            except ValueError:
                return {"text": text}
        raise BoardRefusal(f"{tool}: {last}")

    def _write(self, tool, args):
        gap = PACE - (time.time() - self._wrote)
        if gap > 0:
            time.sleep(gap)
        out = self._call(tool, args, timeout=WRITE_TIMEOUT)
        self._wrote = time.time()
        return out

    def _accepts(self, tool, prop):
        """Does the board's `tool` take `prop`? Read once from tools/list; an older board is spoken to as it is."""
        if self._schemas is None:
            self.n += 1
            body = json.dumps({"jsonrpc": "2.0", "id": self.n, "method": "tools/list", "params": {}}).encode()
            hdr = {"Authorization": f"Bearer {self.token}", "Content-Type": "application/json",
                   "Accept": "application/json, text/event-stream", "User-Agent": "ymir-board-mcp/1.0"}
            try:
                raw = urllib.request.urlopen(urllib.request.Request(self.url, body, hdr), timeout=60).read().decode()
                if raw.lstrip().startswith(("event:", "data:")):
                    raw = next((l[5:].strip() for l in raw.splitlines() if l.startswith("data:")), "{}")
                tools = (json.loads(raw).get("result") or {}).get("tools", [])
                self._schemas = {t["name"]: set(((t.get("inputSchema") or {}).get("properties") or {}).keys())
                                 for t in tools}
            except (urllib.error.URLError, ValueError, KeyError, TimeoutError):
                self._schemas = {}
        return prop in self._schemas.get(tool, set())

    # ── states: a group is the contract's word, a state name is the board's ─────────────────
    def states(self):
        if self._states is None:
            rows = self._call("list_states", {"place": self.place}).get("states", [])
            self._states = [(r["name"], _ENGINE_GROUP.get(r.get("group"), r.get("group"))) for r in rows]
        return self._states

    def state_name(self, group):
        names = [n for n, g in self.states() if g == group]
        if not names and group == "review":  # a board with no review state keeps it in progress
            names = [n for n, g in self.states() if g == "started"]
        if not names:
            raise BoardRefusal(f"the board at {self.place} has no state in the group '{group}'")
        return names[0]

    def group_of(self, state_name):
        return next((g for n, g in self.states() if n == state_name), None)

    # ── the contract ─────────────────────────────────────────────────────────────────────────
    def ensure_label(self, name, dry=False):
        have = [x.get("name") if isinstance(x, dict) else x
                for x in self._call("list_labels", {"place": self.place}).get("labels", [])]
        if name in have:
            return False
        if not dry:
            self._write("create_label", {"place": self.place, "name": name, "color": "#9a8f75"})
        return True

    def _shape(self, c):
        return {"card": c["card"], "title": c.get("title", ""), "group": self.group_of(c.get("state")),
                "labels": c.get("labels") or [], "description": c.get("description"),
                "parent": c.get("parent"), "stamp": c.get("stamp"), "links": c.get("links") or [],
                "children": [dict(ch, group=_ENGINE_GROUP.get(ch.get("state_group"), ch.get("state_group")))
                             for ch in c.get("children") or []]}

    def list_all(self):
        """Every card of the place, paged to the end with `offset`. A board that cannot page is flagged saturated."""
        if not self._accepts("list_cards", "offset"):
            self.saturated = True
            return [self._shape(c) for c in self._call("list_cards", {"place": self.place, "limit": PAGE}).get("cards", [])]
        out, offset = [], 0
        while True:
            r = self._call("list_cards", {"place": self.place, "limit": PAGE, "offset": offset})
            got = r.get("cards", [])
            out += [self._shape(c) for c in got]
            offset += len(got)
            if not got or offset >= int(r.get("count") or 0):
                return out

    def list_cards(self, label):
        out = []
        for name, _ in self.states():
            r = self._call("list_cards", {"place": self.place, "label": label, "state": name, "limit": PAGE})
            got, self._last_count = r.get("cards", []), r.get("count")
            if len(got) >= PAGE:
                self.page_full = True
            if len(got) >= VISIBLE or (self._last_count or 0) >= VISIBLE:
                self.saturated = True
            out += [self._shape(c) for c in got]
        return out

    def find_cards(self, label, text):
        got = self._call("list_cards", {"place": self.place, "label": label, "query": text, "limit": 50}).get("cards", [])
        return [self._shape(c) for c in got]

    def get_card(self, card):
        return self._shape(self._call("get_card", {"place": self.place, "card": str(card)}))

    def create_card(self, title, description, group, labels, parent=None, fmt=None, source=None):
        a = {"place": self.place, "title": title, "description": description, "state": self.state_name(group),
             "labels": labels}
        if parent is not None:
            a["parent"] = str(parent)
        if fmt and self._accepts("create_card", "description_format"):
            a["description_format"] = fmt
        if source and self._accepts("create_card", "source"):
            a["source"] = source
        out = self._write("create_card", a)
        made = out.get("created") or {}
        return {"card": made.get("card"), "diagrams": out.get("diagrams")}

    def update_card(self, card, title=None, description=None, group=None, fmt=None):
        a = {"place": self.place, "card": str(card)}
        if title is not None:
            a["title"] = title
        if description is not None:
            a["description"] = description
            if fmt and self._accepts("update_card", "description_format"):
                a["description_format"] = fmt
        if group is not None:
            a["state"] = self.state_name(group)
        out = self._write("update_card", a)
        return {"diagrams": out.get("diagrams")}

    def add_link(self, card, url, title):
        return self._write("add_link", {"place": self.place, "card": str(card), "url": url, "title": title})
