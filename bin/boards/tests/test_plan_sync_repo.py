#!/usr/bin/env python3
"""test_plan_sync_repo — a ledger kept in the project's own repository, read at a ref; an index with no links;
a ledger's own status words and phase columns. No network: a throwaway git repo and a fake row only."""
import importlib.util
import os
import subprocess
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


def git(repo, *a):
    env = {**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@example.org",
           "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@example.org", "HOME": repo}
    subprocess.run(["git", "-C", repo, *a], check=True, capture_output=True, env=env)


README = """# The plan ledger

| Mark | Means |
|---|---|
| built | done |

| No | Title | Status | One line |
|---|---|---|---|
| 01 | Overview | record | the first brief |
| 02 | The engine | partial | half of it |

| No | Title | Status | One line |
|---|---|---|---|
| 03 | Slices | plan | three slices |
"""

SLICES = """# Plan 03 — Slices

| # | Slice | Done when | Size |
|---|---|---|---|
| 1 | Tokens | it renders | S |
| 2 | Parts | each part passes | M |
"""

with tempfile.TemporaryDirectory() as tmp:
    repo = os.path.join(tmp, "proj")
    os.makedirs(os.path.join(repo, "plans"))
    git(repo, "init", "-q", "-b", "master")
    files = {"README.md": README, "01-overview.md": "# Overview\n", "02-the-engine.md": "# The engine\n",
             "03-slices.md": SLICES}
    for fn, text in files.items():
        Path(repo, "plans", fn).write_text(text)
    git(repo, "add", "plans")
    git(repo, "commit", "-q", "-m", "plans")
    # the checkout moves on, uncommitted: the sync must read the REF, never the working tree
    Path(repo, "plans", "04-draft.md").write_text("# Draft\n")
    Path(repo, "plans", "01-overview.md").write_text("# Changed in the checkout\n")

    row = {"id": "demo", "git": {"host": "git.example.org", "owner": "acme", "repo": "demo", "default_branch": "master"},
           "board": {"adapter": "mcp", "place": "acme/Demo",
                     "plans_repo": {"clone": repo, "ref": "master", "dir": "plans"},
                     "status_map": {"record": "done"},
                     "phase_heads": {"id": ["n"], "name": ["slice"]}}}
    try:
        rel, path = ps.ledger_dir(tmp, row)
        check("the ledger is named by its folder in the repository", rel == "plans" and rel.where == "repository", rel)
        plans = ps.read_plans(rel, path, status_map=row["board"]["status_map"])
        nums = [p["num"] for p in plans]
        check("index rows with no link are read, the uncommitted draft is not", nums == [1, 2, 3], nums)
        check("the ref's text is read, not the checkout's",
              Path(plans[0]["abs"]).read_text() == "# Overview\n", Path(plans[0]["abs"]).read_text())
        check("titles come from the Title column", plans[1]["title"] == "The engine", plans[1]["title"])
        check("the status comes from the Status column", plans[1]["status"] == "partial", plans[1]["status"])
        check("the ledger's own word maps a status", plans[0]["group"] == "done", plans[0]["group"])
        check("the built-in words still apply", plans[1]["group"] == "started", plans[1]["group"])
        check("a word nobody maps is backlog", plans[2]["group"] == "backlog", plans[2]["group"])
        check("the card says the file is in the repository",
              "`plans/01-overview.md` in the repository." in ps.card_markdown(plans[0], "x", False))
        url = ps.file_url(tmp, row, plans[2]["rel"])
        check("the link comes from the row's git block",
              url == "https://git.example.org/acme/demo/blob/master/plans/03-slices.md", url)
        text = Path(plans[2]["abs"]).read_text()
        heads = ps.phase_heads(row["board"]["phase_heads"])
        check("a ledger's own phase columns find the slices",
              ps.read_phases(text, heads) == [("1", "Tokens", "it renders"), ("2", "Parts", "each part passes")],
              ps.read_phases(text, heads))
        check("without them the default reading is unchanged", ps.read_phases(text) == [], ps.read_phases(text))
        check("a file in the clone's ledger finds its project",
              ps.repo_spec(row)["clone"] == repo and ps.repo_spec(row)["dir"] == "plans")
        bad = {**row, "board": {**row["board"], "plans_repo": {"clone": repo, "ref": "no-such-ref", "dir": "plans"}}}
        try:
            ps.ledger_dir(tmp, bad)
            check("an unknown ref is a refusal", False, "no refusal")
        except ps.Refusal as e:
            check("an unknown ref is a refusal that names it", "no-such-ref" in str(e), str(e))
    finally:
        ps.cleanup()
    check("the temporary ledger is removed", all(not os.path.exists(t) for t in ps._TMP), ps._TMP)

# a home ledger with linked rows reads exactly as before
with tempfile.TemporaryDirectory() as home:
    led = os.path.join(home, "svartalfaheim", "r", "projects", "p", "plans")
    os.makedirs(led)
    Path(led, "README.md").write_text("| No | Plan | Status |\n|---|---|---|\n| 7 | [Seven](007-seven.md) | built |\n")
    Path(led, "007-seven.md").write_text("# Plan 7 — Seven\n")
    rel, path = ps.ledger_dir(home, {"id": "p", "realm": "r", "board": {"adapter": "mcp"}})
    plans = ps.read_plans(rel, path)
    check("a home ledger keeps its shape", [(p["num"], p["group"], p["where"]) for p in plans] == [(7, "done", "home")],
          [(p["num"], p["group"], p["where"]) for p in plans])
    check("a home card still says 'in the home'", "in the home." in ps.card_markdown(plans[0], "x", False))

# the door swallows its own rate limit into "no such place/state": a lookup that blinked is retried, a real lack is not
from board_adapter_mcp import McpBoard  # noqa: E402
b = McpBoard.__new__(McpBoard)
b.place, b._states = "acme/Demo", [("Backlog", "backlog"), ("Todo", "unstarted")]
check("a state the place listed, reported missing, is a blink",
      b._place_lookup_blinked('{\n "error": "no such state in acme/Demo: Todo"\n}'))
check("a state the place never had is a refusal", not b._place_lookup_blinked('{"error": "no such state in acme/Demo: Review"}'))
check("the place reported missing while listed is a blink",
      b._place_lookup_blinked('{"error": "no such place on the board: acme/Demo", "places": ["acme/Demo"]}'))
check("a place truly absent is a refusal",
      not b._place_lookup_blinked('{"error": "no such place on the board: acme/Demo", "places": ["acme/Other"]}'))

print(f"{'FAIL' if fails else 'ok'}: {len(fails)} failed")
sys.exit(1 if fails else 0)
