"""config/ — load-with-schema, a loud refusal naming the key and the file (plan 58, Phase 7)."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from ymir_runtime.config import (
    ConfigError,
    ConfigUnavailable,
    ConfigValidationError,
    KNOWN,
    available,
    load_config,
    spec_for,
)
from ymir_runtime.config import schema as schema_mod

REPO = Path(__file__).resolve().parents[3]
CONFIG = REPO / "config"
HAS_VALIDATOR = available()


def _write(name: str, text: str) -> Path:
    directory = Path(tempfile.mkdtemp(prefix="ymir-config-test-"))
    path = directory / name
    path.write_text(text, encoding="utf-8")
    return path


class KindsTest(unittest.TestCase):
    """Name inference — a config with no registered kind is refused, never guessed."""

    def test_every_runtime_config_has_a_kind(self) -> None:
        for name, kind in (
            ("agents.yaml", "agents"),
            ("agents.heimdall.yaml", "agents"),
            ("agents.yaml.example", "agents"),
            ("cron.yaml", "cron"),
            ("cron.yaml.example", "cron"),
            ("fleet.json", "fleet"),
            ("fleet.json.example", "fleet"),
            ("eindri-dispatch.json", "eindri-dispatch"),
            ("grants.yaml", "grants"),
            ("grants.yaml.example", "grants"),
        ):
            self.assertEqual(spec_for(name).kind, kind, name)

    def test_an_unregistered_config_is_refused(self) -> None:
        with self.assertRaises(ConfigError):
            spec_for("something-else.yaml")

    def test_an_unknown_kind_is_refused(self) -> None:
        with self.assertRaises(ConfigError):
            spec_for("agents.yaml", "not-a-kind")

    def test_the_five_known_kinds_are_the_runtime_reads(self) -> None:
        self.assertEqual(set(KNOWN), {"agents", "cron", "fleet", "eindri-dispatch", "grants"})


class AlwaysRefusesTest(unittest.TestCase):
    """Refusals that need no JSON Schema validator — the parse itself is loud."""

    def test_missing_file_is_refused(self) -> None:
        with self.assertRaises(ConfigError):
            load_config(Path(tempfile.gettempdir()) / "no-such-config.yaml")

    def test_empty_config_is_refused(self) -> None:
        path = _write("agents.yaml", "")
        with self.assertRaises(ConfigError):
            load_config(path, root=REPO)

    def test_cron_bad_time_is_refused_and_names_the_line(self) -> None:
        path = _write("cron.yaml", "09:99 bin/x.sh\n")
        with self.assertRaises(ConfigError) as caught:
            load_config(path, root=REPO)
        self.assertIn("line 1", str(caught.exception))

    def test_cron_without_a_command_is_refused(self) -> None:
        path = _write("cron.yaml", "09:00\n")
        with self.assertRaises(ConfigError):
            load_config(path, root=REPO)

    def test_cron_parses_both_role_orders(self) -> None:
        path = _write("cron.yaml", "@heart 06:00 bin/a.sh\n07:00 @forge bin/b.sh\n08:00 bin/c.sh\n")
        if not HAS_VALIDATOR:
            self.skipTest("jsonschema not installed")
        data = load_config(path, root=REPO)
        self.assertEqual([job["time"] for job in data["jobs"]], ["06:00", "07:00", "08:00"])
        self.assertEqual(data["jobs"][0]["roles"], ["heart"])
        self.assertEqual(data["jobs"][1]["roles"], ["forge"])
        self.assertNotIn("roles", data["jobs"][2])

    def test_no_validator_means_no_config_ever(self) -> None:
        """The invariant: absent jsonschema is a refusal, never a default."""
        path = _write("agents.yaml", "agents:\n  brokk: {model: x}\n")
        with mock.patch.object(schema_mod, "_jsonschema", None):
            self.assertFalse(available())
            with self.assertRaises(ConfigUnavailable) as caught:
                load_config(path, root=REPO)
        self.assertEqual(caught.exception.dependency, "jsonschema")


@unittest.skipUnless(HAS_VALIDATOR, "jsonschema not installed — bin/engine/ymir-engine-ensure.sh ensure")
class ExamplesTest(unittest.TestCase):
    """The shipped examples are the truth the schemas must validate."""

    def test_every_shipped_example_loads_clean(self) -> None:
        for name in ("agents.yaml.example", "cron.yaml.example", "fleet.json.example", "eindri-dispatch.json", "grants.yaml.example"):
            data = load_config(CONFIG / name, root=REPO)
            self.assertIsInstance(data, dict, name)

    def test_the_real_schedule_is_a_list_of_jobs(self) -> None:
        data = load_config(CONFIG / "cron.yaml.example", root=REPO)
        self.assertTrue(data["jobs"])
        for job in data["jobs"]:
            self.assertRegex(job["time"], r"^[0-2][0-9]:[0-5][0-9]$")


@unittest.skipUnless(HAS_VALIDATOR, "jsonschema not installed — bin/engine/ymir-engine-ensure.sh ensure")
class BrokenConfigTest(unittest.TestCase):
    """A deliberate break is refused loudly, naming the key and the file."""

    def test_agents_wrong_key_type_names_the_key_and_the_file(self) -> None:
        path = _write("agents.yaml", "default_model: [1]\nagents:\n  brokk: {model: x}\n")
        with self.assertRaises(ConfigValidationError) as caught:
            load_config(path, root=REPO)
        message = str(caught.exception)
        self.assertIn("agents.yaml", message)
        self.assertIn("default_model", message)

    def test_agents_wrong_container_type_is_refused(self) -> None:
        path = _write("agents.yaml", "agents: []\n")
        with self.assertRaises(ConfigValidationError) as caught:
            load_config(path, root=REPO)
        self.assertIn("agents", caught.exception.key)

    def test_an_unknown_agent_name_is_refused(self) -> None:
        path = _write("agents.yaml", "agents:\n  brokk: {model: x}\n  not-a-figure: {model: y}\n")
        with self.assertRaises(ConfigValidationError) as caught:
            load_config(path, root=REPO)
        self.assertIn("agents.not-a-figure", str(caught.exception))

    def test_fleet_unknown_role_names_the_key(self) -> None:
        path = _write("fleet.json", json.dumps({"heart": "a", "hosts": {"a": {"roles": ["captain"]}}}))
        with self.assertRaises(ConfigValidationError) as caught:
            load_config(path, root=REPO)
        self.assertIn("roles", str(caught.exception))

    def test_fleet_heart_must_be_a_declared_host(self) -> None:
        path = _write("fleet.json", json.dumps({"heart": "ghost", "hosts": {"a": {"roles": ["dev"]}}}))
        with self.assertRaises(ConfigValidationError) as caught:
            load_config(path, root=REPO)
        self.assertIn("heart", caught.exception.key)
        self.assertIn("ghost", str(caught.exception))

    def test_fleet_host_must_be_itself(self) -> None:
        path = _write("fleet.json", json.dumps({"heart": "a", "hosts": {"a": {"roles": ["dev"]}}}))
        with self.assertRaises(ConfigValidationError) as caught:
            load_config(path, root=REPO, host="elsewhere")
        self.assertIn("hosts", caught.exception.key)

    def test_cron_unknown_role_is_refused(self) -> None:
        path = _write("cron.yaml", "@captain 09:00 bin/x.sh\n")
        with self.assertRaises(ConfigValidationError) as caught:
            load_config(path, root=REPO)
        self.assertIn("roles", str(caught.exception))

    def test_dispatch_use_must_be_a_list(self) -> None:
        """bin/fleet/dispatch-profile.sh iterates `use`; a single object used to be skipped silently."""
        profile = {
            "version": 1,
            "rules": [{"when": "anything", "use": {"harness": "pi"}}],
        }
        path = _write("eindri-dispatch.json", json.dumps(profile))
        with self.assertRaises(ConfigValidationError) as caught:
            load_config(path, root=REPO)
        self.assertIn("use", str(caught.exception))

    def test_a_healthy_fleet_loads_clean(self) -> None:
        path = _write("fleet.json", json.dumps({"heart": "a", "hosts": {"a": {"roles": ["heart", "dev"]}}}))
        data = load_config(path, root=REPO, host="a")
        self.assertEqual(data["heart"], "a")


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
