#!/usr/bin/env python3
"""status.py — the status of every plan, ticket and document in this repository, read from their headers.

  python3 scripts/status.py                 # plans, tickets, then documents, as tables
  python3 scripts/status.py plans           # plans only (with ticket count and validated_by)
  python3 scripts/status.py tickets         # tickets only
  python3 scripts/status.py docs            # documents only
  python3 scripts/status.py plans --status Proposed --priority Critical
  python3 scripts/status.py --plan PREFIX-028   # (PREFIX = the project's own) that plan and its tickets only
  python3 scripts/status.py --json          # machine-readable, for CI or a dashboard
  python3 scripts/status.py --check         # exit 1 if a header is missing or malformed

The prefix is not assumed. It is read from `plans/.prefix` (one line, e.g. `ACME`) when that file exists;
otherwise from the plan files themselves — any `plans/<PREFIX>-NNN-*.md` — and `PLAN` is the last resort for a
repository with no plans yet.

Plans (`plans/PREFIX-NNN-*.md`) carry YAML front matter: ticket_number, title, type, priority, status,
validated_by, validated_on, updated. The plan lifecycle (RULES/19) is
`Proposed -> In Review -> Validated -> In Progress -> Done`, plus `Rejected` and `Superseded`. `Backlog`, the
status plans used before RULES/19, is still read but reported as a warning only. A plan is *validated* when its
status is Validated, In Progress or Done, and then `validated_by` and `validated_on` must be filled in.

Tickets (`plans/tickets/PREFIX-<plan>-T<nn>-<slug>.md`, README and TEMPLATE skipped) carry: ticket, plan, title,
status, assignee, priority, created, updated, pr_url. Ticket status is
`Open -> In Progress -> In Review -> Done`, plus `Blocked` and `Cancelled`. A ticket past Open whose plan is not
Validated or later is flagged "plan not validated" and fails `--check`.

Documents (`docs/**/*.md`, except `docs/fixes/` and `docs/kit/`) should carry the same kind of header:

  ---
  title: "The tenant architecture"
  status: "review"        # draft | review | accepted | superseded
  owner: "Ada Owner"
  reviewer: "Ben Reviewer"
  updated: "2026-11-11"
  ---

A document with no header is reported as `no header`, never guessed at. Nothing here needs a library: it reads
the simple `key: "value"` lines the headers use, and the standard library is enough.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def detect_prefix():
    """plans/.prefix wins; else the commonest `<PREFIX>-NNN-*.md` among the plans; else PLAN."""
    pf = ROOT / "plans" / ".prefix"
    if pf.is_file():
        line = pf.read_text(encoding="utf-8").strip().splitlines()
        if line and line[0].strip():
            return line[0].strip()
    counts = {}
    for p in (ROOT / "plans").glob("*.md") if (ROOT / "plans").is_dir() else []:
        m = re.match(r"^([A-Za-z][A-Za-z0-9]*)-\d+-", p.name)
        if m:
            counts[m.group(1)] = counts.get(m.group(1), 0) + 1
    return max(counts, key=counts.get) if counts else "PLAN"


PREFIX = detect_prefix()
PLAN_FIELDS = ["ticket_number", "title", "type", "priority", "status", "updated"]
PLAN_STATUSES = {"Proposed", "In Review", "Validated", "In Progress", "Done", "Rejected", "Superseded"}
LEGACY_PLAN_STATUSES = {"Backlog"}  # accepted with a warning only
VALIDATED_PLAN_STATUSES = {"Validated", "In Progress", "Done"}
TICKET_FIELDS = ["ticket", "plan", "title", "status", "assignee", "priority", "created", "updated", "pr_url"]
TICKET_REQUIRED = ["ticket", "plan", "title", "status", "priority", "created", "updated"]  # assignee, pr_url may be empty
TICKET_STATUSES = {"Open", "In Progress", "In Review", "Done", "Blocked", "Cancelled"}
DOC_FIELDS = ["title", "status", "owner", "updated"]
DOC_STATUSES = {"draft", "review", "accepted", "superseded", "record"}
SKIP_DOCS = ("docs/fixes/", "docs/kit/")


def front_matter(text):
    """Return the header as a dict, or None when the file does not start with one."""
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---", 4)
    if end == -1:
        return None
    meta = {}
    for line in text[4:end].splitlines():
        m = re.match(r'^([A-Za-z_][\w-]*):\s*(.*)$', line)
        if not m:
            continue
        value = m.group(2).split(" #")[0].strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        meta[m.group(1)] = value
    return meta


def first_heading(text):
    m = re.search(r'^#\s+(.+)$', text, re.M)
    return m.group(1).strip() if m else ""


def last_commit(path):
    try:
        out = subprocess.run(["git", "-C", str(ROOT), "log", "-1", "--format=%cs", "--", str(path)],
                             capture_output=True, text=True, timeout=10).stdout.strip()
        return out or "uncommitted"
    except Exception:
        return "unknown"


def plan_key(text_or_name):
    m = re.search(re.escape(PREFIX) + r"-(\d+)", text_or_name)
    return m.group(1) if m else ""


def scan_tickets():
    rows = []
    shelf = ROOT / "plans" / "tickets"
    for p in sorted(shelf.glob(PREFIX + "-*.md")) if shelf.is_dir() else []:
        text = p.read_text(encoding="utf-8")
        meta = front_matter(text) or {}
        problems = [f"missing {f}" for f in TICKET_REQUIRED if not meta.get(f)]
        for f in TICKET_FIELDS:
            if f not in meta and f not in TICKET_REQUIRED:
                problems.append(f"missing {f}")
        if meta.get("status") and meta["status"] not in TICKET_STATUSES:
            problems.append(f"unknown status {meta['status']!r}")
        if "## References" not in text:
            problems.append("no References")
        rows.append({
            "ticket": meta.get("ticket", p.stem),
            "plan": meta.get("plan", ""),
            "title": meta.get("title", first_heading(text)),
            "status": meta.get("status", ""),
            "assignee": meta.get("assignee", ""),
            "priority": meta.get("priority", ""),
            "updated": meta.get("updated", ""),
            "pr_url": meta.get("pr_url", ""),
            "file": str(p.relative_to(ROOT)),
            "problems": problems,
            "warnings": [],
        })
    return rows


def scan_plans(tickets=None):
    tickets = tickets if tickets is not None else scan_tickets()
    rows = []
    for p in sorted((ROOT / "plans").glob(PREFIX + "-*.md")):
        text = p.read_text(encoding="utf-8")
        meta = front_matter(text) or {}
        problems = [f"missing {f}" for f in PLAN_FIELDS if not meta.get(f)]
        warnings = []
        status = meta.get("status", "")
        if status in LEGACY_PLAN_STATUSES:
            warnings.append(f"legacy status {status!r}")
        elif status and status not in PLAN_STATUSES:
            problems.append(f"unknown status {status!r}")
        for f in ("validated_by", "validated_on"):
            if f not in meta:
                problems.append(f"missing {f}")
        if status in VALIDATED_PLAN_STATUSES and not (meta.get("validated_by") and meta.get("validated_on")):
            problems.append("validated without validated_by/validated_on")
        if "## References" not in text:
            problems.append("no References")
        number = meta.get("ticket_number", "?")
        mine = [t for t in tickets if plan_key(t["plan"]) == number]
        rows.append({
            "number": number,
            "title": re.sub(r'^\[' + re.escape(PREFIX) + r'-\d+\]\s*', '', meta.get("title", first_heading(text))),
            "type": meta.get("type", ""),
            "priority": meta.get("priority", ""),
            "status": status,
            "validated_by": meta.get("validated_by", ""),
            "validated_on": meta.get("validated_on", ""),
            "tickets": len(mine),
            "updated": meta.get("updated", ""),
            "file": str(p.relative_to(ROOT)),
            "problems": problems,
            "warnings": warnings,
        })
    # a ticket past Open whose plan is not Validated or later
    by_number = {r["number"]: r for r in rows}
    for t in tickets:
        plan = by_number.get(plan_key(t["plan"]))
        if plan is None:
            t["problems"].append("plan not found")
        elif t["status"] not in ("Open", "Cancelled", "") and plan["status"] not in VALIDATED_PLAN_STATUSES:
            t["problems"].append("plan not validated")
    return rows


def scan_docs():
    rows = []
    for p in sorted((ROOT / "docs").rglob("*.md")):
        rel = str(p.relative_to(ROOT))
        if rel.startswith(SKIP_DOCS):
            continue
        text = p.read_text(encoding="utf-8")
        meta = front_matter(text)
        problems = []
        if meta is None:
            problems.append("no header")
            meta = {}
        else:
            problems += [f"missing {f}" for f in DOC_FIELDS if not meta.get(f)]
            if meta.get("status") and meta["status"] not in DOC_STATUSES:
                problems.append(f"unknown status {meta['status']!r}")
        if p.name != "README.md" and "## References" not in text:
            problems.append("no References")
        rows.append({
            "title": meta.get("title") or first_heading(text),
            "status": meta.get("status", ""),
            "owner": meta.get("owner", ""),
            "reviewer": meta.get("reviewer", ""),
            "updated": meta.get("updated", ""),
            "last_commit": last_commit(p),
            "file": rel,
            "problems": problems,
            "warnings": [],
        })
    return rows


def table(rows, cols):
    if not rows:
        print("  (none)")
        return
    width = {c: max(len(c), *(len(str(r[c])) for r in rows)) for c in cols}
    width = {c: min(w, 60) for c, w in width.items()}
    print("  " + "  ".join(c.ljust(width[c]) for c in cols))
    print("  " + "  ".join("-" * width[c] for c in cols))
    for r in rows:
        print("  " + "  ".join(str(r[c])[:width[c]].ljust(width[c]) for c in cols))


def summary(rows, key):
    counts = {}
    for r in rows:
        counts[r[key] or "(none)"] = counts.get(r[key] or "(none)", 0) + 1
    return " · ".join(f"{k} {v}" for k, v in sorted(counts.items()))


def main(argv):
    what = next((a for a in argv if a in ("plans", "tickets", "docs")), "all")
    as_json = "--json" in argv
    check = "--check" in argv
    only_plan = ""
    if "--plan" in argv:
        i = argv.index("--plan")
        if i + 1 < len(argv):
            only_plan = plan_key(argv[i + 1])
    filters = {}
    for flag in ("--status", "--priority", "--type", "--owner"):
        if flag in argv:
            i = argv.index(flag)
            if i + 1 < len(argv):
                filters[flag[2:]] = argv[i + 1]

    def keep(r):
        return all(str(r.get(k, "")).lower() == v.lower() for k, v in filters.items())

    all_tickets = scan_tickets()
    all_plans = scan_plans(all_tickets)
    plans = [r for r in all_plans if keep(r) and (not only_plan or r["number"] == only_plan)] if what in ("all", "plans", "tickets") else []
    tickets = [r for r in all_tickets if keep(r) and (not only_plan or plan_key(r["plan"]) == only_plan)] if what in ("all", "tickets") or only_plan else []
    docs = [r for r in scan_docs() if keep(r)] if what in ("all", "docs") and not only_plan else []
    if what == "tickets":
        plans = []
    if what == "docs":
        tickets = []

    def flags(r):
        out = list(r["problems"]) + [f"warning: {w}" for w in r["warnings"]]
        return ", ".join(out) or "ok"

    if as_json:
        print(json.dumps({"plans": plans, "tickets": tickets, "docs": docs}, indent=2, ensure_ascii=False))
    else:
        if plans:
            print(f"PLANS ({len(plans)})  status: {summary(plans, 'status')}  ·  priority: {summary(plans, 'priority')}")
            for r in plans:
                r["flags"] = flags(r)
                r["validated"] = r["validated_by"] or "-"
            table(plans, ["number", "status", "validated", "tickets", "priority", "type", "updated", "title", "flags"])
            print()
        if what in ("all", "tickets") or only_plan:
            print(f"TICKETS ({len(tickets)})  status: {summary(tickets, 'status')}")
            for r in tickets:
                r["flags"] = flags(r)
            table(tickets, ["ticket", "plan", "status", "priority", "assignee", "updated", "title", "flags"])
            print()
        if docs or what == "docs":
            print(f"DOCUMENTS ({len(docs)})  status: {summary(docs, 'status')}")
            for r in docs:
                r["flags"] = flags(r)
            table(docs, ["status", "owner", "updated", "last_commit", "file", "flags"])

    problems = sum(len(r["problems"]) for r in plans + tickets + docs)
    warnings = sum(len(r["warnings"]) for r in plans + tickets + docs)
    if check:
        print(f"\ncheck: {problems} problem(s), {warnings} warning(s) in {len(plans)} plans, "
              f"{len(tickets)} tickets and {len(docs)} documents", file=sys.stderr)
        return 1 if problems else 0
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
