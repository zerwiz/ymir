"""dispatch/ — the decision table as Python reading data (plan 58, Part 1).

The tree's `.agents/roles.yaml` is the wiring; the hoard's `config/agents.yaml` is
the model. These tests assert the DECISION — role → figure → tools → model → seat
— with two synthetic hoard YAMLs, a scripted registry door, and the tree's own
table. No network, no pane, no model ever touched.
"""

from __future__ import annotations

import contextlib
import io
import tempfile
import unittest
from pathlib import Path

from ymir_runtime import __main__ as cli
from ymir_runtime.config import available as config_available
from ymir_runtime.dispatch import (
    HoardModels,
    ModelUnavailable,
    Resolution,
    TableRefusal,
    read,
    resolve,
)
from ymir_runtime.dispatch import __main__ as dispatch_cli
from ymir_runtime.tests.support import Recorder, completed, engine_env, make_repo

REPO = Path(__file__).resolve().parents[3]
HAS_VALIDATOR = config_available()


def _write_hoard(directory: Path, body: str) -> Path:
    config = directory / "config"
    config.mkdir(parents=True, exist_ok=True)
    path = config / "agents.yaml"
    path.write_text(body, encoding="utf-8")
    return path


HOARD_A = """\
version: 1
harness:
  local: pi
  online: opencode
  local_providers: [llama.cpp, llama-swap]
default_model: opencode-go/default-one
agents:
  sindri: { model: "llama.cpp/model-alpha@q4" }
  bragi: { model: "opencode-go/bragi-a" }
  kvasir: { model: "llama.cpp/scout-a@q4" }
"""

HOARD_B = """\
version: 1
harness:
  local: pi
  online: opencode
  local_providers: [llama.cpp, llama-swap]
default_model: opencode-go/default-two
agents:
  sindri: { model: "llama-swap/model-beta@q8" }
  bragi: { model: "opencode-go/bragi-b" }
  kvasir: { model: "llama-swap/scout-b@q8" }
"""


class TableTest(unittest.TestCase):
    """`.agents/roles.yaml` — the shipped wiring, read as data."""

    def setUp(self) -> None:
        self.table = read(root=REPO)

    def test_the_real_table_loads_and_names_the_smiths(self) -> None:
        self.assertEqual(self.table.model_from, "hoard")
        self.assertIn("developer", self.table.names())
        self.assertEqual(self.table.get("developer").figure, "sindri")
        self.assertEqual(self.table.by_figure("bragi").name, "marketer")
        self.assertIn("yggdrasil", self.table.get("developer").tools)

    def test_every_figure_the_table_names_is_rostered(self) -> None:
        roster = REPO / ".agents" / "agents"
        for role in self.table.roles:
            with self.subTest(role=role.name):
                self.assertTrue(
                    (roster / f"{role.figure}.md").is_file()
                    or any(roster.glob(f"{role.figure}-*.md")),
                    f"{role.figure} is not rostered",
                )

    def test_unknown_role_refuses_and_lists_the_known(self) -> None:
        with self.assertRaises(TableRefusal) as caught:
            self.table.get("captain")
        self.assertIn("unknown role 'captain'", str(caught.exception))
        self.assertIn("developer", str(caught.exception))

    def test_unknown_figure_refuses(self) -> None:
        with self.assertRaises(TableRefusal) as caught:
            self.table.by_figure("loki")
        self.assertIn("unknown figure 'loki'", str(caught.exception))

    def test_find_accepts_a_role_or_a_figure(self) -> None:
        self.assertEqual(self.table.find("sindri").name, "developer")
        self.assertEqual(self.table.find("developer").figure, "sindri")
        with self.assertRaises(TableRefusal) as caught:
            self.table.find("nobody")
        self.assertIn("unknown role or figure", str(caught.exception))

    def test_choose_scores_the_data_keywords(self) -> None:
        role, score = self.table.choose("fix the bug and refactor the module")
        self.assertEqual(role.name, "developer")
        self.assertGreater(score, 0)
        role, _ = self.table.choose("write a marketing blog post for our campaign")
        self.assertEqual(role.name, "marketer")
        role, score = self.table.choose("")
        self.assertEqual(role.name, "developer")
        self.assertEqual(score, 0)

    def test_a_missing_table_refuses(self) -> None:
        with self.assertRaises(TableRefusal) as caught:
            read(path=Path(tempfile.gettempdir()) / "no-such-roles.yaml", root=REPO)
        self.assertIn("absent", str(caught.exception))

    def test_a_role_naming_an_unrostered_figure_refuses(self) -> None:
        directory = Path(tempfile.mkdtemp(prefix="ymir-dispatch-roles-"))
        path = directory / "roles.yaml"
        path.write_text(
            'version: 1\nmodel_from: hoard\nroles:\n  ghost:\n    figure: loki\n',
            encoding="utf-8",
        )
        with self.assertRaises(TableRefusal) as caught:
            read(path=path, root=REPO)
        self.assertIn("not rostered", str(caught.exception))
        self.assertIn("roles.ghost.figure", str(caught.exception))

    def test_a_table_that_pins_a_model_is_refused(self) -> None:
        directory = Path(tempfile.mkdtemp(prefix="ymir-dispatch-roles-"))
        path = directory / "roles.yaml"
        path.write_text(
            'version: 1\nmodel_from: tree\nroles:\n  developer:\n    figure: sindri\n',
            encoding="utf-8",
        )
        with self.assertRaises(TableRefusal) as caught:
            read(path=path, root=REPO)
        self.assertIn("model_from", str(caught.exception))

    def test_a_role_without_a_figure_is_refused(self) -> None:
        directory = Path(tempfile.mkdtemp(prefix="ymir-dispatch-roles-"))
        path = directory / "roles.yaml"
        path.write_text("version: 1\nroles:\n  empty:\n    craft: 'nothing'\n", encoding="utf-8")
        with self.assertRaises(TableRefusal) as caught:
            read(path=path, root=REPO)
        self.assertIn("summons nothing", str(caught.exception))


@unittest.skipUnless(HAS_VALIDATOR, "jsonschema not installed — bin/engine/ymir-engine-ensure.sh ensure")
class RegistryTest(unittest.TestCase):
    """The hoard's model — a lookup of declared data, and a delegation for a request."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.a = _write_hoard(self.tmp / "a", HOARD_A)
        self.b = _write_hoard(self.tmp / "b", HOARD_B)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_two_hoard_yamls_resolve_two_models(self) -> None:
        first = HoardModels(root=REPO, override=self.a).configured("sindri")
        second = HoardModels(root=REPO, override=self.b).configured("sindri")
        self.assertEqual(first.model, "llama.cpp/model-alpha@q4")
        self.assertEqual(second.model, "llama-swap/model-beta@q8")
        self.assertNotEqual(first.model, second.model)
        self.assertIn(str(self.a), first.provenance)

    def test_the_harness_follows_the_yamls_own_local_rule(self) -> None:
        first = HoardModels(root=REPO, override=self.a)
        self.assertEqual(first.configured("sindri").harness, "pi")  # llama.cpp is local
        self.assertEqual(first.configured("bragi").harness, "opencode")  # hosted

    def test_an_absent_hoard_config_refuses_naming_the_key(self) -> None:
        missing = self.tmp / "nowhere" / "agents.yaml"
        with self.assertRaises(ModelUnavailable) as caught:
            HoardModels(root=REPO, override=missing).configured("sindri")
        self.assertEqual(caught.exception.key, "agents.sindri.model")
        self.assertIn(str(missing), str(caught.exception))

    def test_a_figure_the_hoard_does_not_name_refuses(self) -> None:
        with self.assertRaises(ModelUnavailable) as caught:
            HoardModels(root=REPO, override=self.a).configured("huginn")
        self.assertEqual(caught.exception.key, "agents.huginn")

    def test_an_agent_without_a_model_falls_to_default_model(self) -> None:
        path = _write_hoard(self.tmp / "c", "version: 1\ndefault_model: opencode-go/fallback\nagents:\n  sindri: {}\n")
        self.assertEqual(HoardModels(root=REPO, override=path).configured("sindri").model, "opencode-go/fallback")

    def test_a_request_delegates_to_the_fleet_registry_door(self) -> None:
        toon = (
            "model-resolve[1]{request,locality,harness,provider,model,confidence}:\n"
            '  "qwen 3.6 iq3","local","pi","llama-swap","qwen3.6-35b-a3b@iq3_s","high"\n'
        )
        runner = Recorder(responses={"model-resolve.sh": completed(0, toon)})
        answer = HoardModels(root=REPO, override=self.a, runner=runner).request("qwen 3.6 iq3")
        self.assertTrue(answer.resolved)
        self.assertEqual(answer.model, "qwen3.6-35b-a3b@iq3_s")
        self.assertEqual(answer.harness, "pi")
        self.assertEqual(answer.provider, "llama-swap")
        self.assertTrue(runner.saw("model-resolve.sh"))

    def test_an_unresolved_request_is_reported_not_guessed(self) -> None:
        toon = 'model-resolve[1]{request,resolution,ask}:\n  "mystery","unresolved","yes"\n'
        runner = Recorder(responses={"model-resolve.sh": completed(0, toon)})
        answer = HoardModels(root=REPO, override=self.a, runner=runner).request("mystery")
        self.assertFalse(answer.resolved)

    def test_a_broken_door_is_a_refusal(self) -> None:
        runner = Recorder(responses={"model-resolve.sh": completed(1, "", "boom")})
        with self.assertRaises(ModelUnavailable):
            HoardModels(root=REPO, override=self.a, runner=runner).request("anything")

    def test_an_absent_door_is_a_refusal(self) -> None:
        with self.assertRaises(ModelUnavailable):
            HoardModels(root=self.tmp, override=self.a).request("anything")


@unittest.skipUnless(HAS_VALIDATOR, "jsonschema not installed — bin/engine/ymir-engine-ensure.sh ensure")
class ResolveTest(unittest.TestCase):
    """One errand → role · figure · tools · model · harness · seat."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.hoard = _write_hoard(self.tmp / "hoard", HOARD_A)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def _models(self) -> HoardModels:
        return HoardModels(root=REPO, override=self.hoard)

    def test_one_errand_resolves_the_whole_chain(self) -> None:
        resolution = resolve(role="developer", models=self._models(), root=REPO)
        self.assertIsInstance(resolution, Resolution)
        self.assertEqual(resolution.role, "developer")
        self.assertEqual(resolution.figure, "sindri")
        self.assertEqual(resolution.harness, "pi")
        self.assertEqual(resolution.model, "llama.cpp/model-alpha@q4")
        self.assertEqual(resolution.seat, "herdr")
        self.assertEqual(resolution.kind, "ship")
        self.assertIn("yggdrasil", resolution.tools)
        for key in ("role", "figure", "tools", "model", "harness", "seat"):
            self.assertIn(key, resolution.provenance)

    def test_the_brief_declares_the_seat_type(self) -> None:
        resolution = resolve(
            role="developer",
            brief="# Task\n\nIsolation: utgard — untrusted input\n",
            models=self._models(),
            root=REPO,
        )
        self.assertEqual(resolution.seat, "utgard")

    def test_an_explicit_isolation_beats_the_brief(self) -> None:
        resolution = resolve(
            role="developer",
            brief="Isolation: herdr — the ordinary road\n",
            isolation="utgard",
            models=self._models(),
            root=REPO,
        )
        self.assertEqual(resolution.seat, "utgard")

    def test_task_text_chooses_the_smith(self) -> None:
        resolution = resolve(task="write a marketing campaign for the brand", models=self._models(), root=REPO)
        self.assertEqual(resolution.role, "marketer")
        self.assertEqual(resolution.figure, "bragi")
        self.assertEqual(resolution.harness, "opencode")

    def test_a_figure_name_resolves_like_a_role(self) -> None:
        resolution = resolve(role="sindri", models=self._models(), root=REPO)
        self.assertEqual(resolution.role, "developer")

    def test_scout_kind_is_carried(self) -> None:
        resolution = resolve(role="scout", kind="scout", models=self._models(), root=REPO)
        self.assertEqual(resolution.kind, "scout")
        self.assertEqual(resolution.figure, "kvasir")

    def test_an_unsupported_kind_refuses(self) -> None:
        with self.assertRaises(TableRefusal):
            resolve(role="developer", kind="voyage", models=self._models(), root=REPO)

    def test_nothing_to_resolve_refuses(self) -> None:
        with self.assertRaises(TableRefusal) as caught:
            resolve(models=self._models(), root=REPO)
        self.assertIn("no role and no task", str(caught.exception))


class ModuleCliTest(unittest.TestCase):
    """`python3 -m ymir_runtime.dispatch` — the layer's own door face."""

    def _run(self, argv: list[str]) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = dispatch_cli.main(argv)
        return code, out.getvalue(), err.getvalue()

    def test_roles_lists_the_table(self) -> None:
        code, out, _ = self._run(["roles"])
        self.assertEqual(code, dispatch_cli.EXIT_OK)
        self.assertIn("dispatch-roles[", out)
        self.assertIn('"developer","sindri"', out)

    def test_choose_reads_the_table(self) -> None:
        code, out, _ = self._run(["choose", "scout", "the", "codebase"])
        self.assertEqual(code, dispatch_cli.EXIT_OK)
        self.assertIn('"scout","kvasir"', out)

    def test_an_unknown_role_refuses_with_exit_one(self) -> None:
        code, _, err = self._run(["resolve", "--role", "captain"])
        self.assertEqual(code, dispatch_cli.EXIT_REFUSED)
        self.assertIn("refused", err)


class EngineCliDispatchTest(unittest.TestCase):
    """The engine's CLI gains a `dispatch` verb proving the resolution."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.repo = make_repo(self.tmp / "repo")
        self.env = engine_env(self.tmp, repo=self.repo)
        self.env["YMIR_ENGINE_ROOT"] = str(REPO)
        self.env["BROKK_ROOT_OVERRIDE"] = str(REPO)
        hoard = Path(self.env["YMIR_SETTINGS_DIR"]) / "agents.yaml"
        hoard.parent.mkdir(parents=True, exist_ok=True)
        hoard.write_text(HOARD_A, encoding="utf-8")

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def _run(self, argv: list[str]) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = cli.main(argv, env=self.env)
        return code, out.getvalue(), err.getvalue()

    @unittest.skipUnless(HAS_VALIDATOR, "jsonschema not installed")
    def test_the_dispatch_verb_resolves_an_errand(self) -> None:
        code, out, _ = self._run(["dispatch", "developer", "--toon"])
        self.assertEqual(code, cli.EXIT_OK, out)
        self.assertIn("dispatch[1]{role,figure,craft,tools,harness,model,seat,kind}", out)
        self.assertIn('"developer","sindri"', out)
        self.assertIn("llama.cpp/model-alpha@q4", out)
        self.assertIn("yggdrasil", out)

    @unittest.skipUnless(HAS_VALIDATOR, "jsonschema not installed")
    def test_the_dispatch_verb_reads_the_briefs_seat(self) -> None:
        brief = self.tmp / "brief.md"
        brief.write_text("# Task\n\nIsolation: utgard — untrusted\n", encoding="utf-8")
        code, out, _ = self._run(["dispatch", "developer", "--brief", str(brief), "--toon"])
        self.assertEqual(code, cli.EXIT_OK, out)
        self.assertIn('"utgard"', out)

    def test_the_dispatch_verb_refuses_an_unknown_role(self) -> None:
        code, _, err = self._run(["dispatch", "captain"])
        self.assertEqual(code, cli.EXIT_FAILED)
        self.assertIn("refused", err)

    def test_the_dispatch_verb_refuses_an_absent_hoard(self) -> None:
        (Path(self.env["YMIR_SETTINGS_DIR"]) / "agents.yaml").unlink()
        code, _, err = self._run(["dispatch", "developer"])
        self.assertEqual(code, cli.EXIT_FAILED)
        self.assertIn("agents.sindri.model", err)


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
