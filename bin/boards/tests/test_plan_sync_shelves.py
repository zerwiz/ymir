#!/usr/bin/env python3
"""test_plan_sync_shelves — a shelf of plans that is no project's (a machine's own folder) finds its board through the
registry's `plan_shelves:`; plan numbers that repeat between shelves never cross cards. No network: a fake home only."""
import importlib.util
import os
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HERE))
spec = importlib.util.spec_from_file_location("plan_sync", HERE / "plan_sync.py")
ps = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ps)

fails = []


def check(name, ok, got=None):
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f" — got {got!r}"))
    if not ok:
        fails.append(name)


REG = """projects:
- id: demo
  realm: r
  board: {adapter: mcp, place: acme/Demo, mcp: {url: 'https://b.example.org/mcp', token_from: 'env:X'}}
plan_shelves:
- id: machine-host-a
  plans: hodd/machines/host-a/plans/
  labels: ['machine:host-a']
  board: {adapter: mcp, place: acme/Demo, mcp: {url: 'https://b.example.org/mcp', token_from: 'env:X'}}
- id: machine-host-b
  plans: hodd/machines/host-b/plans/
  labels: ['machine:host-b']
- id: company-ledger
  plans: svartalfaheim/co/plans/
"""

with tempfile.TemporaryDirectory() as home:
    os.environ["YMIR_HOME"] = home
    Path(home, "hodd", "identity").mkdir(parents=True)
    Path(home, "hodd", "identity", "projects.yaml").write_text(REG)
    for d in ("hodd/machines/host-a/plans", "hodd/machines/host-b/plans", "svartalfaheim/co/plans",
              "svartalfaheim/r/projects/demo/plans"):
        Path(home, d).mkdir(parents=True)
        Path(home, d, "0001-one.md").write_text("# One\n")

    a = ps.project_for_file(home, os.path.join(home, "hodd/machines/host-a/plans/0001-one.md"))
    check("a machine shelf with a board finds it", a["id"] == "machine-host-a" and a["board"]["place"] == "acme/Demo", a)
    check("its ledger is the shelf's folder", ps.ledger_dir(home, a)[0] == "hodd/machines/host-a/plans")
    check("it carries its machine label", a["scope_labels"] == ["machine:host-a"], a.get("scope_labels"))
    p = ps.project_for_file(home, os.path.join(home, "svartalfaheim/r/projects/demo/plans/0001-one.md"))
    check("a project's ledger still finds its project", p["id"] == "demo", p["id"])

    for f, word in (("hodd/machines/host-b/plans/0001-one.md", "host-b"), ("svartalfaheim/co/plans/0001-one.md", "co")):
        try:
            ps.project_for_file(home, os.path.join(home, f))
            check(f"a shelf with no board is refused ({word})", False, "no refusal")
        except ps.Refusal as e:
            check(f"a shelf with no board is refused, named ({word})", "no board: block" in str(e) and "shelf" in str(e), str(e))
    try:
        ps.project_for_file(home, os.path.join(home, "elsewhere/plans/0001-x.md"))
        check("an unknown folder is still refused", False, "no refusal")
    except ps.Refusal as e:
        check("an unknown folder is still refused", "no project with a board" in str(e), str(e))

    owned = ps.shelf_labels(home)
    check("the shelves' labels are known", owned == {"machine:host-a", "machine:host-b"}, owned)
    cards = {"mine": {"labels": ["plan", "machine:host-a"]}, "other": {"labels": ["plan", "machine:host-b"]},
             "project": {"labels": ["plan"]}}
    seen = lambda row: sorted(k for k, c in cards.items() if ps.in_scope(c, row, owned))
    check("a shelf sees only its own cards", seen(a) == ["mine"], seen(a))
    check("a project sees no shelf's card", seen(p) == ["project"], seen(p))

if fails:
    print(f"FAIL: {len(fails)} failed")
    sys.exit(1)
print("ok: 0 failed")
