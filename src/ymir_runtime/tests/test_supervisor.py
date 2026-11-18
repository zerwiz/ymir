"""supervisor.py — Sýn's mind: measure → judge → act → prove → record.

The loop's contract, asserted without a container, a model or an arm: every door is
a parameter, so what is proven here is the DECISION — which verb may run on which
surface, when the arm is required, what happens when the proof fails, and what a
refusal does (nothing, loudly).
"""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from ymir_runtime import supervisor
from ymir_runtime.tests.support import Recorder, engine_env, completed


def surface(name: str, state: str = "down", criticality: str = "wanted") -> supervisor.Surface:
    return supervisor.Surface(
        service_id=name.replace("-", "_"), container=name, criticality=criticality, state=state
    )


def measurement(*surfaces: supervisor.Surface, host: str = "testhost") -> supervisor.Measurement:
    return supervisor.Measurement(
        host=host,
        machine=(("memory-available", "60% of 16000 MiB"), ("load-1m", "0.4 of 8 cpu")),
        surfaces=tuple(surfaces),
        audit="registry-audit: 1 running · 1 named · 0 unnamed · 0 named-but-not-running",
        registry="/tmp/services.yaml",
    )


def verdict(verb: str, target: str, reason: str = "the runbook says so") -> supervisor.Verdict:
    return supervisor.Verdict(
        verb=verb, target=target, runbook="the-supervisor.md", reason=reason,
        needs_allfather=verb == "escalate",
    )


class MeasureTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def registry(self, host: str, criticality: str = "wanted") -> Path:
        path = self.tmp / "services.yaml"
        path.write_text(
            "host: %s\nservices:\n"
            "  - id: probe\n    host: %s\n    containers: [probe-one, probe-two]\n"
            "    criticality: %s\n"
            % (host, host, criticality),
            encoding="utf-8",
        )
        return path

    def test_memory_swap_and_load_are_measured_from_the_cheap_reads(self) -> None:
        meminfo = self.tmp / "meminfo"
        meminfo.write_text(
            "MemTotal:       16000000 kB\n"
            "MemAvailable:    8000000 kB\n"
            "SwapTotal:       4000000 kB\n"
            "SwapFree:        1000000 kB\n",
            encoding="utf-8",
        )
        loadavg = self.tmp / "loadavg"
        loadavg.write_text("0.50 0.40 0.30 1/100 4242\n", encoding="utf-8")
        facts = dict(supervisor.machine_facts(meminfo=meminfo, loadavg=loadavg, cpu_count=8))
        self.assertEqual(facts["memory-available"], "50% of 15625 MiB")
        self.assertEqual(facts["swap-used"], "75% of 3906 MiB")
        self.assertEqual(facts["load-1m"], "0.50 of 8 cpu")

    def test_a_registry_for_another_host_names_no_surface_of_this_seat(self) -> None:
        measured = supervisor.measure(
            registry=self.registry("elsewhere"),
            host="testhost",
            facts=(("load-1m", "0.1 of 2 cpu"),),
            audit="registry-audit: 0 running · 2 named",
            docker_states={},
        )
        self.assertEqual(measured.surfaces, ())
        self.assertIn("elsewhere", measured.note)
        self.assertIn("testhost", measured.note)

    def test_a_container_down_in_this_hosts_registry_is_the_fault(self) -> None:
        measured = supervisor.measure(
            registry=self.registry("testhost"),
            host="testhost",
            facts=(("load-1m", "0.1 of 2 cpu"),),
            audit="registry-audit: 1 running · 2 named",
            docker_states={"probe-one": "down", "probe-two": "up"},
        )
        self.assertEqual([s.container for s in measured.faulted], ["probe-one"])
        self.assertTrue(measured.surfaces[0].actable)
        always = supervisor.measure(
            registry=self.registry("testhost", "always"),
            host="testhost",
            facts=(("load-1m", "0.1 of 2 cpu"),),
            audit="registry-audit: 1 running · 2 named",
            docker_states={"probe-one": "down", "probe-two": "up"},
        )
        self.assertFalse(always.surfaces[0].actable)

    def test_an_unreadable_state_is_not_a_fault(self) -> None:
        measured = supervisor.measure(
            registry=self.registry("testhost"),
            host="testhost",
            facts=(("load-1m", "0.1 of 2 cpu"),),
            audit="registry-audit: unmeasured",
            docker_states={},
        )
        self.assertEqual({s.state for s in measured.surfaces}, {"unknown"})
        self.assertEqual(measured.faulted, ())


class VerdictTestCase(unittest.TestCase):
    def test_json_is_read_through_the_harness_noise(self) -> None:
        text = (
            "[constellation] mesh: unconfigured\n"
            '{"verb": "start-container", "target": "probe-one", '
            '"runbook": "the-supervisor.md", "reason": "container is down", "needs_allfather": false}'
        )
        parsed = supervisor.parse_verdict(text)
        self.assertEqual(parsed.verb, "start-container")
        self.assertEqual(parsed.target, "probe-one")
        self.assertFalse(parsed.needs_allfather)

    def test_escalate_always_needs_the_allfather(self) -> None:
        parsed = supervisor.parse_verdict('{"verb": "escalate", "target": "gate"}')
        self.assertTrue(parsed.needs_allfather)

    def test_a_verb_the_house_does_not_name_is_refused(self) -> None:
        with self.assertRaises(supervisor.SupervisorRefused) as caught:
            supervisor.parse_verdict('{"verb": "docker-rm-rf", "target": "probe-one"}')
        self.assertIn("docker-rm-rf", str(caught.exception))

    def test_no_json_is_a_refusal_not_a_guess(self) -> None:
        with self.assertRaises(supervisor.SupervisorRefused):
            supervisor.parse_verdict("I think it is probably fine.")


class CycleTestCase(unittest.TestCase):
    """The five steps, with every door a parameter."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.env = engine_env(self.tmp)
        self.root = self.tmp / "repo"
        (self.root / "bin" / "records").mkdir(parents=True, exist_ok=True)
        (self.root / "bin" / "records" / "runes-append.sh").write_text("#!/bin/sh\nexit 0\n")
        (self.root / "bin" / "voice").mkdir(parents=True, exist_ok=True)
        (self.root / "bin" / "voice" / "rodd-arm.sh").write_text("#!/bin/sh\nexit 0\n")
        self.fixes = self.tmp / "home" / "hodd" / "machines" / "testhost" / "fixes.md"
        self.index = self.tmp / "runbooks.md"
        self.index.write_text("| when | open |\n|---|---|\n| a container is down | the-supervisor.md |\n")
        self.judge_door = self.tmp / "judge.sh"
        self.judge_door.write_text("#!/bin/sh\nexit 0\n")

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def cycle(self, before, after, verdict_value, *, arm=(True, "arm held"), runner=None, dry_run=False):
        measurements = [before, after]

        def measure_fn(**_kwargs):
            return measurements.pop(0) if measurements else after

        return supervisor.cycle(
            registry=self.tmp / "services.yaml",
            host="testhost",
            root=self.root,
            fixes_path=self.fixes,
            index_path=self.index,
            judge_door=self.judge_door,
            state_dir=self.tmp / "state",
            dry_run=dry_run,
            measure_fn=measure_fn,
            judge_fn=lambda *_a, **_k: verdict_value,
            arm_fn=lambda **_k: arm,
            runner=runner or Recorder(responses={}, default=completed(0)),
        )

    def test_the_whole_loop_finds_judges_acts_proves_and_records(self) -> None:
        before = measurement(surface("probe-one", "down"), surface("probe-two", "up"))
        after = measurement(surface("probe-one", "up"), surface("probe-two", "up"))
        recorder = Recorder(responses={}, default=completed(0))
        outcome = self.cycle(before, after, verdict("start-container", "probe-one"), runner=recorder)

        self.assertTrue(outcome.acted)
        self.assertTrue(outcome.proved)
        self.assertTrue(outcome.recorded)
        self.assertEqual(outcome.refused, "")
        argv = [" ".join(call) for call in recorder.calls]
        self.assertIn("docker start probe-one", argv)
        self.assertTrue(any("runes-append.sh" in line for line in argv))
        body = self.fixes.read_text(encoding="utf-8")
        self.assertIn("start-container probe-one", body)
        self.assertIn("probe-one=up", body)
        self.assertIn("proved", body)

    def test_the_proof_that_fails_is_recorded_loudly(self) -> None:
        before = measurement(surface("probe-one", "down"))
        after = measurement(surface("probe-one", "down"))
        outcome = self.cycle(before, after, verdict("start-container", "probe-one"))
        self.assertTrue(outcome.acted)
        self.assertFalse(outcome.proved)
        self.assertTrue(outcome.recorded)
        self.assertIn("FAILED", self.fixes.read_text(encoding="utf-8"))

    def test_a_surface_marked_always_is_escalated_not_acted_on(self) -> None:
        before = measurement(surface("gimle-gate", "down", criticality="always"))
        recorder = Recorder(responses={}, default=completed(0))
        outcome = self.cycle(before, before, verdict("start-container", "gimle-gate"), runner=recorder)
        self.assertFalse(outcome.acted)
        self.assertTrue(outcome.escalated)
        self.assertIn("the Allfather's", outcome.detail)
        self.assertEqual([call for call in recorder.calls if "docker" in call], [])
        wake = (self.tmp / "state" / ".wake-queue").read_text(encoding="utf-8")
        self.assertIn("check: syn-supervisor", wake)
        self.assertIn("gimle-gate — container — down", wake)

    def test_no_arm_means_no_act(self) -> None:
        before = measurement(surface("probe-one", "down"))
        recorder = Recorder(responses={}, default=completed(0))
        outcome = self.cycle(
            before, before, verdict("start-container", "probe-one"),
            arm=(False, "no arm is held — a supervisor with no authority does not act"),
            runner=recorder,
        )
        self.assertFalse(outcome.acted)
        self.assertIn("no arm is held", outcome.refused)
        self.assertEqual([call for call in recorder.calls if "docker" in call], [])
        self.assertFalse(self.fixes.exists())

    def test_a_target_outside_the_measurement_is_refused(self) -> None:
        before = measurement(surface("probe-one", "down"))
        outcome = self.cycle(before, before, verdict("start-container", "someone-elses-db"))
        self.assertFalse(outcome.acted)
        self.assertIn("does not", outcome.refused)

    def test_a_verb_whose_road_does_not_fit_the_surface_is_refused(self) -> None:
        before = measurement(surface("probe-one", "down"))
        recorder = Recorder(responses={}, default=completed(0))
        outcome = self.cycle(before, before, verdict("start-unit", "probe-one"), runner=recorder)
        self.assertFalse(outcome.acted)
        self.assertIn("does not fit", outcome.refused)
        self.assertEqual(
            [call for call in recorder.calls if "systemctl" in call or "docker" in call], []
        )

    def test_a_unit_surface_takes_the_unit_road(self) -> None:
        unit = supervisor.Surface(
            service_id="desk", container="gna-desk.service", criticality="wanted",
            state="down", kind="unit",
        )
        before = measurement(unit)
        after = measurement(
            supervisor.Surface(
                service_id="desk", container="gna-desk.service", criticality="wanted",
                state="up", kind="unit",
            )
        )
        recorder = Recorder(responses={}, default=completed(0))
        outcome = self.cycle(before, after, verdict("start-unit", "gna-desk.service"), runner=recorder)
        self.assertTrue(outcome.acted)
        self.assertTrue(outcome.proved)
        self.assertIn("systemctl --user start gna-desk.service", [" ".join(c) for c in recorder.calls])

    def test_escalation_acts_on_nothing_and_says_it_once(self) -> None:
        before = measurement(surface("gimle-share", "down", criticality="always"))
        recorder = Recorder(responses={}, default=completed(0))
        outcome = self.cycle(before, before, verdict("escalate", "gimle-share"), runner=recorder)
        self.assertFalse(outcome.acted)
        self.assertTrue(outcome.escalated)
        self.assertIn("Allfather", outcome.detail)
        self.assertEqual([call for call in recorder.calls if "docker" in call], [])
        wake = (self.tmp / "state" / ".wake-queue").read_text(encoding="utf-8")
        self.assertEqual(wake.count("check: syn-supervisor"), 1)

    def test_a_dry_run_judges_but_acts_on_nothing(self) -> None:
        before = measurement(surface("probe-one", "down"))
        recorder = Recorder(responses={}, default=completed(0))
        outcome = self.cycle(
            before, before, verdict("start-container", "probe-one"), runner=recorder, dry_run=True
        )
        self.assertTrue(outcome.acted)
        self.assertFalse(outcome.proved)
        self.assertEqual([call for call in recorder.calls if "docker" in call], [])
        self.assertIn("dry run", outcome.detail)

    def test_nothing_faulted_is_an_idle_pass(self) -> None:
        before = measurement(surface("probe-one", "up"))
        outcome = self.cycle(before, before, verdict("none", ""))
        self.assertFalse(outcome.acted)
        self.assertEqual(outcome.refused, "")
        self.assertFalse(self.fixes.exists())

    def test_the_judge_reading_no_verb_is_a_refusal(self) -> None:
        before = measurement(surface("probe-one", "down"))

        def measure_fn(**_kwargs):
            return before

        def judge_fn(*_a, **_k):
            raise supervisor.SupervisorRefused("the judge named the verb `nuke`, which is not in the house's vocabulary")

        outcome = supervisor.cycle(
            registry=self.tmp / "services.yaml", host="testhost", root=self.root,
            fixes_path=self.fixes, index_path=self.index, judge_door=self.judge_door,
            state_dir=self.tmp / "state",
            measure_fn=measure_fn, judge_fn=judge_fn,
            arm_fn=lambda **_k: (True, "arm held"),
            runner=Recorder(responses={}, default=completed(0)),
        )
        self.assertFalse(outcome.acted)
        self.assertIn("nuke", outcome.refused)

    def test_the_prompt_carries_the_measurement_the_library_and_the_verbs(self) -> None:
        before = measurement(surface("probe-one", "down"))
        prompt = supervisor.judging_prompt(before, "| a container is down | the-supervisor.md |")
        self.assertIn("probe-one — container — down — criticality: wanted", prompt)
        self.assertIn("the-supervisor.md", prompt)
        self.assertIn("start-container", prompt)
        self.assertIn("escalate", prompt)
        self.assertIn("NEVER acted on", prompt)


class HelmStateTestCase(unittest.TestCase):
    """A worker's own seat state is never where a message FOR THE HELM goes."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def roots(self, state: Path):
        from ymir_runtime import paths as paths_mod

        return paths_mod.Roots(
            home=self.tmp / "home", hoard=self.tmp / "home" / "hodd", state=state,
            data=self.tmp / "data", config=self.tmp / "config", root=self.tmp / "repo",
            wt_root=self.tmp / "wt",
        )

    def test_a_workers_seat_state_is_not_the_helms_queue(self) -> None:
        seat = self.tmp / "seats" / "an-errand"
        env = {"BROKK_STATE_OVERRIDE": str(seat), "BROKK_MACHINE_STATE_DIR": str(seat)}
        resolved = supervisor.helm_state(self.roots(seat), env)
        self.assertEqual(resolved, self.tmp / "home" / "state")

    def test_an_explicit_helm_state_wins(self) -> None:
        env = {"BROKK_HELM_STATE": str(self.tmp / "helm"), "BROKK_STATE_OVERRIDE": str(self.tmp / "seat")}
        self.assertEqual(supervisor.helm_state(self.roots(self.tmp / "seat"), env), self.tmp / "helm")

    def test_a_deliberate_other_override_is_honoured(self) -> None:
        env = {"BROKK_STATE_OVERRIDE": str(self.tmp / "probe"), "BROKK_MACHINE_STATE_DIR": str(self.tmp / "seat")}
        self.assertEqual(supervisor.helm_state(self.roots(self.tmp / "seat"), env), self.tmp / "probe")


class CliTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.env = engine_env(self.tmp)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_help_says_what_the_loop_is(self) -> None:
        self.assertEqual(supervisor.main(["--help"], env=self.env), 0)

    def test_an_unknown_flag_is_usage_not_a_silent_pass(self) -> None:
        self.assertEqual(supervisor.main(["--nonsense"], env=self.env), 2)

    def test_an_absent_judge_door_refuses_rather_than_measuring_alone(self) -> None:
        registry = self.tmp / "services.yaml"
        registry.write_text("host: testhost\nservices: []\n", encoding="utf-8")
        code = supervisor.main(
            ["--once", "--registry", str(registry), "--judge", str(self.tmp / "absent.sh"),
             "--host", "testhost", "--fixes", str(self.tmp / "fixes.md")],
            env=self.env,
            runner=Recorder(responses={}, default=completed(1)),
        )
        self.assertEqual(code, supervisor.EXIT_REFUSED)


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
