#!/usr/bin/env python3
"""project.py — the projector: a meeting's record becomes the desk's data, and (optionally) cards.

    project.py [--home $YMIR_HOME] [--out DIR] [--plane] [--dry-run]

Reads every meeting under `hodd/life/meetings/<workspace>/<id>/` — `meeting.json` for the title and the
classification, `by-house.md` for decisions, questions and actions with their evidence — and writes:

    <out>/meetings.json   what the desk renders
    <out>/places.json     who may see which place (only if it does not exist; never overwritten)

With `--plane` it also creates a card per action in the plane project named by `--plane-project`, using
`PLANE_API` and `PLANE_TOKEN` from the environment, **idempotently by title**. It never writes class 3
material anywhere: a meeting whose `classification` says `restricted` is skipped entirely.
"""
from __future__ import annotations

import argparse
import datetime
import json
import os
import re
import sys
import urllib.error
import urllib.request


def rows(block: str):
    out = []
    for line in (block or "").splitlines():
        s = line.strip()
        if s.startswith("|") and "---" not in s and not re.match(r"^\|\s*#", s):
            cells = [c.strip() for c in s.strip("|").split("|")]
            if cells and re.match(r"^[A-Za-z]?\d+$", cells[0]):
                out.append(cells)
    return out


def read_meeting(path: str) -> dict | None:
    meta = {}
    try:
        meta = json.load(open(os.path.join(path, "meeting.json"), encoding="utf-8"))
    except Exception:
        pass
    klass = str(meta.get("classification", "internal")).lower()
    if klass in ("restricted", "confidential"):
        return None                      # class 3 and class 2-with-NDA never project
    house = os.path.join(path, "by-house.md")
    decisions, questions, actions = [], [], []
    if os.path.isfile(house):
        text = open(house, encoding="utf-8").read()
        dec = re.search(r"## Decisions taken in the room(.*?)## Open questions", text, re.S)
        qs = re.search(r"## Open questions(.*?)## Actions", text, re.S)
        ac = re.search(r"## Actions(.*?)\n---", text, re.S)
        decisions = [{"text": r[1], "evidence": r[2] if len(r) > 2 else ""} for r in rows(dec.group(1) if dec else "")]
        questions = [{"text": r[1], "owner": r[2], "evidence": r[3] if len(r) > 3 else ""} for r in rows(qs.group(1) if qs else "")]
        actions = [{"text": r[1], "owner": r[2], "due": r[3], "evidence": r[4] if len(r) > 4 else ""}
                   for r in rows(ac.group(1) if ac else "")]
    return {"id": os.path.basename(path), "title": meta.get("title", ""),
            "started_at": meta.get("started_at", ""), "class": klass,
            "decisions": decisions, "questions": questions, "actions": actions}


def plane_card(api: str, token: str, project: str, card: dict, dry: bool) -> str:
    def call(method, path, body=None):
        req = urllib.request.Request(api.rstrip("/") + path, method=method,
                                     headers={"X-Api-Key": token, "Content-Type": "application/json"},
                                     data=json.dumps(body).encode() if body is not None else None)
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.read().decode()
            return r.status, (json.loads(raw) if raw else {})
    desc = (f"<p><b>Owner:</b> {card.get('owner','')}<br><b>Due:</b> {card.get('due','')}<br>"
            f"<b>Evidence:</b> {card.get('evidence','')}<br><b>Source:</b> {card.get('source','')}</p>")
    if dry:
        return f"would create: {card['title'][:50]}"
    try:
        st, existing = call("GET", f"/api/v1/workspaces/{card['ws']}/projects/{project}/issues/")
        titles = {i["name"] for i in (existing.get("results") or [])}
        if card["title"] in titles:
            return f"present: {card['title'][:50]}"
        st, res = call("POST", f"/api/v1/workspaces/{card['ws']}/projects/{project}/issues/",
                       {"name": card["title"], "description_html": desc})
        return f"{st}: {card['title'][:50]}"
    except urllib.error.HTTPError as exc:
        return f"! {exc.code}: {exc.read().decode()[:80]}"


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--home", default=os.environ.get("YMIR_HOME", ""))
    ap.add_argument("--out", default="/srv/gimle-desk")
    ap.add_argument("--workspace", default="work")
    ap.add_argument("--plane", action="store_true")
    ap.add_argument("--plane-project", default="")
    ap.add_argument("--plane-workspace", default="whynotproductions")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args(argv)
    if not args.home or not os.path.isdir(args.home):
        print("project: YMIR_HOME is unresolved — nothing is guessed", file=sys.stderr)
        return 1
    root = os.path.join(args.home, "hodd", "life", "meetings", args.workspace)
    meetings, skipped = [], []
    if os.path.isdir(root):
        for name in sorted(os.listdir(root)):
            path = os.path.join(root, name)
            if not os.path.isdir(path):
                continue
            m = read_meeting(path)
            if m is None:
                skipped.append(name)
                continue
            meetings.append(m)
    payload = {"generated": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
               "meetings": meetings}
    os.makedirs(args.out, exist_ok=True)
    with open(os.path.join(args.out, "meetings.json"), "w", encoding="utf-8") as fh:
        json.dump(payload, fh, indent=1, ensure_ascii=False)
    places = os.path.join(args.out, "places.json")
    if not os.path.exists(places):
        with open(places, "w", encoding="utf-8") as fh:
            json.dump({}, fh, indent=1)   # empty map = nobody but the operator sees anything
        note = "places.json created empty (fail-closed)"
    else:
        note = "places.json left untouched"
    print(f"projected\t{len(meetings)} meeting(s)\tskipped {len(skipped)} (class 3)\t{note}")
    if args.plane:
        api, token = os.environ.get("PLANE_API", "http://127.0.0.1:8099"), os.environ.get("PLANE_TOKEN", "")
        if not token:
            print("project: --plane needs PLANE_TOKEN; cards skipped", file=sys.stderr)
            return 1
        if not args.plane_project:
            print("project: --plane needs --plane-project <name-or-id>", file=sys.stderr)
            return 1
        for m in meetings:
            for a in m["actions"]:
                card = {"title": a["text"][:180], "owner": a.get("owner", ""), "due": a.get("due", ""),
                        "evidence": a.get("evidence", ""), "source": f"meeting:{m['id']}",
                        "ws": args.plane_workspace}
                print("card\t" + plane_card(api, token, args.plane_project, card, args.dry_run))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
