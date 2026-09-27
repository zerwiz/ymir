"""paths.py — the home law, read once."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from ymir_runtime import paths


class ResolveTest(unittest.TestCase):
    def test_env_wins_over_everything(self) -> None:
        env = {
            "YMIR_HOME": "/tmp/h",
            "YMIR_HOARD": "/tmp/hoard",
            "YMIR_STATE_DIR": "/tmp/st",
            "YMIR_DATA_DIR": "/tmp/dt",
            "YMIR_SETTINGS_DIR": "/tmp/cf",
            "BROKK_ROOT_OVERRIDE": "/tmp/root",
        }
        roots = paths.resolve(env)
        self.assertEqual(roots.home, Path("/tmp/h"))
        self.assertEqual(roots.hoard, Path("/tmp/hoard"))
        self.assertEqual(roots.state, Path("/tmp/st"))
        self.assertEqual(roots.data, Path("/tmp/dt"))
        self.assertEqual(roots.config, Path("/tmp/cf"))
        self.assertEqual(roots.root, Path("/tmp/root"))
        self.assertEqual(roots.wt_root, Path("/tmp/root/.yggdrasil"))

    def test_recorded_home_is_read_when_env_is_unset(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp) / "ymir"
            config.mkdir()
            (config / "home").write_text("/tmp/recorded\n", encoding="utf-8")
            roots = paths.resolve({"YMIR_CONFIG_DIR": str(config)})
            self.assertEqual(roots.home, Path("/tmp/recorded"))
            self.assertEqual(roots.hoard, Path("/tmp/recorded/hodd"))
            self.assertEqual(roots.state, Path("/tmp/recorded/state"))
            self.assertEqual(roots.data, Path("/tmp/recorded/hodd/data"))

    def test_default_home_when_nothing_is_recorded(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            roots = paths.resolve({"YMIR_CONFIG_DIR": str(Path(tmp) / "absent")})
            self.assertEqual(roots.home, Path("~/Documents/ymirhome").expanduser())

    def test_brokk_overrides_beat_ymir_env(self) -> None:
        env = {
            "YMIR_HOME": "/tmp/h",
            "YMIR_STATE_DIR": "/tmp/st",
            "BROKK_STATE_OVERRIDE": "/tmp/seat-state",
            "BROKK_DATA_OVERRIDE": "/tmp/seat-data",
        }
        roots = paths.resolve(env)
        self.assertEqual(roots.state, Path("/tmp/seat-state"))
        self.assertEqual(roots.data, Path("/tmp/seat-data"))

    def test_repo_root_is_derived_from_the_package_when_env_is_absent(self) -> None:
        root = paths.repo_root({}, module_file="/repo/src/ymir_runtime/paths.py")
        self.assertEqual(root, Path("/repo"))

    def test_the_engine_root_wins_over_brokk_home(self) -> None:
        env = {"YMIR_ENGINE_ROOT": "/code", "BROKK_HOME": "/home-of-worktrees"}
        self.assertEqual(paths.repo_root(env), Path("/code"))
        self.assertEqual(paths.resolve(env).wt_root, Path("/home-of-worktrees/.yggdrasil"))

    def test_wt_root_follows_brokk_home_not_the_code_root(self) -> None:
        env = {"YMIR_ENGINE_ROOT": "/code", "BROKK_ROOT_OVERRIDE": "/project"}
        roots = paths.resolve(env)
        self.assertEqual(roots.root, Path("/code"))
        self.assertEqual(roots.wt_root, Path("/project/.yggdrasil"))

    def test_brokk_wt_root_is_the_last_word(self) -> None:
        env = {"BROKK_HOME": "/home1", "BROKK_WT_ROOT": "/elsewhere"}
        self.assertEqual(paths.resolve(env).wt_root, Path("/elsewhere"))


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
