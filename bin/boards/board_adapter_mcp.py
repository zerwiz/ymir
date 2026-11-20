"""board_adapter_mcp.py — the generic `mcp` adapter of the board contract (plan 335, "the split").

Any board that speaks the contract over MCP is reached with a URL and a token REFERENCE, both read from the
project's `board:` block in the home's registry. Ymir contains no engine inside this file: the board behind the
URL decides what a place and a state are. The adapter, not its callers, turns a state GROUP into the board's own
state name (through the board's `list_states`).

The contract this adapter implements (the card shape is a plain dict):
    ensure_label(name)
    list_cards(label) -> [{"card", "title", "group", "labels"}]        # all pages, flagged when a page was full
    find_cards(label, text) -> same, narrowed by a title fragment
    get_card(card) -> {"card", "title", "group", "labels", "description"}
    create_card(title, description, group, labels)
    update_card(card, title=None, description=None, group=None)
State groups: backlog · unstarted · started · review · done · cancelled.
Never prints or stores a token.
"""
import json
import os
import re
import subprocess
import time
import urllib.error
import urllib.request

GROUPS = ("backlog", "unstarted", "started", "review", "done", "cancelled")
_ENGINE_GROUP = {"completed": "done", "canceled": "cancelled"}  # a board's own spelling → the contract's
PAGE = 200  # the largest page a board lists
PACE = 0.25  # seconds between writes, so a board's rate limit is not met at a run of hundreds


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
        self._wrote = 0.0

    # ── transport ────────────────────────────────────────────────────────────────────────────
    def _call(self, tool, args):
        self.n += 1
        body = json.dumps({"jsonrpc": "2.0", "id": self.n, "method": "tools/call",
                           "params": {"name": tool, "arguments": args}}).encode()
        hdr = {"Authorization": f"Bearer {self.token}", "Content-Type": "application/json",
               "Accept": "application/json, text/event-stream", "User-Agent": "ymir-board-mcp/1.0"}
        last = ""
        for attempt in range(6):
            wait = 2.0 * (attempt + 1)
            try:
                raw = urllib.request.urlopen(urllib.request.Request(self.url, body, hdr), timeout=60).read().decode()
            except urllib.error.HTTPError as e:
                last = f"HTTP {e.code}"
                if e.code not in (429, 500, 502, 503, 504):
                    raise BoardRefusal(f"{tool}: {last}")
                time.sleep(wait)
                continue
            except (urllib.error.URLError, TimeoutError) as e:
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
        out = self._call(tool, args)
        self._wrote = time.time()
        return out

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
            self._write("create_label", {"place": self.place, "name": name, "color": "#7c6f9f"})
        return True

    def _shape(self, c):
        return {"card": c["card"], "title": c.get("title", ""), "group": self.group_of(c.get("state")),
                "labels": c.get("labels") or [], "description": c.get("description")}

    def list_cards(self, label):
        out = []
        for name, _ in self.states():
            got = self._call("list_cards", {"place": self.place, "label": label, "state": name, "limit": PAGE}).get("cards", [])
            if len(got) >= PAGE:
                self.page_full = True
            out += [self._shape(c) for c in got]
        return out

    def find_cards(self, label, text):
        got = self._call("list_cards", {"place": self.place, "label": label, "query": text, "limit": 50}).get("cards", [])
        return [self._shape(c) for c in got]

    def get_card(self, card):
        return self._shape(self._call("get_card", {"place": self.place, "card": str(card)}))

    def create_card(self, title, description, group, labels):
        return self._write("create_card", {"place": self.place, "title": title, "description": description,
                                           "state": self.state_name(group), "labels": labels})

    def update_card(self, card, title=None, description=None, group=None):
        a = {"place": self.place, "card": str(card)}
        if title is not None:
            a["title"] = title
        if description is not None:
            a["description"] = description
        if group is not None:
            a["state"] = self.state_name(group)
        return self._write("update_card", a)
