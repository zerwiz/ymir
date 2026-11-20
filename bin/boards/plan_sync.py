#!/usr/bin/env python3
"""plan_sync.py — mirror a project's plan ledger onto its board, one card per plan (plan 335, phase 3).

The door is `bin/boards/plan-sync.sh`; this file is its logic. Standard library only, plus PyYAML for the registry.

What it does, and refuses to do:
  * reads the project's row in `$YMIR_HOME/hodd/identity/projects.yaml` — the `board:` block names the
    adapter, the place and the road (nothing about an installation is written here, RULES/07);
  * reads the project's plan ledger in the home and its README index;
  * makes ONE card per plan: title `NNN · <plan title>`, label `plan`, the state GROUP from the ledger's status,
    and a description that holds only the plan's number, its home-relative path and its status word —
    never the plan's own text;
  * is idempotent: a second run changes nothing. A card is found by its number and title, never created twice;
  * touches only cards that carry the `plan` label and the `NNN · ` title shape, and never deletes one;
  * leaves a card the board moved by hand where it stands, until the ledger's status itself changes.

It speaks the board CONTRACT only (plan 335, "the split"): state groups — backlog · unstarted · started · review ·
done · cancelled — never one engine's state names. The adapter named in the registry turns a group into the board's
own state; today the generic `mcp` adapter (bin/boards/board_adapter_mcp.py) is the one that exists.

The `board:` block (in the project's registry row):

    board:
      adapter: mcp
      place: <the board's address for this project>
      mcp:
        url: https://…/mcp
        token_from: claude-mcp:<server> | env:<NAME> | vault:<NAME>    # a REFERENCE, never a value
      plans: <home-relative ledger path>    # optional; default records.in_home.plans, then the realm layout

Exit: 0 ok · 1 refused or a call failed · 2 usage.
"""
import argparse
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from board_adapter_mcp import BoardRefusal, McpBoard, resolve_token  # noqa: E402

LABEL = "plan"
TITLE_RE = re.compile(r"^(\d+) · (.*)$")


class Refusal(BoardRefusal):
    pass


# ── the home and the registry ────────────────────────────────────────────────────────────────

def home_root():
    h = os.environ.get("YMIR_HOME")
    if h:
        return h
    return os.path.expanduser("~/Documents/ymirhome")


def load_project(home, wanted):
    try:
        import yaml
    except ImportError:
        raise Refusal("PyYAML is not installed — the registry cannot be read")
    reg = os.path.join(home, "hodd", "identity", "projects.yaml")
    if not os.path.isfile(reg):
        raise Refusal(f"no registry at {reg} — set YMIR_HOME")
    data = yaml.safe_load(open(reg)) or {}
    rows = data.get("projects", data)
    if isinstance(rows, dict):
        rows = [dict(id=k, **(v or {})) for k, v in rows.items()]
    w = wanted.lower()
    for r in rows or []:
        if str(r.get("id", "")).lower() == w:
            return r
    for r in rows or []:
        if str(r.get("name", "")).lower() == w:
            return r
    raise Refusal(f"the registry has no project '{wanted}'")


def ledger_dir(home, row):
    board = row.get("board") or {}
    rel = board.get("plans") or ((row.get("records") or {}).get("in_home") or {}).get("plans")
    if not rel:
        realm = row.get("realm") or row.get("company")
        pid = str(row.get("id", ""))
        pid = {"ymir-platform": "ymir"}.get(pid, pid)
        if not realm:
            raise Refusal("the registry row names neither board.plans, records.in_home.plans nor a realm")
        rel = f"svartalfaheim/{realm}/projects/{pid}/plans/"
    path = os.path.join(home, rel)
    if not os.path.isdir(path):
        raise Refusal(f"no plan ledger at {path}")
    return rel.rstrip("/"), path


# ── the plans ────────────────────────────────────────────────────────────────────────────────

def status_group(text):
    """Map a ledger status phrase onto a state GROUP of the board contract."""
    t = (text or "").strip().lower().lstrip("`*_ ")
    head = re.split(r"\s[—–·(-]\s|\s*\(", t, maxsplit=1)[0]
    if re.match(r"(superseded|retired|withdrawn|rejected|abandoned|cancel|dropped|obsolete|merged into)", head):
        return "cancelled"
    if re.match(r"(built|done|landed|shipped|complete|closed|live|fixed|merged|delivered)", head):
        return "done"
    if re.match(r"(partial|active|building|in progress|in-progress|started|working|living)", head):
        return "started"
    if re.match(r"(approved|ready|briefed)", head):
        return "unstarted"
    return "backlog"


def header_status(path):
    try:
        lines = open(path, encoding="utf-8", errors="replace").read().splitlines()[:45]
    except OSError:
        return ""
    for ln in lines:
        m = re.search(r"\*\*Status:?\*\*:?\s*(.+)", ln, re.I) or re.match(r'\s*"status","([^"]+)"', ln, re.I) \
            or re.match(r"\s*status:\s*(.+)", ln, re.I)
        if m:
            return m.group(1).strip()
    return ""


def clean_title(text):
    t = re.sub(r"^#+\s*", "", text.strip())
    t = re.sub(r"^(?:Plan\s+)?\d+\s*[—–:-]\s*", "", t, flags=re.I)
    return re.sub(r"\s+", " ", t).strip()


def file_title(path):
    try:
        for ln in open(path, encoding="utf-8", errors="replace"):
            if ln.startswith("# "):
                return clean_title(ln)
    except OSError:
        pass
    return ""


def read_plans(ledger_rel, ledger_abs, include_old=False):
    """-> list of dicts (num, title, rel, status) sorted by number then path."""
    found = {}  # rel path inside the ledger -> {title, status}
    readme = os.path.join(ledger_abs, "README.md")
    if os.path.isfile(readme):
        for ln in open(readme, encoding="utf-8", errors="replace"):
            if not ln.startswith("|"):
                continue
            m = re.match(r"\|\s*(\d+)\s*\|\s*\[([^\]]+)\]\(([^)#]+\.md)\)(.*)$", ln.rstrip())
            if not m:
                continue
            link = m.group(3)
            if not os.path.isfile(os.path.join(ledger_abs, link)):
                continue
            cells = [c.strip() for c in m.group(4).split("|")]
            cells = [c for c in cells if c != ""]
            status = cells[-1] if cells else ""
            found[link] = {"title": clean_title(m.group(2)), "status": status}  # a later row wins
    for fn in sorted(os.listdir(ledger_abs)):  # plans at the ledger's root that the index lacks
        if re.match(r"\d+[-_].*\.md$", fn) and fn not in found:
            found[fn] = {"title": "", "status": None}
    plans = []
    for rel, info in found.items():
        if rel.startswith("old-plans/") and not include_old:
            continue
        base = os.path.basename(rel)
        m = re.match(r"(\d+)", base)
        if not m:
            continue
        absf = os.path.join(ledger_abs, rel)
        title = info["title"] or file_title(absf) or re.sub(r"^\d+[-_]", "", base[:-3]).replace("-", " ")
        status = info["status"]
        if status is None or not status.strip():
            status = header_status(absf)
        plans.append({"num": int(m.group(1)), "title": title, "rel": f"{ledger_rel}/{rel}",
                      "status": status or "", "group": status_group(status)})
    plans.sort(key=lambda p: (p["num"], p["rel"]))
    return plans


def card_title(p):
    return f"{p['num']:03d} · {p['title']}"[:250]


def card_description(p):
    word = (p["status"] or "no status in the ledger").split(" — ")[0].split(" · ")[0].strip()[:60]
    return (f"Plan {p['num']}. File: {p['rel']}\n"
            f"plan-status: {p['group']} ({word})\n"
            f"Mirrored by plan-sync (plan 335); the ledger is the record, this card is its view.")


def desc_state(desc):
    m = re.search(r"^plan-status: (\w+) \(", desc or "", re.M)
    return m.group(1) if m else None


# ── the sync ─────────────────────────────────────────────────────────────────────────────────

def find_card(board, by_num, p, plans_by_num):
    cands = by_num.get(p["num"], [])
    want = card_title(p)
    for c in cands:
        if c["title"] == want:
            return c
    if len(plans_by_num[p["num"]]) == 1 and len(cands) == 1:
        return cands[0]  # the same plan under a new title
    if board.page_full:  # a full page may have hidden it: ask for this number alone before creating
        for c in board.find_cards(LABEL, f"{p['num']:03d} ·"):
            if c["title"] == want and LABEL in c["labels"]:
                return c
    return None


def build_board(home, row):
    board = row.get("board") or {}
    if not board:
        raise Refusal(f"project '{row.get('id')}' has no board: block in the registry")
    if board.get("adapter") != "mcp":
        raise Refusal(f"board.adapter '{board.get('adapter')}' has no adapter yet — only 'mcp' exists")
    place, mcpc = board.get("place"), board.get("mcp") or {}
    if not place or not mcpc.get("url") or not mcpc.get("token_from"):
        raise Refusal("board.place, board.mcp.url and board.mcp.token_from are all required")
    root = os.environ.get("YMIR_ROOT") or os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    return place, McpBoard(place, mcpc["url"], resolve_token(mcpc["token_from"], home, root))


def run(args):
    home = home_root()
    row = load_project(home, args.project)
    place, board = build_board(home, row)
    ledger_rel, ledger_abs = ledger_dir(home, row)
    plans = read_plans(ledger_rel, ledger_abs, args.include_old)
    plans_by_num = {}
    for p in plans:
        plans_by_num.setdefault(p["num"], []).append(p)

    if board.ensure_label(LABEL, dry=args.dry_run):
        print(f"label '{LABEL}': {'would create' if args.dry_run else 'created'} in {place}")
    by_num = {}
    for c in board.list_cards(LABEL):  # only plan-labelled cards in the NNN · shape are ours
        m = TITLE_RE.match(c["title"])
        if m and LABEL in c["labels"]:
            by_num.setdefault(int(m.group(1)), []).append(c)

    if board.saturated and not args.dry_run:
        raise Refusal("the board lists as many plan cards as it is known to reveal, so older ones may be hidden and a "
                      "second pass would create them again. Nothing was written; run with --dry-run, or have the board's "
                      "owner list the place in full")
    n = {"created": 0, "updated": 0, "unchanged": 0}
    for p in plans:
        card = find_card(board, by_num, p, plans_by_num)
        title, desc = card_title(p), card_description(p)
        if card is None:
            print(f"create  {title}  [{p['group']}]")
            if not args.dry_run:
                board.create_card(title, desc, p["group"], [LABEL])
            n["created"] += 1
            continue
        change = {}
        if card["title"] != title:
            change["title"] = title
        if card["group"] != p["group"]:
            if desc_state(board.get_card(card["card"]).get("description")) != p["group"]:  # the ledger moved, so the card follows
                change["group"] = p["group"]
                change["description"] = desc
            # else the board moved it by hand: leave it where it stands
        if change:
            print(f"update  #{card['card']} {title}  {sorted(change)}")
            if not args.dry_run:
                board.update_card(card["card"], **change)
            n["updated"] += 1
        else:
            n["unchanged"] += 1
    mode = "dry-run " if args.dry_run else ""
    print(f"plan-sync {mode}{place}: plans={len(plans)} created={n['created']} updated={n['updated']} unchanged={n['unchanged']}")
    return 0


def main(argv):
    ap = argparse.ArgumentParser(prog="plan-sync.sh", description="mirror a plan ledger onto its board, one card per plan")
    ap.add_argument("--project", required=True, help="the registry id (or name) whose ledger to mirror")
    ap.add_argument("--dry-run", action="store_true", help="print what would change; write nothing")
    ap.add_argument("--include-old", action="store_true", help="also mirror the reference archive old-plans/")
    args = ap.parse_args(argv)
    try:
        return run(args)
    except BoardRefusal as e:
        print(f"plan-sync: refused — {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
