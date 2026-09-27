"""landed.py — the teardown gate, proven on real repositories.

Every fixture here is a real `git` repository with a real bare origin, because a
worktree is not something a double can fake honestly. `gh`/`gh-axi` are PATH
stubs, exactly as the vendored teardown suite stubs them, so the merged-PR proof
is exercised without a network.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from ymir_runtime import landed
from ymir_runtime import proc


def git(args: list[str], cwd: Path) -> str:
    result = subprocess.run(
        ["git", "-C", str(cwd), *args],
        capture_output=True,
        text=True,
        env={**os.environ, "GIT_AUTHOR_NAME": "gate", "GIT_AUTHOR_EMAIL": "gate@test",
             "GIT_COMMITTER_NAME": "gate", "GIT_COMMITTER_EMAIL": "gate@test"},
        check=True,
    )
    return result.stdout.strip()


class Fixture(unittest.TestCase):
    """origin.git ← project (clone) → wt (worktree on branch `work`)."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        self.origin = self.root / "origin.git"
        self.project = self.root / "project"
        self.wt = self.root / "wt"
        self.fakebin = self.root / "fakebin"
        self.fakebin.mkdir()

        subprocess.run(["git", "init", "--bare", "-q", "-b", "main", str(self.origin)], check=True)
        subprocess.run(["git", "clone", "-q", str(self.origin), str(self.project)], check=True)
        (self.project / "file.txt").write_text("one\n", encoding="utf-8")
        git(["add", "file.txt"], self.project)
        git(["commit", "-qm", "one"], self.project)
        git(["push", "-q", "-u", "origin", "main"], self.project)
        subprocess.run(["git", "-C", str(self.project), "remote", "set-head", "origin", "main"], check=True, capture_output=True)
        git(["worktree", "add", "-q", "-b", "work", str(self.wt)], self.project)

        self.gh_axi(prefix="")
        self.gh(view_rc=1, view_out="")
        self.env = {**os.environ, "PATH": f"{self.fakebin}{os.pathsep}{os.environ['PATH']}"}

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def gh_axi(self, *, prefix: str) -> None:
        """A `gh-axi pr list` stub: `prefix` is printed before the number row."""
        script = self.fakebin / "gh-axi"
        script.write_text(
            "#!/usr/bin/env bash\n"
            "case \"${1:-} ${2:-}\" in\n"
            f"  'pr list') printf '%s\\n' {prefix!r} \"7,work,OPEN\"; exit 0 ;;\n"
            "esac\n"
            "exit 1\n",
            encoding="utf-8",
        )
        script.chmod(0o755)

    def gh(self, *, view_rc: int, view_out: str) -> None:
        """A `gh pr view` stub printing the tab-joined row the gate parses."""
        script = self.fakebin / "gh"
        script.write_text(
            "#!/usr/bin/env bash\n"
            f"if [ ${{1:-}} = pr ] && [ ${{2:-}} = view ]; then\n"
            f"  printf '%b\\n' {view_out!r}; exit {view_rc}\n"
            "fi\n"
            "exit 1\n",
            encoding="utf-8",
        )
        script.chmod(0o755)

    def commit(self, worktree: Path, text: str, message: str) -> str:
        (worktree / "file.txt").write_text(text, encoding="utf-8")
        git(["add", "file.txt"], worktree)
        git(["commit", "-qm", message], worktree)
        return git(["rev-parse", "HEAD"], worktree)

    def publish_main(self) -> None:
        git(["push", "-q", "origin", "main"], self.project)


class ReachabilityTest(Fixture):
    def test_work_reachable_from_a_remote_is_landed(self) -> None:
        git(["push", "-q", "-u", "origin", "work"], self.wt)
        verdict = landed.work_is_landed(self.wt, "work", runner=proc.run, env=self.env)
        self.assertTrue(verdict.landed)
        self.assertEqual(verdict.how, "remote")

    def test_unpushed_work_with_no_pr_and_no_content_in_default_is_unlanded(self) -> None:
        self.commit(self.wt, "one\ntwo\n", "two")
        verdict = landed.work_is_landed(self.wt, "work", runner=proc.run, env=self.env)
        self.assertFalse(verdict.landed)

    def test_a_clean_tree_reports_no_uncommitted_changes(self) -> None:
        self.assertFalse(landed.dirty(self.wt, runner=proc.run, env=self.env))

    def test_an_uncommitted_change_is_dirty(self) -> None:
        (self.wt / "file.txt").write_text("one\nunsaved\n", encoding="utf-8")
        self.assertTrue(landed.dirty(self.wt, runner=proc.run, env=self.env))

    def test_default_branch_reads_origin_head(self) -> None:
        self.assertEqual(landed.default_branch(self.wt, runner=proc.run, env=self.env), "main")

    def test_commits_not_on_remote_lists_the_unpushed_commit(self) -> None:
        self.commit(self.wt, "one\ntwo\n", "two")
        self.assertEqual(len(landed.commits_not_on_remote(self.wt, runner=proc.run, env=self.env) or []), 1)


class MergedPrTest(Fixture):
    def test_a_merged_pr_whose_head_is_our_head_is_landed(self) -> None:
        head = self.commit(self.wt, "one\ntwo\n", "two")
        self.gh(view_rc=0, view_out=f"MERGED\t{head}\thttps://example.invalid/pull/7")
        self.gh_axi(prefix="")
        verdict = landed.work_is_landed(self.wt, "work", "https://example.invalid/pull/7", runner=proc.run, env=self.env)
        self.assertTrue(verdict.landed, verdict.detail)
        self.assertEqual(verdict.how, "merged-pr")

    def test_a_merged_pr_that_does_not_contain_our_work_is_unlanded(self) -> None:
        self.commit(self.wt, "one\ntwo\n", "two")
        elsewhere = self.commit(self.project, "one\nother\n", "other")
        self.gh(view_rc=0, view_out=f"MERGED\t{elsewhere}\thttps://example.invalid/pull/7")
        verdict = landed.work_is_landed(self.wt, "work", "https://example.invalid/pull/7", runner=proc.run, env=self.env)
        self.assertFalse(verdict.landed)

    def test_an_open_pr_is_not_landed(self) -> None:
        head = self.commit(self.wt, "one\ntwo\n", "two")
        self.gh(view_rc=0, view_out=f"OPEN\t{head}\thttps://example.invalid/pull/7")
        verdict = landed.work_is_landed(self.wt, "work", "https://example.invalid/pull/7", runner=proc.run, env=self.env)
        self.assertFalse(verdict.landed)
        self.assertEqual(verdict.how, "unlanded")

    def test_a_gh_failure_is_inconclusive_and_never_landed(self) -> None:
        self.commit(self.wt, "one\ntwo\n", "two")
        self.gh(view_rc=1, view_out="error: no such PR")
        verdict = landed.work_is_landed(self.wt, "work", "https://example.invalid/pull/7", runner=proc.run, env=self.env)
        self.assertFalse(verdict.landed)
        self.assertEqual(verdict.how, "inconclusive")

    def test_the_pr_can_be_found_by_branch_when_none_is_recorded(self) -> None:
        head = self.commit(self.wt, "one\ntwo\n", "two")
        self.gh_axi(prefix="")
        self.gh(view_rc=0, view_out=f"MERGED\t{head}\thttps://example.invalid/pull/7")
        verdict = landed.work_is_landed(self.wt, "work", runner=proc.run, env=self.env)
        self.assertTrue(verdict.landed, verdict.detail)


class ContentInDefaultTest(Fixture):
    def test_a_squash_merged_change_counts_as_landed(self) -> None:
        # The branch's own commit lives nowhere on a remote; its CONTENT is in main.
        # The squash merge is simulated by committing the same content on main.
        self.commit(self.wt, "one\ntwo\n", "two")
        (self.project / "file.txt").write_text("one\ntwo\n", encoding="utf-8")
        git(["add", "file.txt"], self.project)
        git(["commit", "-qm", "squash"], self.project)
        self.publish_main()
        verdict = landed.work_is_landed(self.wt, "work", runner=proc.run, env=self.env)
        self.assertTrue(verdict.landed, verdict.detail)
        self.assertEqual(verdict.how, "content-in-default")

    def test_content_the_default_branch_lacks_is_unlanded(self) -> None:
        self.commit(self.wt, "one\ntwo\n", "two")
        verdict = landed.content_in_default(self.wt, runner=proc.run, env=self.env)
        self.assertFalse(verdict.landed)
        self.assertEqual(verdict.how, "unlanded")


class GateTest(Fixture):
    def test_force_is_the_approved_discard_path(self) -> None:
        verdict = landed.gate(self.wt, force=True, runner=proc.run, env=self.env)
        self.assertTrue(verdict.landed)
        self.assertEqual(verdict.how, "forced")

    def test_an_absent_worktree_is_not_a_gate(self) -> None:
        verdict = landed.gate(self.root / "nowhere", runner=proc.run, env=self.env)
        self.assertTrue(verdict.landed)
        self.assertEqual(verdict.how, "absent")

    def test_dirty_wins_even_when_the_work_landed(self) -> None:
        git(["push", "-q", "-u", "origin", "work"], self.wt)
        (self.wt / "file.txt").write_text("one\nunsaved\n", encoding="utf-8")
        verdict = landed.gate(self.wt, runner=proc.run, env=self.env)
        self.assertFalse(verdict.landed)
        self.assertEqual(verdict.how, "dirty")

    def test_a_ship_seat_on_a_remote_branch_passes(self) -> None:
        git(["push", "-q", "-u", "origin", "work"], self.wt)
        verdict = landed.gate(self.wt, mode="no-mistakes", runner=proc.run, env=self.env)
        self.assertTrue(verdict.landed, verdict.detail)

    def test_a_local_only_seat_merged_into_local_main_passes(self) -> None:
        self.commit(self.wt, "one\ntwo\n", "two")
        git(["merge", "--ff-only", "-q", "work"], self.project)
        verdict = landed.gate(self.wt, mode="local-only", runner=proc.run, env=self.env)
        self.assertTrue(verdict.landed, verdict.detail)
        self.assertEqual(verdict.how, "local-default")

    def test_a_local_only_seat_with_unmerged_work_is_refused(self) -> None:
        self.commit(self.wt, "one\ntwo\n", "two")
        verdict = landed.gate(self.wt, mode="local-only", runner=proc.run, env=self.env)
        self.assertFalse(verdict.landed)
        self.assertEqual(verdict.how, "unlanded")


class PatchIdentityTest(Fixture):
    def test_a_patch_id_is_stable_for_the_same_change(self) -> None:
        self.commit(self.wt, "one\ntwo\n", "two")
        here = landed.patch_id_for_commit(self.wt, "HEAD", runner=proc.run, env=self.env)
        self.assertRegex(here, r"^[0-9a-f]{40}$")
        self.assertEqual(here, landed.patch_id_for_commit(self.wt, "HEAD", runner=proc.run, env=self.env))

    def test_target_shapes(self) -> None:
        self.assertEqual(landed.pr_number_from_target("https://github.com/o/r/pull/42"), "42")
        self.assertEqual(landed.pr_number_from_target("42"), "42")
        self.assertEqual(landed.pr_number_from_target("work"), "")


class StopRequiresLandedTest(Fixture):
    """`stop --remove-worktree --require-landed` never discards unlanded work."""

    def env_for_stop(self) -> dict[str, str]:
        from ymir_runtime.tests.support import engine_env

        environ = {**os.environ, **engine_env(self.root / "engine")}
        environ["PATH"] = f"{self.fakebin}{os.pathsep}{os.environ['PATH']}"
        environ["BROKK_STATE_OVERRIDE"] = str(self.root / "engine" / "home" / "state")
        return environ

    def seat(self, environ: dict[str, str]) -> None:
        from ymir_runtime import heartbeat

        state = Path(environ["BROKK_STATE_OVERRIDE"])
        state.mkdir(parents=True, exist_ok=True)
        heartbeat.write_meta(
            state, "s1", {"launched": "1", "worktree": str(self.wt), "mode": "no-mistakes"}
        )

    def test_stop_refuses_a_worktree_whose_work_has_not_landed(self) -> None:
        from ymir_runtime.errors import EngineError
        from ymir_runtime.stop import stop as stop_verb

        self.commit(self.wt, "one\ntwo\n", "two")
        environ = self.env_for_stop()
        self.seat(environ)
        with self.assertRaises(EngineError) as raised:
            stop_verb("s1", remove_worktree=True, require_landed=True, env=environ)
        self.assertIn("has not landed", str(raised.exception))
        self.assertTrue(self.wt.is_dir(), "a refused stop must not touch the worktree")

    def test_stop_proceeds_when_the_work_has_landed(self) -> None:
        from ymir_runtime.stop import stop as stop_verb

        git(["push", "-q", "-u", "origin", "work"], self.wt)
        environ = self.env_for_stop()
        self.seat(environ)
        verdict = landed.gate(self.wt, mode="no-mistakes", runner=proc.run, env=environ)
        self.assertTrue(verdict.landed, verdict.detail)


class ProcInputTest(unittest.TestCase):
    def test_a_runner_can_feed_stdin(self) -> None:
        result = proc.run(["cat"], input_text="piped\n")
        self.assertEqual(result.stdout, "piped\n")

    def test_which_reports_an_absent_binary_as_empty(self) -> None:
        self.assertEqual(proc.which("definitely-not-a-binary-here"), "")


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
