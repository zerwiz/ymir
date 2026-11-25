#!/usr/bin/env python3
"""board_sync.py — mirror the headers of plans, tickets and documents onto Plane cards. One way: files -> board.

  python3 scripts/board_sync.py                 # dry run: print what would be created or changed
  python3 scripts/board_sync.py --apply         # write it
  python3 scripts/board_sync.py --only plans    # plans | tickets | docs (documents are never synced unless asked)
  python3 scripts/board_sync.py --json          # machine-readable result

Reads the header of every plan (`plans/**/*.md`) and ticket (`plans/tickets/*.md`), and a document
(`docs/**/*.md`, except `docs/fixes/` and `docs/kit/`) only with `--only docs`, using the reader `status.py` already uses, and upserts one Plane card per file.
A card is found by its `external_id` (the file's path) and `external_source` (`repo-header`), never by title, so a
renamed title updates the card and does not duplicate it.

What it writes: name, state, priority, assignees (added, never removed, unless `"assignees": "replace"`), labels, start and target dates, the parent card (a ticket's
plan), and a small block at the top of the description with `created`, `updated`, `product`, `legacy_id`, the
source path and the links. Text a person writes below the block's closing marker is kept.

What it never does: delete or move a card, change a card's project, write anything back to a file, or hold a
secret. The token is read from the environment variable the config names, never from the repository.

Configuration — `plans/.board.json` (see `plans/.board.json.example`). Nothing here needs a library.
"""
import argparse
import html
import re
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import status as hdr  # noqa: E402  (the one header reader)

ROOT = hdr.ROOT
SOURCE = "repo-header"
OPEN, CLOSE = "<!--repo-header-->", "<!--/repo-header-->"
DEFAULT_STATES = {"Proposed": "Backlog", "In Review": "Todo", "Validated": "Todo", "In Progress": "In Progress",
                  "Done": "Done", "Rejected": "Cancelled", "Superseded": "Cancelled", "Backlog": "Backlog",
                  "Open": "Todo", "Accepted": "Todo", "Built": "Done", "Blocked": "In Progress", "Cancelled": "Cancelled",
                  "draft": "Backlog", "review": "Todo", "accepted": "Done", "superseded": "Cancelled",
                  "record": "Done"}
DEFAULT_PRIORITIES = {"Critical": "urgent", "High": "high", "Medium": "medium", "Low": "low"}
PAUSE = 0.7  # seconds between writes: the board rate-limits


def die(msg):
    print("board_sync: " + msg, file=sys.stderr)
    sys.exit(2)


def load_config():
    p = ROOT / "plans" / ".board.json"
    if not p.is_file():
        die("no plans/.board.json (copy plans/.board.json.example and fill it in)")
    cfg = json.loads(p.read_text(encoding="utf-8"))
    for k in ("url", "workspace", "products"):
        if not cfg.get(k):
            die(f"plans/.board.json has no `{k}`")
    cfg.setdefault("token_env", "PLANE_API_TOKEN")
    cfg.setdefault("default_product", next(iter(cfg["products"])))
    cfg["states"] = {**DEFAULT_STATES, **cfg.get("states", {})}
    cfg["priorities"] = {**DEFAULT_PRIORITIES, **cfg.get("priorities", {})}
    return cfg


class Plane:
    def __init__(self, cfg):
        token = os.environ.get(cfg["token_env"], "")
        if not token:
            die(f"environment variable {cfg['token_env']} is empty (the token lives in the vault, not here)")
        self.base = f"{cfg['url'].rstrip('/')}/api/v1/workspaces/{cfg['workspace']}"
        self.token = token

    def call(self, method, path, body=None):
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(self.base + path, data=data, method=method,
                                     headers={"X-API-Key": self.token, "Content-Type": "application/json",
                                              "User-Agent": "board-sync/1.0"})  # a bare Python agent is refused by CDNs
        for attempt in range(4):
            try:
                with urllib.request.urlopen(req, timeout=30) as r:
                    return json.load(r)
            except urllib.error.HTTPError as e:
                if e.code == 429 and attempt < 3:
                    time.sleep(5 * (attempt + 1))
                    continue
                raise

    def pages(self, path):
        out, cursor = [], None
        while True:
            sep = "&" if "?" in path else "?"
            d = self.call("GET", f"{path}{sep}per_page=100" + (f"&cursor={cursor}" if cursor else ""))
            if isinstance(d, list):
                return d
            out += d.get("results", [])
            if not d.get("next_page_results"):
                return out
            cursor = d["next_cursor"]


def split_list(value):
    return [x.strip() for x in (value or "").replace(";", ",").split(",") if x.strip()]


def scan(only):
    """Yield (kind, relpath, meta, body) for every file with a header."""
    groups = []
    if only in (None, "plans"):
        groups.append(("plan", [p for p in sorted((ROOT / "plans").rglob("*.md"))
                                if "tickets" not in p.relative_to(ROOT / "plans").parts
                                and p.name not in ("README.md", "TEMPLATE.md")] if (ROOT / "plans").is_dir() else []))
    if only in (None, "tickets"):
        shelf = ROOT / "plans" / "tickets"
        groups.append(("ticket", [p for p in sorted(shelf.glob("*.md")) if p.name not in ("README.md", "TEMPLATE.md")]
                       if shelf.is_dir() else []))
    if only == "docs":  # documents are cards only when asked for; the document tool mirrors them otherwise
        groups.append(("doc", [p for p in sorted((ROOT / "docs").rglob("*.md"))
                               if not any(s in p.relative_to(ROOT).as_posix() + "/" for s in hdr.SKIP_DOCS)
                               ] if (ROOT / "docs").is_dir() else []))
    for kind, files in groups:
        for p in files:
            text = p.read_text(encoding="utf-8")
            meta = hdr.front_matter(text)
            if meta and meta.get("title"):
                yield kind, p.relative_to(ROOT).as_posix(), meta, text


def card_id(meta, rel=""):
    """The header's id; else the `PREFIX-NNN` the file name starts with."""
    m = re.match(r"([A-Za-z][A-Za-z0-9]*-\d+[a-z]?(?:-T\d+)?)(?=-|\.)", Path(rel).name)
    return meta.get("id") or meta.get("ticket") or (m.group(1) if m else "") or meta.get("ticket_number") or ""


def base_status(value):
    """`Accepted — first slice built` -> `Accepted`: only the word before a dash names the state."""
    return re.split(r"\s+[—–-]\s+", (value or "").strip(), maxsplit=1)[0].strip()


def state_for(states, value):
    """Case-blind; `In progress` and `Built on fixtures` fall back to their first words."""
    low = {k.lower(): v for k, v in states.items()}
    words = base_status(value).lower().split()
    for n in range(len(words), 0, -1):
        if " ".join(words[:n]) in low:
            return low[" ".join(words[:n])]
    return None


def who_is(name, members, people):
    """An owner may be an email, a configured alias, a display name, `First Last` or a first name."""
    key = name.strip().strip("|").strip().lower()
    key = (people.get(key) or people.get(name.strip()) or key).lower()
    return members.get(key)


def description_block(kind, rel, meta):
    rows = [("Created", meta.get("created")), ("Updated", meta.get("updated")), ("Product", meta.get("product")),
            ("Was", meta.get("legacy_id")), ("Reviewer", meta.get("reviewer")), ("Source", rel),
            ("Links", meta.get("links"))]
    cells = "".join(f"<li><strong>{k}:</strong> {html.escape(v)}</li>" for k, v in rows if v)
    return f"{OPEN}<ul>{cells}</ul>{CLOSE}"


def merge_description(existing, block):
    existing = existing or ""
    if OPEN in existing and CLOSE in existing:
        return block + existing.split(CLOSE, 1)[1]
    return block + existing


def project_for(cfg, meta):
    product = (meta.get("product") or cfg["default_product"]).strip().lower()
    ident = cfg["products"].get(product)
    return product, ident


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--only", choices=["plans", "tickets", "docs"])
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    cfg = load_config()
    plane = Plane(cfg)

    members = {}
    for m in plane.pages("/members/"):
        mm = m.get("member") if isinstance(m.get("member"), dict) else m
        if mm.get("email"):
            members[mm["email"].lower()] = mm.get("id")
            full = f"{mm.get('first_name', '')} {mm.get('last_name', '')}".strip().lower()
            for alias in (full, (mm.get("display_name") or "").lower(), (mm.get("first_name") or "").lower()):
                if alias and alias not in members:
                    members[alias] = mm.get("id")
    projects = {p["identifier"]: p for p in plane.pages("/projects/")}
    cache = {}

    def project_data(ident):
        if ident not in cache:
            pid = projects[ident]["id"]
            cache[ident] = {
                "id": pid,
                "states": {s["name"]: s["id"] for s in plane.pages(f"/projects/{pid}/states/")},
                "labels": {l["name"].lower(): l["id"] for l in plane.pages(f"/projects/{pid}/labels/")},
                "issues": {i.get("external_id"): i for i in plane.pages(f"/projects/{pid}/issues/")
                           if i.get("external_source") == SOURCE},
                "by_card": {},
            }
            cache[ident]["unclaimed"] = [i for i in plane.pages(f"/projects/{pid}/issues/")
                                         if i.get("external_source") != SOURCE]
        return cache[ident]

    result, warnings = [], []
    items = list(scan(a.only))
    items.sort(key=lambda t: 0 if t[0] == "plan" else 1)  # plans first, so a ticket can find its parent
    for kind, rel, meta, _text in items:
        product, ident = project_for(cfg, meta)
        if ident not in projects:
            warnings.append(f"{rel}: product `{product}` maps to no Plane project ({ident})")
            continue
        pd = project_data(ident)
        cid = card_id(meta, rel)
        name = meta["title"] if (not cid or cid in meta["title"]) else f"{cid} — {meta['title']}"

        state_name = state_for(cfg["states"], meta.get("status"))
        state = pd["states"].get(state_name) if state_name else None
        if meta.get("status") and not state:
            warnings.append(f"{rel}: status `{meta.get('status')}` maps to no state")
        want = {"name": name}
        if state:
            want["state"] = state
        prio = cfg["priorities"].get(meta.get("priority", ""))
        if prio:
            want["priority"] = prio
        who = split_list(meta.get("owner") or meta.get("assignee")) + split_list(meta.get("co_owners"))
        ids = []
        for e in who:
            uid = who_is(e, members, cfg.get("people", {}))
            if uid:
                ids.append(uid)
            elif e.strip("| "):
                warnings.append(f"{rel}: {e} is not a member of the workspace")
        if ids:
            want["assignees"] = sorted(set(ids))
        if meta.get("start"):
            want["start_date"] = meta["start"]
        if meta.get("due"):
            want["target_date"] = meta["due"]
        label_ids, new_labels = [], []
        for lab in split_list(meta.get("labels")) + [x for x in (meta.get("type"),) if x]:
            lid = pd["labels"].get(lab.lower())
            (label_ids.append(lid) if lid else new_labels.append(lab))
        parent = meta.get("parent")
        if parent and pd["by_card"].get(parent):
            want["parent"] = pd["by_card"][parent]
        block = description_block(kind, rel, meta)

        card = pd["issues"].get(rel)
        adopt = False
        wanted = (cfg.get("adopt") or {}).get(rel)  # a file named in the config is matched to that card, e.g. "ALPHA-12"
        if not card and wanted:
            for other in pd["unclaimed"]:
                if f"{ident}-{other['sequence_id']}" == wanted:
                    card, adopt = other, True
                    pd["unclaimed"].remove(other)
                    break
            else:
                warnings.append(f"{rel}: adopt target {wanted} not found or already claimed")
        if not card and cid:  # a card made before this tool existed: adopt it by its id, never duplicate it
            for other in pd["unclaimed"]:
                n = (other.get("name") or "").strip()
                if n == cid or n.startswith((cid + " ", cid + ":", cid + " —", cid + " -")):
                    card, adopt = other, True
                    pd["unclaimed"].remove(other)
                    break
        action = "create" if not card else "update"
        diff = {}
        if card:
            if adopt:
                diff["external_id"], diff["external_source"] = rel, SOURCE
            for k, v in want.items():
                cur = card.get(k)
                if k == "assignees":
                    cur = sorted(card.get("assignees") or [])
                    if cfg.get("assignees", "add") != "replace":  # default: add the header's owners, never remove anyone
                        v = sorted(set(cur) | set(v))
                if cur != v:
                    diff[k] = v
            if sorted(card.get("labels") or []) != sorted(label_ids) and not new_labels:
                diff["labels"] = label_ids
            desc = merge_description(card.get("description_html"), block)
            if desc != (card.get("description_html") or ""):
                diff["description_html"] = desc
            if not diff:
                action = "same"
        row = {"file": rel, "kind": kind, "card": f"{ident}-{card['sequence_id']}" if card else "(new)",
               "action": action, "fields": sorted(diff) if card else sorted(want)}
        result.append(row)

        if a.apply and action != "same":
            for lab in new_labels:
                lid = plane.call("POST", f"/projects/{pd['id']}/labels/", {"name": lab})["id"]
                pd["labels"][lab.lower()] = lid
                label_ids.append(lid)
                time.sleep(PAUSE)
            if action == "create":
                body = {**want, "labels": label_ids, "description_html": block,
                        "external_id": rel, "external_source": SOURCE}
                card = plane.call("POST", f"/projects/{pd['id']}/issues/", body)
                pd["issues"][rel] = card
            else:
                if new_labels:
                    diff["labels"] = sorted(label_ids)
                card = plane.call("PATCH", f"/projects/{pd['id']}/issues/{card['id']}/", diff)
            time.sleep(PAUSE)
        if cid and card:
            pd["by_card"][cid] = card["id"]

    if a.json:
        print(json.dumps({"applied": a.apply, "rows": result, "warnings": warnings}, indent=1))
    else:
        for r in result:
            print(f"{r['action']:7} {r['card']:12} {r['file']}  {','.join(r['fields']) if r['action'] != 'same' else ''}")
        for w in warnings:
            print("warning: " + w)
        n = {k: sum(1 for r in result if r["action"] == k) for k in ("create", "update", "same")}
        print(f"{'applied' if a.apply else 'dry run'}: {n['create']} to create, {n['update']} to update, {n['same']} unchanged, {len(warnings)} warnings")
    return 0


if __name__ == "__main__":
    sys.exit(main())
