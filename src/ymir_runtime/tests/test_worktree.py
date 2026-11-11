"""worktree.py — Yggdrasil, against a real git repo."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from ymir_runtime import worktree
from ymir_runtime.errors import EngineError
from ymir_runtime.tests.support import make_repo


class EnsureTest(unittest.TestCase):
    def test_creates_a_detached_worktree_at_the_expected_path(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo = make_repo(root / "repo")
            wt_root = repo / ".yggdrasil"
            made = worktree.ensure("errand-one", repo, wt_root)
            self.assertTrue(made.created)
            self.assertEqual(made.path, wt_root / "errand-one")
            self.assertTrue((made.path / "README.md").is_file())
            self.assertTrue(made.head)

    def test_reuses_a_worktree_that_already_stands(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo = make_repo(root / "repo")
            wt_root = repo / ".yggdrasil"
            first = worktree.ensure("errand-two", repo, wt_root)
            second = worktree.ensure("errand-two", repo, wt_root)
            self.assertTrue(first.created)
            self.assertFalse(second.created)
            self.assertEqual(first.path, second.path)

    def test_a_new_worktree_carries_no_second_extension_tree(self) -> None:
        """RULES/13: one extension home. A worktree that copies the project's
        `.pi/extensions/` makes pi load every tool twice and refuse to start — the
        seat then never stands, and a seat that never stands reads as `working`.
        Measured 2026-11-08: three errands died this way and no judge could seat."""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo = make_repo(root / "repo")
            ext = repo / ".pi" / "extensions" / "demo"
            ext.mkdir(parents=True)
            (ext / "index.ts").write_text("export default {}\n")
            (repo / ".pi" / "extensions" / "README.md").write_text("the project's own\n")
            import subprocess
            subprocess.run(["git", "-C", str(repo), "add", "-A"], check=True)
            subprocess.run(["git", "-C", str(repo), "commit", "-qm", "an extension tree"], check=True)

            made = worktree.ensure("errand-ext", repo, repo / ".yggdrasil")
            self.assertFalse((made.path / ".pi" / "extensions").exists(),
                             "the worktree must not carry a second extension tree")
            # AND THE TREE MUST BE CLEAN. A directory removed behind git's back leaves
            # every file reported DELETED — `--assume-unchanged` is a per-FILE bit and
            # does nothing for a directory, so the old shape was green in this ward and
            # dirty in every worker's `git status` (Forseti, PR #639 follow-up). The
            # ward now fails on the fault it could not see, and a worker's `git add -A`
            # can no longer delete the extension tree from the repository.
            status = subprocess.run(
                ["git", "-C", str(made.path), "status", "--porcelain"],
                capture_output=True, text=True, check=True,
            )
            self.assertEqual(status.stdout.strip(), "",
                             f"the worktree must be clean after the exclusion, got:\n{status.stdout}")
            self.assertTrue((repo / ".pi" / "extensions" / "demo" / "index.ts").exists(),
                            "the project's own tree is untouched")

    def test_refuses_a_directory_that_is_not_a_worktree(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo = make_repo(root / "repo")
            wt_root = repo / ".yggdrasil"
            (wt_root / "squatter").mkdir(parents=True)
            with self.assertRaises(EngineError) as caught:
                worktree.ensure("squatter", repo, wt_root)
            self.assertIn("not a Yggdrasil worktree", str(caught.exception))

    def test_refuses_a_project_that_is_not_a_git_tree(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            plain = root / "plain"
            plain.mkdir()
            with self.assertRaises(EngineError) as caught:
                worktree.ensure("x", plain, root / "wt")
            self.assertIn("not a git working tree", str(caught.exception))

    def test_remove_reaps_the_worktree(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo = make_repo(root / "repo")
            wt_root = repo / ".yggdrasil"
            made = worktree.ensure("errand-three", repo, wt_root)
            self.assertTrue(worktree.remove("errand-three", repo, wt_root, force=True))
            self.assertFalse(made.path.exists())


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
