#!/usr/bin/env python3
"""The apps door, proven on a throwaway app — never on a real home, a real app or apps/.

Fenced (tests-fence-real-paths): YMIR_APPS_HOME, the registry, the state and config dirs
and the desk door all point into a temp dir. The app is a local git repo carrying the
contract (app.yaml + install.sh), so install, update, a red build, rollback, prune and the
desk law all run end to end with no network.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import apps  # noqa: E402

ROOT = HERE.parents[2]

INSTALL = """#!/usr/bin/env bash
set -eu
if [ "${1-}" = --check ]; then
  [ -f built.txt ] || { echo "not built" >&2; exit 1; }
  grep -q ok built.txt || { echo "built red" >&2; exit 1; }
  exit 0
fi
[ -f FAIL ] && { echo "build failed" >&2; exit 1; }
cat VERSION > built.txt; echo ok >> built.txt
[ -f CHECKRED ] && echo red > built.txt
mkdir -p "$YMIR_APP_STATE_DIR"; echo kept > "$YMIR_APP_STATE_DIR/state.txt"
"""


class Restart(unittest.TestCase):
    def test_a_unit_running_from_elsewhere_is_never_restarted(self):
        home = Path(tempfile.mkdtemp())
        # dbus is a user unit on every systemd seat, and it never runs from a temp apps home
        self.assertFalse(apps.runs_from("dbus.service", home))


class SeatUnits(unittest.TestCase):
    """A Ymir-rendered unit still serving from elsewhere is re-rendered through the one renderer (2026-11-19)."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = Path(self.tmp.name)
        self.home = t / "smidja"
        (self.home / "releases" / "abc").mkdir(parents=True)
        (self.home / "current").symlink_to("releases/abc")
        self.calls = t / "calls"
        door = t / "render.sh"
        door.write_text(f"#!/usr/bin/env bash\necho \"$*\" >> {self.calls}\n")
        door.chmod(0o755)
        desk = t / "in-call.sh"
        desk.write_text("#!/usr/bin/env bash\nexit 0\n")
        self.saved = dict(os.environ), apps.runs_from, apps.unit_seated, apps.sh
        os.environ.update({"YMIR_UNIT_RENDER_DOOR": str(door), "YMIR_DESK_DOOR": str(desk)})
        real_sh = apps.sh
        # systemctl is never asked for real: daemon-reload is swallowed, everything else runs
        apps.sh = lambda cmd, **kw: (subprocess.CompletedProcess(cmd, 0, "", "") if cmd[0] == "systemctl"
                                     else real_sh(cmd, **kw))
        apps.unit_seated = lambda unit: True
        apps.runs_from = lambda unit, home: False

    def tearDown(self):
        env, apps.runs_from, apps.unit_seated, apps.sh = self.saved
        os.environ.clear()
        os.environ.update(env)
        self.tmp.cleanup()

    def units(self, line):
        (self.home / "releases" / "abc" / "app.yaml").write_text(f"name: smidja\n{line}\n")

    def test_a_ymir_rendered_unit_is_re_seated_through_the_renderer(self):
        self.units("units: [smidja.service]")   # tools/web/systemd/smidja.service ships in this tree
        self.assertEqual(apps.seat_units({"id": "smidja"}, self.home), "smidja.service")
        self.assertEqual(self.calls.read_text().strip(), "unit smidja")

    def test_a_unit_ymir_does_not_render_is_left_alone(self):
        self.units("units: [toy-only.service]")
        self.assertEqual(apps.seat_units({"id": "toy"}, self.home), "")
        self.assertFalse(self.calls.exists())

    def test_a_unit_already_on_the_home_or_not_owed_here_is_left_alone(self):
        self.units("units: [smidja.service]")
        apps.runs_from = lambda unit, home: True
        self.assertEqual(apps.seat_units({"id": "smidja"}, self.home), "")
        apps.runs_from, apps.unit_seated = (lambda unit, home: False), (lambda unit: False)
        self.assertEqual(apps.seat_units({"id": "smidja"}, self.home), "")
        self.assertFalse(self.calls.exists())


class Lifecycle(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = Path(self.tmp.name)
        self.repo = t / "upstream"
        self.repo.mkdir()
        self.git("init", "-q", "-b", "main")
        (self.repo / "app.yaml").write_text("name: toy\nkind: electron\nunits: []\n")
        (self.repo / "install.sh").write_text(INSTALL)
        (self.repo / "VERSION").write_text("1\n")
        self.commit("v1")
        reg = t / "app-repos.yaml"
        reg.write_text("- id: toy\n  name: Toy\n  repo: apps/toy\n"
                       "  git: { host: example.invalid, owner: x, repo: toy, remote: origin, default_branch: main, auth: gh }\n"
                       "  home: toy\n  kind: electron\n  contract: 1\n")
        desk = t / "in-call.sh"
        desk.write_text("#!/usr/bin/env bash\n[ -f \"$(dirname \"$0\")/CALL\" ] && echo someone\nexit 0\n")
        desk.chmod(0o755)
        self.desk_flag = t / "CALL"
        self.home = t / "apps-home"
        self.env_saved = dict(os.environ)
        os.environ.update({"YMIR_APPS_HOME": str(self.home), "YMIR_APP_REGISTRY": str(reg),
                           "YMIR_APP_TOY_REPO": str(self.repo), "YMIR_DESK_DOOR": str(desk),
                           "YMIR_UNIT_RENDER_DOOR": str(t / "no-render-door"),
                           "XDG_STATE_HOME": str(t / "state"), "XDG_CONFIG_HOME": str(t / "config"),
                           "YMIR_RUNTIME_DIR": str(t / "pin")})
        apps._ROADS.clear()

    def tearDown(self):
        os.environ.clear()
        os.environ.update(self.env_saved)
        self.tmp.cleanup()

    def git(self, *a):
        subprocess.run(["git", "-C", str(self.repo), *a], check=True, capture_output=True,
                       env={**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
                            "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"})

    def commit(self, msg):
        self.git("add", "-A")
        self.git("commit", "-q", "-m", msg)

    def run_door(self, *argv):
        return apps.main([*argv, "--json"])

    def state(self, verb, *names):
        app = apps.find("toy")
        return {"install": apps.install, "update": apps.update, "check": apps.check,
                "rollback": apps.rollback}[verb](app)

    def current(self):
        return (self.home / "toy" / "current" / "built.txt").read_text()

    def test_install_builds_checks_and_flips(self):
        r = self.state("install")
        self.assertEqual(r["state"], "updated", r)
        self.assertIn("1", self.current())
        self.assertEqual(self.state("check")["state"], "green")
        self.assertEqual(self.state("update")["state"], "current")

    def test_update_flips_and_keeps_previous_then_rolls_back(self):
        self.state("install")
        (self.repo / "VERSION").write_text("2\n")
        self.commit("v2")
        self.assertEqual(self.state("update")["state"], "updated")
        self.assertIn("2", self.current())
        self.assertTrue((self.home / "toy" / "previous").is_symlink())
        self.assertEqual(self.state("rollback")["state"], "rolled back")
        self.assertIn("1", self.current())

    def test_a_red_build_never_flips(self):
        self.state("install")
        (self.repo / "FAIL").write_text("x")
        (self.repo / "VERSION").write_text("2\n")
        self.commit("broken")
        r = self.state("update")
        self.assertEqual(r["state"], "red")
        self.assertIn("1", self.current())

    def test_a_red_check_never_flips(self):
        self.state("install")
        (self.repo / "CHECKRED").write_text("x")
        (self.repo / "VERSION").write_text("3\n")
        self.commit("checks red")
        self.assertEqual(self.state("update")["state"], "red")
        self.assertIn("1", self.current())

    def test_in_a_call_it_builds_but_does_not_flip(self):
        self.state("install")
        (self.repo / "VERSION").write_text("2\n")
        self.commit("v2")
        self.desk_flag.write_text("x")
        r = self.state("update")
        self.assertEqual(r["state"], "built, waiting")
        self.assertIn("1", self.current())
        self.assertTrue((self.home / "toy" / "pending-flip").exists())
        self.desk_flag.unlink()
        self.assertEqual(self.state("update")["state"], "updated")
        self.assertIn("2", self.current())

    def test_prune_keeps_three(self):
        self.state("install")
        for v in range(2, 7):
            (self.repo / "VERSION").write_text(f"{v}\n")
            self.commit(f"v{v}")
            self.assertEqual(self.state("update")["state"], "updated")
        self.assertEqual(len(list((self.home / "toy" / "releases").iterdir())), 3)

    def test_state_survives_remove(self):
        self.state("install")
        state = Path(os.environ["XDG_STATE_HOME"]) / "toy" / "state.txt"
        self.assertTrue(state.exists())
        self.assertEqual(apps.remove(apps.find("toy"), yes=True)["state"], "removed")
        self.assertTrue(state.exists())
        self.assertFalse((self.home / "toy").exists())

    def test_the_sweep_installs_only_a_default_app(self):
        app = apps.find("toy")
        self.assertEqual(apps.update(app, sweeping=True)["state"], "not installed")
        self.assertFalse((self.home / "toy").exists())
        os.environ["YMIR_ROLE"] = "hand"
        app["install_default"] = "heart, dev"
        self.assertEqual(apps.update(app, sweeping=True)["state"], "not installed")
        os.environ["YMIR_ROLE"] = "dev"
        self.assertEqual(apps.update(app, sweeping=True)["state"], "updated")

    def test_remove_needs_yes(self):
        self.state("install")
        with self.assertRaises(apps.Refusal):
            apps.remove(apps.find("toy"), yes=False)

    def test_an_apps_home_inside_apps_is_refused(self):
        os.environ["YMIR_APPS_HOME"] = str(ROOT / "apps" / "nope-home")
        with self.assertRaises(apps.Refusal):
            apps.guard_home(apps.apps_home())
        self.assertFalse((ROOT / "apps" / "nope-home").exists())

    def test_an_app_still_in_the_tree_installs_nothing(self):
        os.environ.pop("YMIR_APP_REGISTRY")
        before = sorted(p.name for p in (ROOT / "apps").iterdir())
        for a in apps.registry():
            if a["contract"] >= 1:
                continue          # a moved app installs from its own repo (the network); not this test's
            self.assertIn(apps.install(a)["state"], ("legacy", "archived"), a["id"])
        self.assertEqual(sorted(p.name for p in (ROOT / "apps").iterdir()), before)
        self.assertFalse(self.home.exists())


if __name__ == "__main__":
    unittest.main()
