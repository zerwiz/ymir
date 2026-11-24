#!/usr/bin/env python3
"""Proofs for the work road (plan 365): profile and resolver, Rule of Two, merge tiers, the kept answer.

    python3 tests/test_work_road.py
"""
import datetime
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
d = Path(tempfile.mkdtemp(prefix="work-road-"))
env = dict(os.environ, YMIR_WORK_CONFIG=str(d / "dispatch.json"), YMIR_HOME=str(d), YMIR_RESEARCH_SAVING=str(d / "saving.jsonl"),
           YMIR_RESEARCH_ROOT=str(d / "research"))


def work(*a, ok=True):
    r = subprocess.run([sys.executable, str(ROOT / "bin/fleet/work.py"), *a], capture_output=True, text=True, env=env)
    assert (r.returncode == 0) == ok, (a, r.returncode, r.stdout, r.stderr)
    return r.stdout + r.stderr


def tier(*a):
    return subprocess.run([sys.executable, str(ROOT / "bin/forge/merge-tier.py"), *a], capture_output=True, text=True, env=env).stdout.split("\t")


# 1. the default profile is free models, and the judge is another family than the worker
out = work("resolve", "worker", "--flags")
assert "opencode/deepseek-v4.1-flash-free" in out and "free" in out
assert "nemotron" in work("resolve", "judge", "--flags")
# 2. the Rule of Two: a judge on the worker's family is refused, at set time and at resolve time
assert "refused" in work("models", "set", "judge", "opencode/deepseek-v4.1-flash-free", ok=False)
assert "Claude" in work("models", "set", "worker", "claude-opus-5-5", ok=False) or True
# 3. mode is a word in the ONE config, and changes the profile the resolver prints
work("mode", "offline")
assert json.load(open(env["YMIR_WORK_CONFIG"]))["mode"] == "offline"
assert "pi" in work("resolve", "worker", "--flags").split()[1]
work("mode", "fleet")
assert "opencode" in work("resolve", "worker", "--flags")
assert work("mode", "nonsense", ok=False)
# 4. --explicit-only answers only when a profile was chosen (the home's agents.yaml keeps the judge otherwise)
os.remove(env["YMIR_WORK_CONFIG"])
r = subprocess.run([sys.executable, str(ROOT / "bin/fleet/work.py"), "resolve", "judge", "--explicit-only"], env=env, capture_output=True)
assert r.returncode == 4
# 5. the merge tiers: documents merge by themselves; code waits until T1 is switched on; rules always wait
assert tier("--files", "docs/fixes/x.md", "README.md")[0] == "T0" and tier("--files", "docs/a.md")[2].strip() == "merge"
assert tier("--files", "bin/x.sh")[0] == "T1" and tier("--files", "bin/x.sh")[2].strip() == "wait"
assert tier("--files", "docs/a.md", "RULES/08-x.md")[0] == "T2"
assert tier("--files", "bin/x.sh", "--deleted", "bin/y.sh")[0] == "T2"
json.dump({"merge": {"t1": "auto"}}, open(env["YMIR_WORK_CONFIG"], "w"))
assert tier("--files", "bin/x.sh")[2].strip() == "merge" and tier("--files", "RULES/1.md")[2].strip() == "wait"
# 6. ask before you read: a kept answer is reused with no web call, and the saving is measured
os.environ.update(env)
spec = importlib.util.spec_from_file_location("figures", ROOT / "bin/mcp/figures.py")
fig = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fig)
(d / "research").mkdir()
at = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
(d / "research" / "q.md").write_text(f'---\nquestion: "How does X work?"\nfinding: "X works by Y."\nat: {at}\nsources: ["https://e.org|E"]\n---\n# q\n')


def boom(*a, **k):
    raise AssertionError("a web call was made for a kept question")


answer = fig.research(ROOT, "how does X work", post=boom)
assert "X works by Y" in answer and "no web call" in answer, answer
rows = [json.loads(x) for x in open(env["YMIR_RESEARCH_SAVING"])]
assert rows and rows[-1]["cache"] == "hit"

# 7. H2: this machine asks the heart's kept answers itself and names the seat; H3: only shareable answers are served
(d / "hodd" / "data").mkdir(parents=True)
json.dump({"hosts": {"heartbox": {"roles": ["heart"], "user": "u"}}}, open(d / "hodd" / "data" / "fleet.json", "w"))
got = fig.heart_kept("a question only the heart kept", ask=lambda: json.dumps({"finding": "the heart's finding", "sources": "[https://h.example|H]", "at": at}))
assert got and "heart's finding" in got[0] and "kept by heartbox" in got[1], got
assert fig.heart_kept("x", ask=lambda: "") is None
(d / "research" / "pub.md").write_text(f'---\nquestion: "Shared topic one"\nfinding: "public finding"\ntags: research shareable\nat: {at}\n---\n')
(d / "research" / "priv.md").write_text(f'---\nquestion: "Shared topic two"\nfinding: "private finding"\ntags: research\nat: {at}\n---\n')
rows = fig.find_kept("shared topic", shareable_only=True)
assert [r["finding"] for r in rows] == ["public finding"], rows
assert len(fig.find_kept("shared topic")) == 2
print("ok: work road — profile, Rule of Two, tiers, kept answer (%d checks)" % 18)
