"""The worktree reaper (plan 339.4): the road that made a worktree reaps it.

Every test is FENCED: HOME, YMIR_HOME, the ledger, the state shelf and the walked repository
all point into a temporary directory, so no sweep here can see — let alone remove — a real
worktree on the machine running the test.
"""
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REAPER = Path(__file__).resolve().parents[1] / "bin/forge/worktree-reap.py"
DAY = 86400
GIT_ID = ("-c", "user.email=t@example.org", "-c", "user.name=t", "-c", "commit.gpgsign=false")


def sh(*argv, cwd=None):
    return subprocess.run(argv, cwd=cwd, check=True, capture_output=True, text=True).stdout.strip()


class Reaper(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = Path(self.tmp.name)
        self.origin = t / "origin.git"
        self.repo = t / "repo"
        self.state = t / "state"
        self.state.mkdir()
        (t / "home").mkdir()
        sh("git", "init", "-q", "--bare", "-b", "main", str(self.origin))
        sh("git", "init", "-q", "-b", "main", str(self.repo))
        (self.repo / "a.txt").write_text("a\n")
        sh("git", "add", "a.txt", cwd=self.repo)
        sh("git", *GIT_ID, "commit", "-q", "-m", "base", cwd=self.repo)
        sh("git", "remote", "add", "origin", str(self.origin), cwd=self.repo)
        sh("git", "push", "-q", "-u", "origin", "main", cwd=self.repo)
        sh("git", "remote", "set-head", "origin", "main", cwd=self.repo)
        self.env = {
            **os.environ,
            "HOME": str(t / "home"),
            "YMIR_HOME": str(t / "home" / "ymirhome"),
            "YMIR_WORKTREE_LEDGER": str(t / "ledger"),
            "YMIR_WORKTREE_ROOTS": str(t / "roots.yaml"),
            "YMIR_WORKTREE_REPO": str(self.repo),
            "BROKK_STATE_OVERRIDE": str(self.state),
            "YMIR_WORKTREE_AGENT_PROBE": "off",
        }
        self.env.pop("YMIR_WORKTREE_REAP", None)
        self.env.pop("YMIR_WORKTREE_NOW", None)

    def tearDown(self):
        self.tmp.cleanup()

    def run_reaper(self, *args, now=None):
        env = dict(self.env)
        if now is not None:
            env["YMIR_WORKTREE_NOW"] = str(now)
        r = subprocess.run([sys.executable, str(REAPER), *args], env=env, capture_output=True, text=True,
                           cwd=self.tmp.name)
        self.assertEqual(r.returncode, 0, r.stderr)
        return r.stdout

    def errand(self, name, commit=False, status=None):
        wt = self.repo / ".yggdrasil" / name
        wt.parent.mkdir(parents=True, exist_ok=True)
        sh("git", "worktree", "add", "-q", "-b", f"eindri/{name}", str(wt), "origin/main", cwd=self.repo)
        if commit:
            (wt / f"{name}.txt").write_text(name + "\n")
            sh("git", "add", f"{name}.txt", cwd=wt)
            sh("git", *GIT_ID, "commit", "-q", "-m", name, cwd=wt)
        self.run_reaper("record", "--path", str(wt), "--errand", name, "--owner", "sindri", "--road", "test")
        if status:
            (self.state / f"{name}.status").write_text(f"working: launched\n{status}\n")
        return wt

    def branch_exists(self, name):
        return subprocess.run(["git", "show-ref", "--verify", "--quiet", f"refs/heads/eindri/{name}"],
                              cwd=self.repo).returncode == 0

    def test_done_and_merged_is_reaped_and_its_branch_stays(self):
        wt = self.errand("landed", status="done: committed")
        dry = self.run_reaper("sweep")
        self.assertIn('"reap:done-merged","landed"', dry)
        self.assertTrue(wt.exists(), "a dry run removes nothing")
        self.run_reaper("sweep", "--apply")
        self.assertFalse(wt.exists())
        self.assertTrue(self.branch_exists("landed"), "branches are never deleted")

    def test_done_but_unlanded_is_kept_and_named(self):
        wt = self.errand("unlanded", commit=True, status="done: committed on eindri/unlanded (not pushed)")
        out = self.run_reaper("sweep", "--apply")
        self.assertIn('"keep:done-unlanded","unlanded"', out)
        self.assertTrue(wt.exists())

    def test_done_and_pushed_is_reaped(self):
        wt = self.errand("pushed", commit=True, status="done: pushed")
        sh("git", "push", "-q", "origin", "eindri/pushed", cwd=wt)
        self.assertIn('"reap:done-pushed","pushed"', self.run_reaper("sweep"))
        self.run_reaper("sweep", "--apply")
        self.assertFalse(wt.exists())
        self.assertTrue(self.branch_exists("pushed"))

    def test_done_and_parked_is_reaped(self):
        wt = self.errand("parked", commit=True, status="done: parked")
        sh("git", "push", "-q", "origin", "HEAD:refs/parked/parked", cwd=wt)
        self.assertIn('"reap:done-parked","parked"', self.run_reaper("sweep"))

    def test_dirty_tree_is_never_removed_even_when_closed(self):
        wt = self.errand("dirty", status="done: committed")
        (wt / "scratch.txt").write_text("uncommitted\n")
        out = self.run_reaper("sweep", "--apply")
        self.assertIn('"keep:dirty","dirty"', out)
        self.assertTrue((wt / "scratch.txt").exists())
        quiet = self.run_reaper("sweep", "--quiet")
        self.assertIn("dirty (named, never removed): " + str(wt), quiet)

    def test_failed_is_held_seven_days_then_reaped(self):
        wt = self.errand("broke", commit=True, status="failed: the pane held no agent")
        closed = (self.state / "broke.status").stat().st_mtime
        held = self.run_reaper("sweep", "--apply", now=closed + 3 * DAY)
        self.assertIn('"keep:failed-held","broke"', held)
        self.assertTrue(wt.exists())
        gone = self.run_reaper("sweep", "--apply", now=closed + 8 * DAY)
        self.assertIn("removed:", gone)
        self.assertFalse(wt.exists())
        self.assertTrue(self.branch_exists("broke"), "a failed errand's branch is kept")

    def test_open_errand_and_recordless_tree_are_kept(self):
        a = self.errand("busy", status="working: writing tests")
        b = self.errand("nostatus")
        self.run_reaper("sweep", "--apply")
        self.assertTrue(a.exists() and b.exists())

    def test_exterior_root_is_reaped_by_configuration(self):
        hands = Path(self.tmp.name) / "hands"
        (Path(self.tmp.name) / "roots.yaml").write_text(
            f"roots:\n  - path: {hands}\n    owner: outer-worker\n    rule: landed\n")
        wt = hands / "hand-1"
        wt.parent.mkdir(parents=True)
        sh("git", "worktree", "add", "-q", "--detach", str(wt), "origin/main", cwd=self.repo)
        out = self.run_reaper("sweep")
        self.assertIn('"reap:landed-merged","hand-1","unrecorded","outer-worker"', out)
        self.run_reaper("sweep", "--apply")
        self.assertFalse(wt.exists())

    def test_vanished_folder_is_forgotten(self):
        wt = self.errand("vanished", status="done: x")
        sh("git", "worktree", "remove", "--force", str(wt), cwd=self.repo)
        self.assertIn('"forget","vanished"', self.run_reaper("sweep"))
        self.run_reaper("sweep", "--apply")
        self.assertNotIn("vanished", self.run_reaper("list"))

    def test_kill_switch_makes_apply_a_dry_run(self):
        wt = self.errand("switched", status="done: committed")
        self.env["YMIR_WORKTREE_REAP"] = "off"
        out = self.run_reaper("sweep", "--apply")
        self.assertIn("dry-run (YMIR_WORKTREE_REAP=off)", out)
        self.assertTrue(wt.exists())

    def test_record_keeps_owner_errand_and_road(self):
        self.errand("recorded")
        self.assertIn('"recorded","test","sindri","eindri/recorded"', self.run_reaper("list"))


if __name__ == "__main__":
    unittest.main()
