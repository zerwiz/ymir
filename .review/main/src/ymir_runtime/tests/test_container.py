"""container.py — the sandbox decision, and the refusals it must make."""

from __future__ import annotations

import unittest

from ymir_runtime import container
from ymir_runtime.tests.support import Recorder, completed


class DeclaredFromBriefTest(unittest.TestCase):
    def test_herdr_declaration(self) -> None:
        declared, reason = container.declared_from_brief("Isolation: herdr — the ordinary road\n")
        self.assertEqual(declared, "herdr")
        self.assertEqual(reason, "the ordinary road")

    def test_commented_and_indented_declaration(self) -> None:
        declared, reason = container.declared_from_brief("  # Isolation: utgard — untrusted input\n")
        self.assertEqual(declared, "utgard")
        self.assertEqual(reason, "untrusted input")

    def test_absent_declaration_defaults_to_herdr(self) -> None:
        declared, reason = container.declared_from_brief("# Task\nnothing here\n")
        self.assertEqual(declared, "herdr")
        self.assertIn("no Isolation: line", reason)

    def test_unknown_word_falls_back_to_herdr_and_says_so(self) -> None:
        declared, reason = container.declared_from_brief("Isolation: vm — somewhere\n")
        self.assertEqual(declared, "herdr")
        self.assertIn("unrecognized", reason)


class PlanTest(unittest.TestCase):
    def test_herdr_is_supported(self) -> None:
        plan = container.plan(declared="herdr", probe=lambda name: "", runner=Recorder())
        self.assertTrue(plan.supported)
        self.assertEqual(plan.effective, "off")
        self.assertFalse(plan.sandboxed)

    def test_utgard_without_an_engine_is_a_loud_refusal(self) -> None:
        plan = container.plan(declared="utgard", probe=lambda name: "", runner=Recorder())
        self.assertFalse(plan.supported)
        self.assertIn("neither docker nor podman", plan.refusal)

    def test_utgard_without_the_image_is_a_loud_refusal(self) -> None:
        probe = lambda name: "/usr/bin/docker" if name == "docker" else ""  # noqa: E731
        runner = Recorder(responses={"docker image inspect": completed(1, "", "no such image")})
        plan = container.plan(declared="utgard", probe=probe, runner=runner)
        self.assertFalse(plan.supported)
        self.assertIn("utgard-runner:latest", plan.refusal)

    def test_utgard_with_engine_and_image_is_still_a_refusal_in_phase_one(self) -> None:
        probe = lambda name: "/usr/bin/docker" if name == "docker" else ""  # noqa: E731
        runner = Recorder(responses={"docker image inspect": completed(0, "[]", "")})
        plan = container.plan(declared="utgard", probe=probe, runner=runner)
        self.assertFalse(plan.supported)
        self.assertIn("does not launch the Utgard sandbox yet", plan.refusal)

    def test_isolation_off_over_a_declared_utgard_is_refused(self) -> None:
        plan = container.plan(declared="utgard", override="off", probe=lambda name: "", runner=Recorder())
        self.assertFalse(plan.supported)
        self.assertIn("never silently downgraded", plan.refusal)

    def test_isolation_on_forces_the_sandbox_and_is_refused(self) -> None:
        plan = container.plan(declared="herdr", override="on", probe=lambda name: "", runner=Recorder())
        self.assertFalse(plan.supported)
        self.assertEqual(plan.declared, "utgard")


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
