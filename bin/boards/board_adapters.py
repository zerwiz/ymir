#!/usr/bin/env python3
"""board_adapters.py — the `file`, `github` and `trello` adapters of the board contract (plan 335 phase 2).

Each speaks the SAME verbs as the `mcp` adapter (board_adapter_mcp.py): ensure_label, can_relate, relations,
add_relation, list_all, list_cards, find_cards, get_card, create_card, update_card, add_link. A project on any tool
gets the same plan cards: a state group, labels, a start date, a DONE date, a priority, an owner and relations. A
tool with no typed relations keeps them as links (a Trello attachment, a GitHub comment, a BOARD.md column).

The registry row's `board.adapter` picks one (`make_board`). State groups: backlog · unstarted · started · review ·
done · cancelled. Nothing here prints or stores a credential; the REST and `gh` doors are injectable so a test needs
no network.
"""
import json
import os
import re
import subprocess

GROUPS = ("backlog", "unstarted", "started", "review", "done", "cancelled")
STAMP = re.compile(r"\[stamp: ([^\]]+)\]")
RELATIONS = ("relates_to", "blocking", "blocked_by", "duplicate", "start_before", "start_after",
             "finish_before", "finish_after")
# the words a tool's own columns/lists use for each group (first match wins)
GROUP_WORDS = {
    "backlog": ["backlog", "proposed", "inbox", "icebox"],
    "unstarted": ["todo", "to do", "unstarted", "accepted", "next", "ready"],
    "started": ["in progress", "doing", "started", "today"],
    "review": ["review", "in review", "testing"],
    "done": ["done", "completed", "closed", "shipped"],
    "cancelled": ["cancelled", "canceled", "dropped", "won't do", "wontdo"],
}


class AdapterRefusal(Exception):
    pass


def group_of_name(name):
    n = (name or "").strip().lower()
    for g, words in GROUP_WORDS.items():
        if n in words:
            return g
    return None


def name_for_group(names, group):
    """Of a tool's own state names, the one standing for `group`; a tool with no review keeps it in progress."""
    for g in ([group] + (["started"] if group == "review" else [])):
        for w in GROUP_WORDS[g]:
            for n in names:
                if n.strip().lower() == w:
                    return n
    return None


def stamp_of(desc):
    m = STAMP.search(desc or "")
    return m.group(1) if m else None


class Base:
    """The contract, written once over four primitives each adapter supplies:
    `_cards()` -> [record], `_make(rec) -> number`, `_patch(number, **fields)`, `_labels()` / `_new_label(name)`,
    plus `_rel_add` / `_rel_get` / `_link_add` / `_links_of`. A record is a dict with card, title, group, labels,
    description, parent, start, done, priority, assignees."""

    # ── the contract ─────────────────────────────────────────────────────────────────────
    def ensure_label(self, name, dry=False):
        if name in self._labels():
            return False
        if not dry:
            self._new_label(name)
        return True

    def can_relate(self):
        return True

    def relations(self, card):
        return {(str(r), str(o)) for r, o in self._rel_get(card)}

    def add_relation(self, card, relation, other):
        if relation not in RELATIONS:
            raise AdapterRefusal(f"relation '{relation}' is not one of {', '.join(RELATIONS)}")
        return self._rel_add(card, relation, other)

    def add_link(self, card, url, title):
        return self._link_add(card, url, title)

    def _shape(self, r):
        return {"card": r["card"], "title": r.get("title", ""), "group": r.get("group"),
                "labels": list(r.get("labels") or []), "description": r.get("description") or "",
                "parent": r.get("parent"), "stamp": stamp_of(r.get("description")),
                "start": r.get("start") or "", "done": r.get("done") or "", "priority": r.get("priority") or "none",
                "assignees": list(r.get("assignees") or []), "links": []}

    def list_all(self):
        return [self._shape(r) for r in self._cards()]

    def list_cards(self, label):
        return [c for c in self.list_all() if not label or label in c["labels"]]

    def find_cards(self, label, text):
        return [c for c in self.list_cards(label) if (text or "").lower() in c["title"].lower()]

    def get_card(self, card):
        for c in self.list_all():
            if str(c["card"]) == str(card):
                c["links"] = self._links_of(card)
                return c
        raise AdapterRefusal(f"no card {card} on this board")

    def create_card(self, title, description, group, labels, parent=None, fmt=None, source=None, assignees=None,
                    start=None, priority=None, done=None):
        rec = {"title": title, "description": description, "group": group, "labels": list(labels or []),
               "parent": parent, "start": start or "", "priority": priority or "none",
               "assignees": list(assignees or []), "done": done or ""}
        num = self._make(rec)
        if done:
            self._closed(num, done)
        return {"card": num, "diagrams": None}

    def update_card(self, card, title=None, description=None, group=None, fmt=None, start=None, assignees=None,
                    labels=None, parent=None, priority=None, done=None):
        fields = {k: v for k, v in (("title", title), ("description", description), ("group", group),
                                    ("start", start), ("assignees", assignees), ("labels", labels),
                                    ("parent", parent), ("priority", priority), ("done", done)) if v}
        if fields:
            self._patch(card, **fields)
        if done:
            self._closed(card, done)
        return {"diagrams": None}

    def _closed(self, card, day):
        """The DONE date: written into the card's own field by `_patch(done=…)`; a tool with a place for a note also
        gets the comment `closed YYYY-MM-DD` (adapters override)."""


# ── the file board ───────────────────────────────────────────────────────────────────────────

FILE_COLS = ["#", "Title", "State", "Labels", "Parent", "Owner", "Start", "Done", "Priority", "Relations", "Links"]


def _esc(s):
    return str(s or "").replace("\\", "\\\\").replace("|", "\\|").replace("\n", " ")


def _split_row(line):
    cells, cur, i = [], "", 0
    line = line.strip()
    if line.startswith("|"):
        line = line[1:]
    if line.endswith("|") and not line.endswith("\\|"):
        line = line[:-1]
    while i < len(line):
        ch = line[i]
        if ch == "\\" and i + 1 < len(line):
            cur += line[i + 1]
            i += 2
            continue
        if ch == "|":
            cells.append(cur.strip())
            cur = ""
        else:
            cur += ch
        i += 1
    cells.append(cur.strip())
    return cells


class FileBoard(Base):
    """A BOARD.md table in the project, for a project with no online tool. One row per card; a card's description
    (it may be a whole document) sits beside it in `.board/<n>.md`, so the table stays readable on any viewer."""

    def __init__(self, place):
        self.dir = place
        self.table = os.path.join(place, "BOARD.md")
        self.cards_dir = os.path.join(place, ".board")

    # storage
    def _read(self):
        rows = []
        try:
            lines = open(self.table, encoding="utf-8").read().splitlines()
        except OSError:
            return rows
        for ln in lines:
            if not ln.startswith("|") or re.match(r"^\|\s*-", ln) or ln.startswith("| #"):
                continue
            c = _split_row(ln)
            c += [""] * (len(FILE_COLS) - len(c))
            n = int(c[0]) if c[0].isdigit() else None
            if n is None:
                continue
            try:
                desc = open(os.path.join(self.cards_dir, f"{n}.md"), encoding="utf-8").read()
            except OSError:
                desc = ""
            rel = [tuple(x.split(":", 1)) for x in c[9].split() if ":" in x]
            links = [(m.group(1), m.group(2)) for m in re.finditer(r"\[([^\]]*)\]\(([^)]*)\)", c[10])]
            rows.append({"card": n, "title": c[1], "group": c[2], "labels": [x for x in c[3].split(",") if x],
                         "parent": c[4] or None, "assignees": [x for x in c[5].split(",") if x], "start": c[6],
                         "done": c[7], "priority": c[8] or "none", "relations": rel, "links": links,
                         "description": desc})
        return rows

    def _write(self, rows):
        os.makedirs(self.cards_dir, exist_ok=True)
        out = ["# Board", "", "<!-- kept by the board contract: one row per card; descriptions live in .board/ -->", "",
               "| " + " | ".join(FILE_COLS) + " |", "|" + "---|" * len(FILE_COLS)]
        for r in sorted(rows, key=lambda r: r["card"]):
            out.append("| " + " | ".join([
                str(r["card"]), _esc(r["title"]), r["group"] or "", _esc(",".join(r["labels"])), str(r["parent"] or ""),
                _esc(",".join(r["assignees"])), r["start"] or "", r["done"] or "", r["priority"] or "none",
                " ".join(f"{a}:{b}" for a, b in r["relations"]),
                _esc(" ".join(f"[{t}]({u})" for t, u in r["links"]))]) + " |")
            with open(os.path.join(self.cards_dir, f"{r['card']}.md"), "w", encoding="utf-8") as f:
                f.write(r["description"] or "")
        with open(self.table, "w", encoding="utf-8") as f:
            f.write("\n".join(out) + "\n")

    def _cards(self):
        return self._read()

    def _labels(self):
        return {x for r in self._read() for x in r["labels"]}

    def _new_label(self, name):
        pass  # a label is a word in a row; it exists when a card carries it

    def _make(self, rec):
        rows = self._read()
        n = max([r["card"] for r in rows] or [0]) + 1
        rows.append({**rec, "card": n, "relations": [], "links": []})
        self._write(rows)
        return n

    def _patch(self, card, **f):
        rows = self._read()
        for r in rows:
            if str(r["card"]) == str(card):
                r.update({k: v for k, v in f.items()})
                self._write(rows)
                return
        raise AdapterRefusal(f"no card {card} on this board")

    def _rel_get(self, card):
        return next((r["relations"] for r in self._read() if str(r["card"]) == str(card)), [])

    def _rel_add(self, card, relation, other):
        rows = self._read()
        for r in rows:
            if str(r["card"]) == str(card) and (relation, str(other)) not in r["relations"]:
                r["relations"].append((relation, str(other)))
        self._write(rows)

    def _links_of(self, card):
        return [{"title": t, "url": u} for t, u in
                next((r["links"] for r in self._read() if str(r["card"]) == str(card)), [])]

    def _link_add(self, card, url, title):
        rows = self._read()
        for r in rows:
            if str(r["card"]) == str(card) and (title, url) not in r["links"]:
                r["links"].append((title, url))
        self._write(rows)


# ── GitHub Projects v2, through gh ────────────────────────────────────────────────────────────

def gh_run(args, stdin=None):
    p = subprocess.run(["gh", *args], input=stdin, capture_output=True, text=True, timeout=120)
    if p.returncode:
        raise AdapterRefusal(f"gh {' '.join(args[:3])} failed: {p.stderr.strip()[:200]}")
    out = p.stdout.strip()
    try:
        return json.loads(out) if out[:1] in "[{" else out
    except ValueError:
        return out


class GithubBoard(Base):
    """GitHub Projects v2: each card is an issue in `repo`, added to project number `project` of `owner`. The state is
    the project's `Status` field; Start, Done and Priority are the project's own fields when it has them. Relations and
    links are issue comments (`[relation] blocked_by #N`, `[link] title url`) — GitHub's typed relations are not used."""

    def __init__(self, repo, owner, project, run=gh_run):
        self.repo, self.owner, self.project, self.run = repo, owner, str(project), run
        self._fields = None

    def _field(self, name):
        if self._fields is None:
            got = self.run(["project", "field-list", self.project, "--owner", self.owner, "--format", "json"])
            self._fields = {f["name"].lower(): f for f in (got or {}).get("fields", [])}
        return self._fields.get(name.lower())

    def _status_option(self, group):
        f = self._field("status") or {}
        opts = {o["name"]: o["id"] for o in f.get("options", [])}
        name = name_for_group(list(opts), group)
        if not name:
            raise AdapterRefusal(f"the project has no Status option for the group '{group}'")
        return f["id"], opts[name]

    def _items(self):
        got = self.run(["project", "item-list", self.project, "--owner", self.owner, "--format", "json", "-L", "1000"])
        return (got or {}).get("items", [])

    def _cards(self):
        out = []
        for it in self._items():
            c = it.get("content") or {}
            if c.get("type") != "Issue" or not c.get("repository", self.repo).endswith(self.repo.split("/")[-1]):
                continue
            out.append({"card": c["number"], "title": it.get("title", ""), "group": group_of_name(it.get("status")),
                        "labels": it.get("labels") or [], "description": c.get("body") or "", "item": it["id"],
                        "start": it.get("start") or it.get("start date") or "", "done": it.get("done") or "",
                        "priority": (it.get("priority") or "none").lower(), "assignees": it.get("assignees") or [],
                        "parent": it.get("parent issue")})
        return out

    def _item(self, card):
        for r in self._cards():
            if str(r["card"]) == str(card):
                return r["item"]
        raise AdapterRefusal(f"issue {card} is not on project {self.project}")

    def _set(self, item, name, value, kind):
        f = self._field(name)
        if not f or value in (None, ""):
            return
        a = ["project", "item-edit", "--id", item, "--project-id", self._project_id(), "--field-id", f["id"]]
        if kind == "date":
            a += ["--date", value]
        elif kind == "select":
            opt = next((o["id"] for o in f.get("options", []) if o["name"].lower() == str(value).lower()), None)
            if not opt:
                return
            a += ["--single-select-option-id", opt]
        self.run(a)

    def _project_id(self):
        got = self.run(["project", "view", self.project, "--owner", self.owner, "--format", "json"])
        return got["id"]

    def _labels(self):
        return {x["name"] for x in self.run(["label", "list", "-R", self.repo, "--json", "name", "-L", "500"])}

    def _new_label(self, name):
        self.run(["label", "create", name, "-R", self.repo, "--color", "9a8f75", "--force"])

    def _make(self, rec):
        a = ["issue", "create", "-R", self.repo, "-t", rec["title"], "-b", rec["description"] or ""]
        for l in rec["labels"]:
            a += ["-l", l]
        url = self.run(a).splitlines()[-1]
        n = int(url.rstrip("/").split("/")[-1])
        added = self.run(["project", "item-add", self.project, "--owner", self.owner, "--url", url, "--format", "json"])
        item = added["id"]
        self._apply(item, n, rec)
        return n

    def _apply(self, item, n, f):
        if f.get("group"):
            fid, oid = self._status_option(f["group"])
            self.run(["project", "item-edit", "--id", item, "--project-id", self._project_id(), "--field-id", fid,
                      "--single-select-option-id", oid])
            if f["group"] in ("done", "cancelled"):
                self.run(["issue", "close", str(n), "-R", self.repo, "--reason",
                          "completed" if f["group"] == "done" else "not planned"])
        self._set(item, "start", f.get("start"), "date")
        self._set(item, "done", f.get("done"), "date")
        if f.get("priority") not in (None, "", "none"):
            self._set(item, "priority", f["priority"], "select")

    def _patch(self, card, **f):
        item = self._item(card)
        a = ["issue", "edit", str(card), "-R", self.repo]
        if f.get("title"):
            a += ["-t", f["title"]]
        if f.get("description"):
            a += ["-b", f["description"]]
        for l in f.get("labels") or []:
            a += ["--add-label", l]
        if len(a) > 5:
            self.run(a)
        if f.get("group") and f["group"] not in ("done", "cancelled"):
            try:  # a card moved out of done is open again; an issue already open answers with an error we ignore
                self.run(["issue", "reopen", str(card), "-R", self.repo])
            except AdapterRefusal:
                pass
        self._apply(item, card, f)

    def _comment(self, card, text):
        self.run(["issue", "comment", str(card), "-R", self.repo, "-b", text])

    def _comments(self, card):
        got = self.run(["issue", "view", str(card), "-R", self.repo, "--json", "comments"])
        return [c.get("body", "") for c in (got or {}).get("comments", [])]

    def _rel_get(self, card):
        out = []
        for b in self._comments(card):
            m = re.match(r"\[relation\] (\w+) #(\d+)", b)
            if m:
                out.append((m.group(1), m.group(2)))
        return out

    def _rel_add(self, card, relation, other):
        if (relation, str(other)) not in self._rel_get(card):
            self._comment(card, f"[relation] {relation} #{other}")

    def _links_of(self, card):
        out = []
        for b in self._comments(card):
            m = re.match(r"\[link\] (.*?) (\S+)$", b)
            if m:
                out.append({"title": m.group(1), "url": m.group(2)})
        return out

    def _link_add(self, card, url, title):
        if not any(l["url"] == url for l in self._links_of(card)):
            self._comment(card, f"[link] {title} {url}")

    def _closed(self, card, day):
        self._comment(card, f"closed {day}")


# ── Trello, through the house's own REST door (cardlib.Trello) ────────────────────────────────

class TrelloBoard(Base):
    """Trello: `place` is a board id. A group is a list named for it (GROUP_WORDS); labels, a start date, a due date
    carrying the DONE date (with `dueComplete` set — Trello's completed field), members and priority (a `priority:`
    label). Relations and the parent are attachments named `relation:<kind>` / `parent`, because Trello has none."""

    def __init__(self, board_id, http=None, headers=None, base=None, people=None):
        if http is None:
            import cardlib  # the house's one credential loader and REST client
            t = cardlib.Trello()
            http, headers, base = cardlib._http, t.h, t.base
        self.b, self.http, self.h, self.base, self.people = board_id, http, headers or {}, base, people or {}
        self._idmap = {}

    def _get(self, path):
        return self.http("GET", f"{self.base}{path}", self.h)

    def _lists(self):
        return self._get(f"/boards/{self.b}/lists?fields=name")

    def _list_for(self, group):
        ls = self._lists()
        name = name_for_group([l["name"] for l in ls], group)
        if not name:
            raise AdapterRefusal(f"the Trello board has no list for the group '{group}'")
        return next(l["id"] for l in ls if l["name"] == name)

    def _cards(self):
        lists = {l["id"]: group_of_name(l["name"]) for l in self._lists()}
        out = []
        for c in self._get(f"/boards/{self.b}/cards?fields=name,desc,idList,idShort,due,start,dueComplete,idLabels,"
                           "idMembers&attachments=true&labels=true"):
            self._idmap[c["idShort"]] = c["id"]
            labels = [l["name"] for l in c.get("labels", [])]
            prio = next((l.split(":", 1)[1] for l in labels if l.startswith("priority:")), "none")
            parent = next((a["name"].split(":", 1)[1] for a in c.get("attachments", [])
                           if a.get("name", "").startswith("parent:")), None)
            out.append({"card": c["idShort"], "title": c["name"], "group": lists.get(c["idList"]),
                        "labels": [l for l in labels if not l.startswith("priority:")], "description": c.get("desc", ""),
                        "start": (c.get("start") or "")[:10],
                        "done": (c.get("due") or "")[:10] if c.get("dueComplete") else "", "priority": prio,
                        "parent": parent, "assignees": c.get("idMembers") or []})
        return out

    def _id(self, card):
        if card not in self._idmap:
            self._cards()
        return self._idmap[card] if card in self._idmap else self._idmap[int(card)]

    def _labels(self):
        return {l["name"] for l in self._get(f"/boards/{self.b}/labels?fields=name&limit=1000")}

    def _label_id(self, name):
        for l in self._get(f"/boards/{self.b}/labels?fields=name&limit=1000"):
            if l["name"] == name:
                return l["id"]
        return self.http("POST", f"{self.base}/labels", self.h, {"name": name, "color": "sky", "idBoard": self.b})["id"]

    def _new_label(self, name):
        self._label_id(name)

    def _members(self, who):
        ms = self._get(f"/boards/{self.b}/members?fields=username,fullName")
        ids = []
        for w in who or []:
            login = str(self.people.get(w, w)).lower()
            hit = next((m for m in ms if login in (m.get("username", "").lower(), m.get("fullName", "").lower())), None)
            if hit:
                ids.append(hit["id"])
        return ids

    def _body(self, f):
        b = {}
        if f.get("title"):
            b["name"] = f["title"]
        if f.get("description") is not None and "description" in f:
            b["desc"] = f["description"]
        if f.get("group"):
            b["idList"] = self._list_for(f["group"])
        if f.get("start"):
            b["start"] = f["start"] + "T09:00:00.000Z"
        if f.get("done"):
            b["due"] = f["done"] + "T09:00:00.000Z"
            b["dueComplete"] = True
        labels = list(f.get("labels") or [])
        if f.get("priority") not in (None, "", "none"):
            labels.append("priority:" + f["priority"])
        if labels:
            b["idLabels"] = ",".join(self._label_id(l) for l in labels)
        if f.get("assignees"):
            b["idMembers"] = ",".join(self._members(f["assignees"]))
        return b

    def _make(self, rec):
        body = self._body({**rec, "description": rec["description"]})
        body.setdefault("idList", self._list_for(rec["group"] or "unstarted"))
        made = self.http("POST", f"{self.base}/cards", self.h, body)
        self._idmap[made["idShort"]] = made["id"]
        if rec.get("parent"):
            self._attach(made["id"], f"parent:{rec['parent']}", made.get("shortUrl") or "https://trello.com")
        return made["idShort"]

    def _patch(self, card, **f):
        body = self._body(f)
        if body:
            self.http("PUT", f"{self.base}/cards/{self._id(card)}", self.h, body)

    def _attach(self, cid, name, url):
        self.http("POST", f"{self.base}/cards/{cid}/attachments", self.h, {"name": name, "url": url})

    def _attachments(self, card):
        return self._get(f"/cards/{self._id(card)}/attachments?fields=name,url")

    def _rel_get(self, card):
        return [tuple(a["name"][9:].split(":", 1)) for a in self._attachments(card) if a["name"].startswith("relation:")]

    def _rel_add(self, card, relation, other):
        tag = f"relation:{relation}:{other}"
        if not any(a["name"] == tag for a in self._attachments(card)):
            self._attach(self._id(card), tag, self._get(f"/cards/{self._id(other)}?fields=shortUrl")["shortUrl"])

    def _links_of(self, card):
        return [{"title": a["name"], "url": a["url"]} for a in self._attachments(card)
                if not a["name"].startswith(("relation:", "parent:"))]

    def _link_add(self, card, url, title):
        if not any(a["url"] == url for a in self._attachments(card)):
            self._attach(self._id(card), title, url)

    def _closed(self, card, day):
        self.http("POST", f"{self.base}/cards/{self._id(card)}/actions/comments", self.h, {"text": f"closed {day}"})


# ── the choice ───────────────────────────────────────────────────────────────────────────────

def make_board(board, repo_root, home):
    """The adapter the registry row's `board:` block names, or a refusal that says what is missing."""
    kind = board.get("adapter")
    if kind == "file":
        place = board.get("place") or "."
        place = place if os.path.isabs(place) else os.path.join(repo_root or home, place)
        return place, FileBoard(place)
    if kind == "github":
        g = board.get("github") or {}
        repo, project = board.get("place"), g.get("project")
        if not repo or not project:
            raise AdapterRefusal("a github board needs board.place (owner/repo) and board.github.project (a number)")
        return repo, GithubBoard(repo, g.get("owner") or repo.split("/")[0], project)
    if kind == "trello":
        if not board.get("place"):
            raise AdapterRefusal("a trello board needs board.place (the Trello board id)")
        return board["place"], TrelloBoard(board["place"], people=board.get("people") or {})
    raise AdapterRefusal(f"board.adapter '{kind}' is not one of mcp, file, github, trello")
