#!/usr/bin/env python3
"""test_work.py — the proofs for work start/stop/sweep, the stack switch and the deploy door (kit 2.0.0).

Fakes on PATH: a stateful podman (images, builds, rmi, info, containers, pods), a systemctl with a unit state
file, and a gh that answers a pull request's state from a file. No network, no real engine.

  python3 bin/collab/tests/test_work.py -v
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import textwrap
import time
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_kit import Base, Fixture, set_yaml, sh  # noqa: E402

FAKE_PODMAN = r'''#!/usr/bin/env python3
import json, os, sys, time
d = os.environ["FAKE_DIR"]; state = os.path.join(d, "podman.json")
s = json.load(open(state)) if os.path.exists(state) else {"images": [], "running": {}, "driver": "overlay"}
a = sys.argv[1:]
open(os.path.join(d, "calls.log"), "a").write(" ".join(a) + "\n")
if a[:1] == ["--storage-driver"]:
    a = a[2:]
def save(): json.dump(s, open(state, "w"))
v = a[0] if a else ""
if v == "info":
    if os.environ.get("FAKE_INFO_FAILS"): sys.exit(125)
    print(s["driver"], os.path.join(d, "storage"))
elif v == "images":
    print(json.dumps(s["images"]))
elif v == "build":
    labels, tag = {}, None
    for i, x in enumerate(a):
        if x == "--label": k, val = a[i + 1].split("=", 1); labels[k] = val
        if x == "-t": tag = a[i + 1]
    if os.environ.get("FAKE_BUILD_FAILS"): sys.exit(1)
    s["images"].append({"Id": "%012d" % len(s["images"]), "Names": [tag], "Labels": labels, "Created": time.time()})
    save()
elif v == "rmi":
    s["images"] = [i for i in s["images"] if a[1] not in i["Names"]]; save()
elif v in ("start", "stop"):
    s["running"][a[1]] = (v == "start"); save()
elif v == "pod" and a[1] in ("start", "stop"):
    s["running"]["pod:" + a[2]] = (a[1] == "start"); save()
elif v == "inspect":
    if a[1] not in s["running"]: sys.exit(125)
    print(("true" if s["running"][a[1]] else "false") + " 2026-11-20T10:00:00")
elif v == "pod" and a[1] == "inspect":
    print(("Running" if s["running"].get("pod:" + a[2]) else "Exited") + " 2026-11-20T10:00:00")
elif v == "stats":
    print("12MiB / 1GiB|0.5%")
'''

FAKE_SYSTEMCTL = r'''#!/usr/bin/env python3
import json, os, sys
d = os.environ["FAKE_DIR"]; state = os.path.join(d, "units.json")
s = json.load(open(state)) if os.path.exists(state) else {}
a = [x for x in sys.argv[1:] if x != "--user"]
open(os.path.join(d, "calls.log"), "a").write("systemctl " + " ".join(a) + "\n")
if a[0] in ("start", "stop"):
    s[a[1]] = a[0] == "start"; json.dump(s, open(state, "w"))
elif a[0] == "show":
    print("ActiveState=" + ("active" if s.get(a[1]) else "inactive")); print("MemoryCurrent=10485760")
    print("ActiveEnterTimestamp=Thu 2026-11-20 10:00:00 CET")
'''

FAKE_GH = r'''#!/usr/bin/env python3
import json, os, sys
d = os.environ["FAKE_DIR"]; f = os.path.join(d, "pr_state")
open(os.path.join(d, "calls.log"), "a").write("gh " + " ".join(sys.argv[1:]) + "\n")
if sys.argv[1:3] == ["pr", "view"]:
    if not os.path.exists(f): sys.exit(1)
    print(json.dumps({"state": open(f).read().strip(), "url": "https://example.invalid/pr/1"}))
elif sys.argv[1:3] == ["pr", "create"]:
    open(f, "w").write("OPEN"); print("https://example.invalid/pr/1")
'''


class WorkBase(Base):
    def fakes(self) -> dict:
        b = self.tmp / "fakebin"
        b.mkdir(exist_ok=True)
        for name, body in (("podman", FAKE_PODMAN), ("systemctl", FAKE_SYSTEMCTL), ("gh", FAKE_GH)):
            (b / name).write_text(body)
            (b / name).chmod(0o755)
        d = self.tmp / "fakestate"
        d.mkdir(exist_ok=True)
        return {"PATH": f"{b}:{os.environ['PATH']}", "FAKE_DIR": str(d), "KIT_LOCK_DIR": str(self.tmp),
                "KIT_HEALTH_WAIT": "0", "KIT_STACKS_FILE": str(self.tmp / "stacks.yaml")}

    def calls(self, env) -> str:
        p = Path(env["FAKE_DIR"]) / "calls.log"
        return p.read_text() if p.exists() else ""

    def manifest(self, repo: Path):
        (self.tmp / "stacks.yaml").write_text(textwrap.dedent(f"""\
            host: test
            apps:
              repo:
                repos: [{repo}]
                pieces:
                  - {{kind: unit, name: app-dev.service, role: dev}}
                  - {{kind: container, name: app-db, role: dev}}
                  - {{kind: pod, name: app-prod, role: prod}}
                  - {{kind: container, name: someone-elses, role: unknown, owner: another team}}
            """))


class Start(WorkBase):
    def test_start_refused_at_low_disk_and_says_what_to_clean(self):
        f = Fixture(self.tmp)
        r = f.kit("work", "start", "s1", env={"KIT_FAKE_DISK": "20/1000"})
        self.assertEqual(r.returncode, 1)
        self.assertIn("20 GB free", r.stdout)
        self.assertFalse((f.repo / ".worktrees" / "s1").exists())

    def test_start_makes_the_worktree_record_and_turns_the_dev_stack_on(self):
        f = Fixture(self.tmp)
        env = self.fakes()
        self.manifest(f.repo)
        r = f.kit("work", "start", "s2", "--purpose", "the list", env=env)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("next\tcd", r.stdout)
        rec = json.loads(sh('cat "$(git rev-parse --git-dir)/kit.json"', f.repo / ".worktrees" / "s2").stdout)
        self.assertEqual(rec["state"], "working")
        self.assertTrue(rec["started"])
        log = self.calls(env)
        self.assertIn("systemctl start app-dev.service", log)
        self.assertIn("start app-db", log)
        self.assertNotIn("app-prod", log.replace("inspect", ""), "a prod piece is never touched")


class Stop(WorkBase):
    def test_stop_removes_everything_after_merge(self):
        f = Fixture(self.tmp)
        env = self.fakes()
        self.manifest(f.repo)
        f.kit("work", "start", "done1", env=env)
        wt = f.repo / ".worktrees" / "done1"
        (wt / "dist").mkdir()
        (wt / "dist" / "x.js").write_text("cache")
        sleeper = subprocess.Popen(["sleep", "60"])
        f.kit("work", "track", "done1", "--pid", str(sleeper.pid), "--what", "dev server", env=env)
        (wt / "feature.txt").write_text("done\n")
        Path(env["FAKE_DIR"], "pr_state").write_text("MERGED")
        r = f.kit("work", "stop", "done1", "-m", "Add the feature file for the list", "--no-checks", env=env)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        sleeper.wait(timeout=5)
        self.assertFalse(wt.exists(), "worktree and its caches removed")
        self.assertEqual(sh("git branch --list work/done1", f.repo).stdout.strip(), "", "branch removed")
        self.assertIsNotNone(sleeper.returncode, "the tracked process was stopped")
        self.assertIn("feature.txt", sh(["git", "--git-dir", str(f.remote), "ls-tree", "--name-only", "work/done1"], self.tmp).stdout)
        self.assertIn("systemctl stop app-dev.service", self.calls(env), "no worktree open: the dev stack goes off")

    def test_stop_not_merged_waits_with_an_expiry(self):
        f = Fixture(self.tmp)
        env = self.fakes()
        f.kit("work", "start", "w1", env=env)
        wt = f.repo / ".worktrees" / "w1"
        (wt / "a.txt").write_text("a\n")
        r = f.kit("work", "stop", "w1", "-m", "Add a file that waits for review", "--no-checks", env=env)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("waiting for merge", r.stdout)
        self.assertIn("gh pr create", self.calls(env))
        rec = json.loads(sh('cat "$(git rev-parse --git-dir)/kit.json"', wt).stdout)
        self.assertEqual(rec["state"], "waiting for merge")
        self.assertGreater(rec["expires_epoch"], time.time())

    def test_stop_refuses_uncommitted_work_without_a_message(self):
        f = Fixture(self.tmp)
        env = self.fakes()
        f.kit("work", "start", "m1", env=env)
        (f.repo / ".worktrees" / "m1" / "b.txt").write_text("b\n")
        r = f.kit("work", "stop", "m1", "--no-checks", env=env)
        self.assertEqual(r.returncode, 1)
        self.assertTrue((f.repo / ".worktrees" / "m1").exists())


class Sweep(WorkBase):
    def test_sweep_closes_merged_and_reports_the_budget(self):
        f = Fixture(self.tmp)
        set_yaml(f.repo, "worktrees.close_merged_on_new", "false")
        sh("git commit -qam 'adjust the fixture limits' --no-verify", f.repo, check=True)
        env = self.fakes()
        f.kit("work", "start", "z1", env=env)
        r = f.kit("work", "sweep", env=env)
        self.assertIn("worktrees\tremove\tz1", r.stdout)
        self.assertIn("leftovers:", r.stdout)
        self.assertFalse((f.repo / ".worktrees" / "z1").exists())


class Stack(WorkBase):
    def test_off_refuses_a_prod_piece(self):
        f = Fixture(self.tmp)
        env = self.fakes()
        self.manifest(f.repo)
        r = f.kit("stack", "off", "repo", "--piece", "app-prod", env=env)
        self.assertEqual(r.returncode, 1)
        self.assertIn("REFUSED", r.stdout)
        self.assertNotIn("pod stop", self.calls(env))

    def test_off_then_on_restores_the_dev_stack_healthy(self):
        f = Fixture(self.tmp)
        env = self.fakes()
        self.manifest(f.repo)
        self.assertEqual(f.kit("stack", "on", "repo", env=env).returncode, 0)
        r = f.kit("stack", "off", "repo", env=env)
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertIn("kept\trepo\tpod:app-prod\trole prod", r.stdout)
        self.assertIn("kept\trepo\tcontainer:someone-elses\trole unknown (owner another team)", r.stdout)
        st = f.kit("--json", "stack", "status", "repo", env=env).stdout
        dev = [json.loads(l) for l in st.splitlines() if json.loads(l)["role"] == "dev"]
        self.assertTrue(all(not d["running"] for d in dev))
        r = f.kit("stack", "on", "repo", env=env)
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertEqual(r.stdout.count("ok\trepo"), 2)
        st = f.kit("--json", "stack", "status", "repo", env=env).stdout
        dev = [json.loads(l) for l in st.splitlines() if json.loads(l)["role"] == "dev"]
        self.assertTrue(all(d["running"] for d in dev))
        self.assertNotIn("someone-elses", self.calls(env).replace("inspect someone-elses", ""))


class Deploy(WorkBase):
    def _deploy_cfg(self, f, extra=""):
        f.config(f"""\
            deploy:
              images:
                - {{name: localhost/app-web, context: ., purpose: product}}
              ship: ""
              hook: "{extra}"
              rollback: "echo roll back to {{previous}}"
            """)

    def test_deploy_keeps_exactly_two_tags(self):
        f = Fixture(self.tmp)
        env = self.fakes()
        self._deploy_cfg(f)
        for rel in ("1", "2", "3", "4"):
            r = f.kit("deploy", "--release", rel, env=env)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        state = json.loads(Path(env["FAKE_DIR"], "podman.json").read_text())
        tags = sorted(t for i in state["images"] for t in i["Names"])
        self.assertEqual(tags, ["localhost/app-web:3", "localhost/app-web:4"])
        self.assertTrue(all(i["Labels"].get("release") for i in state["images"]))

    def test_failed_hook_leaves_the_previous_and_prints_the_rollback(self):
        f = Fixture(self.tmp)
        env = self.fakes()
        self._deploy_cfg(f, extra="exit 3")
        set_yaml(f.repo, "deploy.hook", '""')
        f.kit("deploy", "--release", "1", env=env)
        set_yaml(f.repo, "deploy.hook", '"exit 3"')
        r = f.kit("deploy", "--release", "2", env=env)
        self.assertEqual(r.returncode, 1)
        self.assertIn("previous release keeps running", r.stdout)
        self.assertIn("roll back to 1", r.stdout)
        state = json.loads(Path(env["FAKE_DIR"], "podman.json").read_text())
        self.assertIn("localhost/app-web:1", [t for i in state["images"] for t in i["Names"]])

    def test_btrfs_picks_the_btrfs_driver_and_says_so(self):
        f = Fixture(self.tmp)
        env = self.fakes()
        env["KIT_FAKE_FS"] = "btrfs"
        self._deploy_cfg(f)
        r = f.kit("deploy", "--release", "1", env=env)
        self.assertIn("driver btrfs", r.stdout)
        self.assertIn("--storage-driver btrfs build", self.calls(env))
        env["FAKE_INFO_FAILS"] = "1"
        r = f.kit("deploy", "--release", "2", "--dry-run", env=env)
        self.assertIn("podman info failed", r.stdout)

    def test_deploy_refused_on_a_product_host_and_at_low_disk(self):
        f = Fixture(self.tmp)
        env = self.fakes()
        self._deploy_cfg(f)
        self.assertEqual(f.kit("deploy", "--release", "1", env={**env, "KIT_PRODUCT_HOST": "1"}).returncode, 1)
        r = f.kit("deploy", "--release", "1", env={**env, "KIT_FAKE_DISK": "10/1000"})
        self.assertEqual(r.returncode, 1)
        self.assertIn("below the floor", r.stdout)


if __name__ == "__main__":
    unittest.main()
