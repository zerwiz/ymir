#!/usr/bin/env bash
# plan-board.sh — how many plans are done and not done, what to work on next, and which old
# plans a newer one has superseded — from EVIDENCE, then confirmed by a person.
#
# Why (the Allfather, 2026-11-12): "we need a system to track how many plans we have done and
# not done and what we need to work on so we can work on it and validate if old plans are
# superseded." Measured the same night: 218 of 229 plans carried no Status header, and the
# index's status column said "opened" for 121 of them — many long since shipped. A label
# nobody updates cannot answer the question, so this door reads the evidence instead:
#
#   declared   the plan's own `Status:` header (plan-state.sh's field), else the index column
#   commits    commits on the Ymir main branch whose message names the plan ("plan 190")
#   PRs        `PR #N` cited in the plan's text, and whether GitHub says it merged
#   superseded a NEWER plan that says it supersedes / replaces / retires / absorbs this one,
#              or this plan's own "superseded by plan M"
#
# A status the evidence suggests carries a `?` — it is a suggestion, never a verdict. A person
# confirms it with `confirm`, which writes the plan's header; only then is it a fact.
#
# Usage:
#   plan-board.sh tally                       # done · building · open · superseded · parked, counted
#   plan-board.sh list [--status S]           # every plan, one row: number, status, evidence, title
#   plan-board.sh next [N]                    # what to work on: open/building, newest first (default 15)
#   plan-board.sh supersede                   # old plans a newer one claims to replace — to validate
#   plan-board.sh show <number>               # the evidence for one plan
#   plan-board.sh confirm <number|file> <done|building|open|parked|superseded> [--by <number>]
#   add --json to tally/list/next/supersede for machine output
#
# The ledger: YMIR_PLAN_DIR, else the home's ymir project shelf (as plan-state.sh finds it).
# Exit: 0 ok · 1 no ledger · 2 usage.
set -uo pipefail
VERSION="1.0.0"
case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLAN_DIR="${YMIR_PLAN_DIR:-}"
if [ -z "$PLAN_DIR" ]; then
  # The ledger's realm is the OPERATOR's, so it is DISCOVERED inside his home; the
  # repository carries no realm name of ours (RULES/04). A home with several ledgers
  # answers "name one", never a guess.
  . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
  command -v ymir_plan_dir >/dev/null 2>&1 && { ymir_plan_dir PLAN_DIR 2>/dev/null || true; }
fi
[ -n "$PLAN_DIR" ] && [ -d "$PLAN_DIR" ] || { printf 'plan-board: no ledger (set YMIR_PLAN_DIR)\n' >&2; exit 1; }

exec python3 - "$ROOT" "$PLAN_DIR" "$@" <<'PY'
import json, os, re, subprocess, sys
from datetime import date

root, plan_dir, *argv = sys.argv[1:]
JSON = "--json" in argv
argv = [a for a in argv if a != "--json"]
cmd = argv[0] if argv else "tally"
STATUSES = ("done", "building", "open", "parked", "superseded")

def run(args, cwd=None):
    try:
        return subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=60).stdout
    except Exception:
        return ""

# ---- the plans --------------------------------------------------------------------------
plans = []
# The top of the shelf only: old-plans/, inbox/, audits/ and errands/ are records about
# plans, not plans; and a date (2026-11-12-…) is not a plan number.
for fn in sorted(os.listdir(plan_dir)):
    m = re.match(r"^(\d{1,3})-.*\.md$", fn)
    if m:
        p = os.path.join(plan_dir, fn)
        plans.append({"num": int(m.group(1)), "file": fn, "path": p})
plans.sort(key=lambda x: (x["num"], x["file"]))

def norm_status(s):
    s = re.sub(r"[*_`]", "", s or "").strip().lower()
    w = s.split()[0] if s.split() else ""
    w = w.strip(".,;:—-")
    return {"done": "done", "shipped": "done", "merged": "done", "complete": "done", "completed": "done",
            "built": "building", "building": "building", "in-progress": "building",
            "open": "open", "opened": "open", "proposed": "open",
            "parked": "parked", "paused": "parked",
            "superseded": "superseded", "retired": "superseded", "replaced": "superseded"}.get(w, "")

# the index's last column, keyed by file name
index_status = {}
readme = os.path.join(plan_dir, "README.md")
if os.path.exists(readme):
    for line in open(readme, encoding="utf-8", errors="replace"):
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        link = re.search(r"\(([^)]+\.md)\)|`([^`]+\.md)`", line)
        if link and len(cells) >= 3:
            index_status[os.path.basename(link.group(1) or link.group(2))] = norm_status(cells[-1])

for p in plans:
    text = open(p["path"], encoding="utf-8", errors="replace").read()
    p["text"] = text
    h1 = re.search(r"^#\s+(.+)$", text, re.M)
    p["title"] = re.sub(r"^Plan\s+\d+\s*[-—·:]\s*", "", h1.group(1)).strip() if h1 else p["file"]
    head = "\n".join(text.splitlines()[:25])
    hs = re.search(r"^\**status:?\**:?\s*(.+)$", head, re.I | re.M)
    # a front-matter "status: live" is header.sh's default for a note, not a plan's state
    if hs and not norm_status(hs.group(1)):
        hs = None
    p["declared"] = norm_status(hs.group(1)) if hs else ""
    p["declared_from"] = "header" if p["declared"] else ""
    if not p["declared"] and index_status.get(os.path.basename(p["file"])):
        p["declared"] = index_status[os.path.basename(p["file"])]
        p["declared_from"] = "index"
    sb = re.search(r"superseded[ _]by:? (?:plan )?(\d+)", text, re.I)
    p["superseded_by"] = [int(sb.group(1))] if sb else []

# ---- the evidence: commits on main ------------------------------------------------------
log = run(["git", "log", "origin/main", "--format=%cs%x1f%s%x1f%b%x1e"], cwd=root)
commits = [c.split("\x1f") for c in log.split("\x1e") if c.strip()]
plan_ref = re.compile(r"\bplans?[ -]?#?0*(\d{1,3})(?!\d)", re.I)
by_plan = {}
for c in commits:
    if len(c) < 2:
        continue
    d, msg = c[0].strip(), " ".join(c[1:])
    for n in set(int(x) for x in plan_ref.findall(msg)):
        e = by_plan.setdefault(n, {"count": 0, "last": ""})
        e["count"] += 1
        e["last"] = max(e["last"], d)

# ---- the evidence: PRs cited in the plan, and GitHub's word on them ----------------------
merged = set()
pr_names = {}   # plan number -> merged PRs whose TITLE or BRANCH names it (the strong evidence)
out = run(["gh", "pr", "list", "--state", "merged", "--limit", "2000", "--json", "number,title,headRefName"], cwd=root)
try:
    for pr in json.loads(out or "[]"):
        merged.add(pr["number"])
        for n in set(int(x) for x in plan_ref.findall(pr["title"] + " " + pr["headRefName"].replace("-", " "))):
            pr_names.setdefault(n, []).append(pr["number"])
except ValueError:
    pass

# fix notes on main that name the plan
fix_names = {}
fixes = os.path.join(root, "docs", "fixes")
for dp, _, files in os.walk(fixes):
    for fn in files:
        if fn.endswith(".md"):
            try:
                t = open(os.path.join(dp, fn), encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            for n in set(int(x) for x in plan_ref.findall(t)):
                fix_names[n] = fix_names.get(n, 0) + 1
for p in plans:
    prs = sorted({int(x) for x in re.findall(r"PR\s*#(\d+)", p["text"])})
    p["prs"] = prs
    p["prs_merged"] = [x for x in prs if x in merged]

# ---- the evidence: a newer plan claims this one -----------------------------------------
claim = re.compile(r"(supersed\w*|replac\w*|retir\w*|absorb\w*|folds? (?:in|into)|takes? over)[^.\n]{0,80}?\bplans?\s+(\d{1,3})(?!\d)"
                   r"|\bplans?\s+(\d{1,3})(?!\d)[^.\n]{0,40}?\b(is |was |now )?(supersed\w*|replac\w*|retir\w*|absorb\w*)", re.I)
num_index = {}
for p in plans:
    num_index.setdefault(p["num"], []).append(p)
for p in plans:
    p["claimed_by"] = []
for p in plans:
    for m in claim.finditer(p["text"]):
        n = int(m.group(2) or m.group(3))
        if n < p["num"] and n in num_index:
            for old in num_index[n]:
                if p["num"] not in old["claimed_by"]:
                    old["claimed_by"].append(p["num"])
for p in plans:
    for n in p["superseded_by"]:
        if n not in p["claimed_by"]:
            p["claimed_by"].append(n)

# ---- the suggestion ---------------------------------------------------------------------
tail_done = re.compile(r"\b(merged|shipped|landed|sealed|done)\b", re.I)
# "nothing built", "not merged", "unbuilt": a keyword after a negation is not evidence of
# work (the board sync's fault, 2026-11-12: "nothing built" was mapped to Done).
negated = re.compile(r"\b(nothing|not|never|un|no)\s*-?\s*(yet\s+)?(built|merged|shipped|landed|done)\b", re.I)
for p in plans:
    ev = by_plan.get(p["num"], {"count": 0, "last": ""})
    p["commits"], p["last_commit"] = ev["count"], ev["last"]
    p["pr_named"] = sorted(set(pr_names.get(p["num"], [])))
    p["fix_notes"] = fix_names.get(p["num"], 0)
    tail = p["text"][-1500:]
    says_done = bool(tail_done.search(negated.sub("", tail)))
    says_unbuilt = bool(negated.search(tail))
    if p["declared_from"] == "header":
        p["status"], p["why"] = p["declared"], "header"
    elif p["claimed_by"]:
        p["status"], p["why"] = "superseded?", "plan " + ", ".join(map(str, sorted(p["claimed_by"]))) + " claims it"
    elif p["pr_named"] and not says_unbuilt and (says_done or (p["prs"] and len(p["prs_merged"]) == len(p["prs"]))):
        p["status"], p["why"] = "done?", f"merged PR {' '.join('#'+str(x) for x in p['pr_named'][:3])} names it; nothing left unbuilt in its text"
    elif p["pr_named"] or p["commits"] or p["prs_merged"] or p["fix_notes"]:
        p["status"], p["why"] = "building?", (f"{len(p['pr_named'])} PR(s) named, {p['commits']} commit(s), "
                                              f"{p['fix_notes']} fix note(s), {len(p['prs_merged'])}/{len(p['prs'])} cited PR(s) merged")
    elif p["declared"]:
        p["status"], p["why"] = p["declared"] + ("?" if p["declared"] != "open" else ""), "index column"
    else:
        p["status"], p["why"] = "open", "no evidence of work"

def base(s):
    return s.rstrip("?")

def row(p):
    return {k: p[k] for k in ("num", "status", "why", "pr_named", "commits", "last_commit", "fix_notes", "prs", "prs_merged", "claimed_by", "title", "file")}

def toon(name, rows, cols):
    print(f"{name}[{len(rows)}]{{{','.join(cols)}}}:")
    for r in rows:
        vals = []
        for c in cols:
            v = r[c]
            v = " ".join(map(str, v)) if isinstance(v, list) else str(v)
            vals.append('"' + v.replace('"', "'") + '"')
        print("  " + ",".join(vals))

COLS = ("num", "status", "why", "title")

if cmd == "tally":
    t = {s: 0 for s in STATUSES}
    unconfirmed = 0
    for p in plans:
        t[base(p["status"])] = t.get(base(p["status"]), 0) + 1
        unconfirmed += p["status"].endswith("?")
    res = {"total": len(plans), **t, "suggested_not_confirmed": unconfirmed,
           "duplicate_numbers": sorted(n for n, v in num_index.items() if len(v) > 1)}
    if JSON:
        print(json.dumps(res)); sys.exit(0)
    print("plan-board[1]{total,done,building,open,parked,superseded,suggested_not_confirmed}:")
    print("  " + ",".join(f'"{res[k]}"' for k in ("total", "done", "building", "open", "parked", "superseded", "suggested_not_confirmed")))
    if res["duplicate_numbers"]:
        print("help: numbers used twice on the shelf: " + " ".join(map(str, res["duplicate_numbers"])))
    print("help: a '?' status is evidence, not a verdict — plan-board.sh supersede, then confirm")
elif cmd == "list":
    want = argv[argv.index("--status") + 1] if "--status" in argv else ""
    rows = [row(p) for p in plans if not want or base(p["status"]) == want]
    print(json.dumps(rows)) if JSON else toon("plans", rows, COLS)
elif cmd == "next":
    k = int(argv[1]) if len(argv) > 1 and argv[1].isdigit() else 15
    cand = [p for p in plans if base(p["status"]) in ("open", "building")]
    cand.sort(key=lambda p: (base(p["status"]) != "building", -p["num"]))
    rows = [row(p) for p in cand[:k]]
    print(json.dumps(rows)) if JSON else toon("next", rows, COLS)
elif cmd == "supersede":
    rows = [row(p) for p in plans if p["claimed_by"] and p["declared_from"] != "header"]
    print(json.dumps(rows)) if JSON else toon("supersede", rows, ("num", "claimed_by", "status", "title"))
    if not JSON:
        print("help: read the newer plan; if it truly replaces the old, plan-board.sh confirm <old> superseded --by <new>")
elif cmd == "show":
    n = int(argv[1])
    for p in num_index.get(n, []):
        print(json.dumps(row(p), indent=2, ensure_ascii=False))
    if n not in num_index:
        print(f"plan-board: no plan {n}", file=sys.stderr); sys.exit(2)
elif cmd == "confirm":
    if len(argv) < 3 or argv[2] not in STATUSES:
        print("usage: plan-board.sh confirm <number|file> <" + "|".join(STATUSES) + "> [--by <number>]", file=sys.stderr); sys.exit(2)
    target, st = argv[1], argv[2]
    by = argv[argv.index("--by") + 1] if "--by" in argv else ""
    hits = num_index.get(int(target), []) if target.isdigit() else [p for p in plans if p["file"].endswith(target)]
    if len(hits) != 1:
        print(f"plan-board: '{target}' names {len(hits)} plans — name the file", file=sys.stderr); sys.exit(2)
    p = hits[0]

    def set_front(path, fields):
        """The house's declared header (bin/records/header.sh): YAML front matter with
        kind · status · verified · verified_by · supersedes · superseded_by. Only the named
        keys change; the body is never touched — a body line that starts "Status:" is history."""
        text = open(path, encoding="utf-8").read()
        if text.startswith("---\n") and "\n---\n" in text[4:]:
            end = text.index("\n---\n", 4)
            front, body = text[4:end].splitlines(), text[end + 5:]
        else:
            front, body = ["kind: plan", "supersedes: none", "superseded_by: none"], text
        keys = [l.split(":", 1)[0].strip() for l in front]
        for k, v in fields.items():
            if k in keys:
                front[keys.index(k)] = f"{k}: {v}"
            else:
                front.append(f"{k}: {v}")
                keys.append(k)
        open(path, "w", encoding="utf-8").write("---\n" + "\n".join(front) + "\n---\n" + body)

    today = date.today().isoformat()
    fields = {"status": st, "verified": "confirmed", "verified_by": f"{today} (plan-board confirm)"}
    if st == "superseded" and by:
        fields["superseded_by"] = f"plan {by}"
    set_front(p["path"], fields)
    if st == "superseded" and by and by.isdigit() and len(num_index.get(int(by), [])) == 1:
        set_front(num_index[int(by)][0]["path"], {"supersedes": f"plan {p['num']}"})
    print(f'plan-board[1]{{plan,status,by}}:\n  "{p["file"]}","{st}","{by}"')
    if st == "superseded" and by and by.isdigit() and len(num_index.get(int(by), [])) > 1:
        names = " · ".join(x["file"] for x in num_index[int(by)])
        print(f"help: plan {by} is two files ({names}) — write `supersedes: plan {p['num']}` in the right one by hand")
else:
    print(f"plan-board: unknown command {cmd}", file=sys.stderr); sys.exit(2)
PY
