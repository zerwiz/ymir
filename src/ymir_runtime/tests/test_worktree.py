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
