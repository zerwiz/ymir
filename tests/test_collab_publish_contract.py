"""collab publish through the board contract (plan 335, the split): no engine's API, only the `mcp` adapter.

A dry run lists what it would file and writes nothing; --yes files each bullet once, labelled `baton`, in the
`unstarted` group, with its source; a second run files none; a project with no board: block is refused by name;
the token never appears in the output.
"""
import os
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from test_plan_sync import Board, serve  # noqa: E402  (the stub board, one copy)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DOOR = os.path.join(ROOT, "bin", "collab", "collab.sh")


class SourcedBoard(Board):
    """The stub, plus the `source` a board that asks for provenance is given."""

    def tool(self, name, a):
        if name == "create_card":
            self.sources = getattr(self, "sources", []) + [a.get("source")]
        return super().tool(name, a)


class PublishContract(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = os.path.join(self.tmp.name, "home")
        self.repo = os.path.join(self.tmp.name, "demo")
        self.board = SourcedBoard()
        self.board.cards.append(dict(card=1, title="Already on the board", state="Next", labels=[], description=""))
        self.board.seq = 1
        self.srv = serve(self.board)
        os.makedirs(os.path.join(self.home, "hodd", "identity"))
        open(os.path.join(self.home, "hodd", "identity", "projects.yaml"), "w").write(
            "projects:\n- id: demo\n  board:\n    adapter: mcp\n    place: acme/Demo\n"
            f"    mcp:\n      url: http://127.0.0.1:{self.srv.server_port}/mcp\n      token_from: env:PS_TOKEN\n"
            "- id: bare\n  name: Bare\n")
        os.makedirs(os.path.join(self.repo, "handoff"))
        open(os.path.join(self.repo, "handoff", "CURRENT.md"), "w").write(
            "# Baton\n\n**Date:** 2026-11-20\n\n## 3 · What is next\n- Write the first page\n- Already on the board\n"
            "## 4 · What is blocked, and on whom\n- Waiting on the reviewer\n")

    def tearDown(self):
        self.srv.shutdown()
        self.tmp.cleanup()

    def publish(self, *extra, project="demo", rc=0):
        env = dict(os.environ, YMIR_HOME=self.home, PS_TOKEN="s3cret")
        r = subprocess.run(["bash", DOOR, "publish", self.repo, "--project", project, *extra],
                           capture_output=True, text=True, env=env)
        self.assertEqual(r.returncode, rc, r.stdout + r.stderr)
        self.assertNotIn("s3cret", r.stdout + r.stderr)
        return r.stdout + r.stderr

    def test_dry_run_writes_nothing_and_skips_what_is_there(self):
        out = self.publish("--dry-run")
        self.assertIn("would create 2, skipped 1", out)
        self.assertIn("acme/Demo (mcp adapter)", out)
        self.assertNotIn("create_card", self.board.calls)
        self.assertNotIn("create_label", self.board.calls)

    def test_yes_files_each_bullet_once_with_label_group_and_source(self):
        self.assertIn("created 2, skipped 1", self.publish("--yes"))
        made = [c for c in self.board.cards if "baton" in c["labels"]]
        self.assertEqual({c["title"] for c in made}, {"Write the first page", "Waiting on the reviewer"})
        self.assertTrue(all(c["state"] == "Next" for c in made))  # the board's name for `unstarted`
        self.assertEqual(sorted(self.board.sources), ["handoff/CURRENT.md#s3-1", "handoff/CURRENT.md#s4-1"])
        self.assertIn("created 0, skipped 3", self.publish("--yes"))

    def test_a_project_with_no_board_block_is_refused_by_name(self):
        out = self.publish("--dry-run", project="bare", rc=1)
        self.assertIn("has no board: block", out)


if __name__ == "__main__":
    unittest.main()
