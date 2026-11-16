#!/usr/bin/env python3
"""test_launchd_user.py — the macOS service layer proved with no Mac in the room (plan 293).

`bin/engine/launchd-user.py` answers Ymir's `systemctl --user` verbs on a Mac by rendering each
systemd user unit as a launchd agent. Until this file it had no test at all, and the layer can
only be measured on hardware nobody's CI has — so every case here runs against a FAKE HOME and a
FAKE `launchctl`: the real register (`config/units.yaml`) is rendered into the real unit directory
shape, and the real verb paths are driven.

What is proved:
  · a `render` entry in config/units.yaml becomes a valid launchd plist (parsed back by plistlib),
    with the label, the shell wrapper, the log paths, the environment and the PATH order;
  · a `timer` entry becomes an interval agent (StartInterval from OnUnitActiveSec);
  · the verbs answer as systemctl answers: enable/disable/--now, start/stop/restart,
    is-active/is-enabled/is-failed, status, show -p/--value, cat, list-units/list-unit-files,
    daemon-reload, and the exit codes 0/1/3/4;
  · a restart waits for the old agent to leave before loading the new one (the measured
    `Bootstrap failed: 5` race);
  · the file on disk runs by itself, and answers `systemd-run` by its own name.

    python3 bin/engine/tests/test_launchd_user.py     # this file
    bash bin/gates/ci-verify.sh                       # or the gate that runs it

Exit: 0 every case held · 1 a case failed.
"""
from __future__ import annotations

import importlib.util
import io
import os
import plistlib
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[3]   # bin/engine/tests/ → the repo
LAUNCHD_PY = ROOT / "bin" / "engine" / "launchd-user.py"
UNITS_PY = ROOT / "bin" / "engine" / "units.py"
REGISTER = ROOT / "config" / "units.yaml"


def load_module(name: str, path: Path):
    """Import a file whose name cannot be an identifier (launchd-user.py, units.py is fine)."""
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


class FakeLaunchctl:
    """launchctl as a Mac answers it: bootstrap loads a label, bootout forgets it, print reports."""

    def __init__(self) -> None:
        self.calls: list[tuple[str, ...]] = []
        self.loaded: dict[str, dict[str, str]] = {}

    def __call__(self, *args: str) -> subprocess.CompletedProcess:
        self.calls.append(args)
        verb = args[0] if args else ""
        if verb == "print":
            label = args[1].rsplit("/", 1)[-1]
            info = self.loaded.get(label)
            if not info:
                return subprocess.CompletedProcess(args, 1, "", "Could not find service")
            out = (f"{args[1]} = {{\n\tstate = {info['state']}\n\tpid = {info['pid']}\n"
                   f"\tlast exit code = {info['last']}\n}}\n")
            return subprocess.CompletedProcess(args, 0, out, "")
        if verb == "bootstrap":
            label = plistlib.loads(Path(args[2]).read_bytes())["Label"]
            self.loaded.setdefault(label, {"state": "running", "pid": "4242", "last": "0"})
            return subprocess.CompletedProcess(args, 0, "", "")
        if verb == "bootout":
            self.loaded.pop(args[1].rsplit("/", 1)[-1], None)
            return subprocess.CompletedProcess(args, 0, "", "")
        return subprocess.CompletedProcess(args, 0, "", "")

    def verbs_since(self, mark: int) -> list[str]:
        return [c[0] for c in self.calls[mark:]]


class LaunchdCase(unittest.TestCase):
    """A fake HOME, a fake launchctl, and the real program loaded from the tree."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)
        self.home = self.root / "home"
        self.units = self.root / "systemd" / "user"
        self.agents = self.home / "Library" / "LaunchAgents"
        self.stage = self.home / "Library" / "Application Support" / "ymir" / "launchd"
        self.logs = self.home / "Library" / "Logs" / "ymir"
        self.pin = self.root / "pin"
        for d in (self.home / ".local" / "bin", self.units, self.logs, self.pin):
            d.mkdir(parents=True, exist_ok=True)

        self._env = mock.patch.dict(os.environ, {
            "HOME": str(self.home),
            "YMIR_UNIT_DIR": str(self.units),
            "YMIR_LAUNCH_AGENTS": str(self.agents),
            "YMIR_LAUNCHD_STAGE": str(self.stage),
            "YMIR_LAUNCHD_LOGS": str(self.logs),
            "YMIR_LAUNCHD_PREFIX": "org.ymir.",
        })
        self._env.start()
        self.addCleanup(self._env.stop)

        self.mod = load_module("launchd_user_under_test", LAUNCHD_PY)
        # HOME is read at import; point the module's own copy at the fake home so specifiers,
        # the environment it hands an agent and the PATH order all resolve there.
        self.mod.HOME = self.home
        self.fake = FakeLaunchctl()
        self.mod.lc = self.fake

    # ── helpers ───────────────────────────────────────────────────────────────
    def run_cli(self, *argv: str) -> tuple[int, str, str]:
        """Drive `launchd-user.py --user <argv…>` in process; return (rc, stdout, stderr)."""
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            rc = self.mod.main(["--user", *argv])
        return rc, out.getvalue(), err.getvalue()

    def write_from_register(self, name: str, overrides: dict[str, str] | None = None) -> dict[str, str]:
        """Render one real config/units.yaml entry through the one writer, into the unit directory."""
        units = load_module("ymir_units_under_test", UNITS_PY)
        entry = next(e for e in units.load_register()["units"] if e.get("name") == name)
        files = units.render_entry(entry, self.pin, overrides or {})
        for fname, text in files.items():
            (self.units / fname).write_text(text, encoding="utf-8")
        return files


# ── rendering config/units.yaml as launchd agents ────────────────────────────
class TheRegisterBecomesAPlist(LaunchdCase):
    def test_a_service_entry_becomes_a_valid_agent(self) -> None:
        files = self.write_from_register("gna-desk")
        self.assertIn("gna-desk.service", files)

        pl = self.mod.render("gna-desk.service")
        self.assertIsNotNone(pl, "a render entry with an ExecStart must produce a plist")

        self.assertEqual(pl["Label"], "org.ymir.gna-desk")
        self.assertEqual(pl["ProgramArguments"][:2], ["/bin/bash", "-c"])
        script = pl["ProgramArguments"][2]
        last = script.rstrip().splitlines()[-1]
        self.assertTrue(last.startswith("exec /usr/bin/env python3 "), last)
        self.assertIn(f"{self.pin}/bin/mail/gna_desk.py", last)
        self.assertIn("--port 8494", last)                       # ${GNA_DESK_PORT} resolved from vars
        self.assertTrue(pl["RunAtLoad"])                          # a service starts at login
        self.assertIs(pl["KeepAlive"], True)                       # Restart=always
        self.assertEqual(pl["ThrottleInterval"], 5)                # RestartSec=5
        self.assertEqual(pl["WorkingDirectory"], str(self.pin))    # workdir: "."
        self.assertEqual(pl["ProcessType"], "Standard")            # never Background (throttled)
        self.assertEqual(pl["StandardOutPath"], str(self.logs / "gna-desk.log"))
        self.assertEqual(pl["StandardErrorPath"], str(self.logs / "gna-desk.log"))

        env = pl["EnvironmentVariables"]
        self.assertEqual(env["HOME"], str(self.home))
        self.assertEqual(env["GNA_DESK_PORT"], "8494")
        self.assertEqual(env["YMIR_TREE"], str(self.pin))
        self.assertTrue(env["PATH"].startswith(str(self.home / ".local" / "bin") + ":"), env["PATH"])

        # an agent launchd can actually read: parse the bytes the writer writes
        data = self.mod.plist_bytes(pl)
        self.assertIn(b"<plist version=\"1.0\">", data)
        self.assertIn(b"<key>Label</key>", data)
        self.assertEqual(plistlib.loads(data), pl)

    def test_a_timer_entry_becomes_an_interval_agent(self) -> None:
        files = self.write_from_register("queue-warden")
        self.assertIn("queue-warden.service", files)
        self.assertIn("OnUnitActiveSec=10min", files["queue-warden.timer"])
        self.assertIn("Type=oneshot", files["queue-warden.service"])

        pl = self.mod.render("queue-warden.timer")
        self.assertIsNotNone(pl)
        self.assertEqual(pl["Label"], "org.ymir.queue-warden")
        self.assertEqual(pl["StartInterval"], 600)                 # 10min
        self.assertFalse(pl["RunAtLoad"])                          # OnBootSec=3min, past the login window

        # a oneshot service is never kept alive, and is not the interval agent until its timer is enabled
        svc = self.mod.render("queue-warden.service")
        self.assertTrue(svc["RunAtLoad"])
        self.assertNotIn("KeepAlive", svc)

        self.assertEqual(self.run_cli("enable", "queue-warden.timer")[0], 0)
        self.assertTrue((self.units / "timers.target.wants" / "queue-warden.timer").is_symlink())
        again = self.mod.render("queue-warden.service")
        self.assertEqual(again["StartInterval"], 600, "an enabled timer makes its service the interval agent")

    def test_a_target_has_nothing_to_run(self) -> None:
        (self.units / "backend.target").write_text("[Unit]\nDescription=backend\n", encoding="utf-8")
        self.assertIsNone(self.mod.render("backend.target"))


# ── the verbs ────────────────────────────────────────────────────────────────
class TheVerbsAnswer(LaunchdCase):
    def setUp(self) -> None:
        super().setUp()
        self.write_from_register("gna-desk")
        self.agent_file = self.agents / "org.ymir.gna-desk.plist"

    def test_enable_now_writes_the_agent_and_loads_it(self) -> None:
        rc, out, err = self.run_cli("enable", "--now", "gna-desk")
        self.assertEqual(rc, 0, err)
        self.assertTrue(self.agent_file.is_file())
        self.assertTrue((self.units / "default.target.wants" / "gna-desk.service").is_symlink())
        self.assertIn("org.ymir.gna-desk", self.fake.loaded)

        self.assertEqual(self.run_cli("is-enabled", "gna-desk")[:2], (0, "enabled\n"))
        self.assertEqual(self.run_cli("is-active", "gna-desk")[:2], (0, "active\n"))

        rc, out, _ = self.run_cli("status", "gna-desk")
        self.assertEqual(rc, 0)
        self.assertIn("Active: active", out)
        self.assertIn("Main PID: 4242", out)
        self.assertIn("enabled", out)

        rc, out, _ = self.run_cli("show", "-p", "ActiveState,SubState,MainPID", "gna-desk")
        self.assertEqual(rc, 0)
        self.assertEqual(out, "ActiveState=active\nSubState=running\nMainPID=4242\n")
        self.assertEqual(self.run_cli("show", "--value", "-p", "MainPID", "gna-desk")[:2], (0, "4242\n"))

    def test_disable_now_takes_the_agent_away(self) -> None:
        self.run_cli("enable", "--now", "gna-desk")
        rc, _, _ = self.run_cli("disable", "--now", "gna-desk")
        self.assertEqual(rc, 0)
        self.assertFalse(self.agent_file.exists())
        self.assertFalse((self.units / "default.target.wants" / "gna-desk.service").is_symlink())
        self.assertNotIn("org.ymir.gna-desk", self.fake.loaded)
        self.assertEqual(self.run_cli("is-enabled", "gna-desk")[:2], (1, "disabled\n"))
        self.assertEqual(self.run_cli("is-active", "gna-desk")[:2], (3, "inactive\n"))
        self.assertEqual(self.run_cli("is-failed", "gna-desk")[:2], (1, "inactive\n"))
        self.assertEqual(self.run_cli("start", "gna-desk")[0], 0)

    def test_start_without_enable_stages_the_agent(self) -> None:
        rc, _, err = self.run_cli("start", "gna-desk")
        self.assertEqual(rc, 0, err)
        self.assertTrue((self.stage / "org.ymir.gna-desk.plist").is_file())
        self.assertFalse(self.agent_file.exists(), "a started-but-not-enabled unit never starts at login")
        self.assertIn("org.ymir.gna-desk", self.fake.loaded)

        self.assertEqual(self.run_cli("stop", "gna-desk")[0], 0)
        self.assertNotIn("org.ymir.gna-desk", self.fake.loaded)
        self.assertEqual(self.run_cli("is-active", "gna-desk")[:2], (3, "inactive\n"))

    def test_a_restart_waits_for_the_old_agent_to_leave(self) -> None:
        self.run_cli("start", "gna-desk")
        mark = len(self.fake.calls)
        rc, _, _ = self.run_cli("restart", "gna-desk")
        self.assertEqual(rc, 0)
        verbs = self.fake.verbs_since(mark)
        self.assertLess(verbs.index("bootout"), verbs.index("bootstrap"))
        between = verbs[verbs.index("bootout") + 1:verbs.index("bootstrap")]
        self.assertIn("print", between, "launchd must be seen letting the old job go (Bootstrap failed: 5)")
        self.assertIn("org.ymir.gna-desk", self.fake.loaded)

    def test_daemon_reload_re_renders_an_edited_unit(self) -> None:
        self.run_cli("enable", "--now", "gna-desk")
        before = self.agent_file.read_bytes()
        unit = self.units / "gna-desk.service"
        unit.write_text(unit.read_text(encoding="utf-8").replace("--port 8494", "--port 9999"),
                        encoding="utf-8")
        self.assertEqual(self.run_cli("daemon-reload")[0], 0)
        after = plistlib.loads(self.agent_file.read_bytes())
        self.assertIn("--port 9999", after["ProgramArguments"][2])
        self.assertNotEqual(before, self.agent_file.read_bytes())

    def test_the_reading_verbs(self) -> None:
        rc, out, _ = self.run_cli("cat", "gna-desk")
        self.assertEqual(rc, 0)
        self.assertIn("ExecStart=", out)

        rc, out, _ = self.run_cli("list-unit-files")
        self.assertEqual(rc, 0)
        self.assertIn("gna-desk.service disabled", out)

        rc, out, _ = self.run_cli("list-units")
        self.assertEqual(rc, 0)
        self.assertNotIn("gna-desk.service", out, "systemctl omits an inactive unit from list-units")

        self.assertEqual(self.run_cli("daemon-reexec")[0], 0)
        self.assertEqual(self.run_cli("reset-failed", "whatever")[0], 0)
        rc, out, _ = self.run_cli("show-environment")
        self.assertEqual(rc, 0)
        self.assertIn("HOME=", out)

    def test_a_missing_unit_is_refused_as_systemctl_refuses_it(self) -> None:
        rc, _, err = self.run_cli("start", "nope")
        self.assertEqual(rc, 1)
        self.assertIn("Unit nope.service not found", err)

        rc, out, _ = self.run_cli("status", "nope")
        self.assertEqual(rc, 4)
        self.assertIn("Unit nope.service could not be found", out)

        self.assertEqual(self.run_cli("is-enabled", "nope")[:2], (1, "not-found\n"))
        self.assertEqual(self.run_cli("enable", "nope")[0], 1)

        rc, _, err = self.run_cli("frobnicate", "gna-desk")
        self.assertEqual(rc, 1)
        self.assertIn("has no launchd road yet", err)

        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            rc = self.mod.main(["status", "gna-desk"])       # the user manager is the only one here
        self.assertEqual(rc, 1)
        self.assertIn("--user", err.getvalue())

    def test_a_quiet_query_prints_nothing(self) -> None:
        self.assertEqual(self.run_cli("is-active", "--quiet", "gna-desk"), (3, "", ""))


# ── the file on disk, and the systemd-run name ───────────────────────────────
class TheDoorOnDisk(LaunchdCase):
    def setUp(self) -> None:
        super().setUp()
        self.write_from_register("gna-desk")

    def cli(self, prog: Path, *argv: str, env: dict[str, str] | None = None) -> subprocess.CompletedProcess:
        return subprocess.run([str(prog), *argv], capture_output=True, text=True, timeout=60,
                              env={**os.environ, **(env or {})})

    def test_it_runs_by_itself(self) -> None:
        r = self.cli(LAUNCHD_PY, "--user", "is-enabled", "gna-desk")
        self.assertEqual((r.returncode, r.stdout), (1, "disabled\n"), r.stderr)
        r = self.cli(LAUNCHD_PY, "--user", "enable", "gna-desk")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((self.agents / "org.ymir.gna-desk.plist").is_file())

    def test_it_answers_systemd_run_by_its_own_name(self) -> None:
        # the transient-unit door: the same file installed as `systemd-run` renders a one-shot agent
        bindir = self.root / "bin"
        bindir.mkdir(exist_ok=True)
        link = bindir / "systemd-run"
        link.symlink_to(LAUNCHD_PY)
        state = self.root / "launchctl.state"
        state.write_text("", encoding="utf-8")
        fake_lc = bindir / "launchctl"
        fake_lc.write_text(f"""#!/usr/bin/env bash
set -u
st={str(state)!r}
case "$1" in
  print) label="${{2##*/}}"
         if grep -qx "$label" "$st" 2>/dev/null; then
           printf '%s = {{\\n\\tstate = running\\n\\tpid = 4321\\n\\tlast exit code = 0\\n}}\\n' "$2"; exit 0
         fi
         echo "Could not find service" >&2; exit 1 ;;
  bootstrap) awk '/<key>Label<\\/key>/{{getline; gsub(/.*<string>|<\\/string>.*/,""); print}}' "$3" >> "$st"; exit 0 ;;
  bootout) label="${{2##*/}}"; grep -vx "$label" "$st" > "$st.n" 2>/dev/null; mv "$st.n" "$st"; exit 0 ;;
esac
exit 0
""", encoding="utf-8")
        fake_lc.chmod(0o755)

        r = self.cli(link, "--user", "--unit=once", "--collect", "--setenv=K=V", "/bin/echo", "hi",
                     env={"PATH": f"{bindir}:{os.environ['PATH']}"})
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("Running as unit: once.service", r.stderr)

        transient = self.stage / "transient" / "once.service"
        self.assertTrue(transient.is_file(), "a transient unit is written outside the unit directory")
        self.assertIn("ExecStart=/bin/echo hi", transient.read_text(encoding="utf-8"))
        pl = plistlib.loads((self.stage / "org.ymir.once.plist").read_bytes())
        self.assertEqual(pl["ProgramArguments"], ["/bin/echo", "hi"])
        self.assertEqual(pl["EnvironmentVariables"]["K"], "V")
        self.assertTrue(pl["RunAtLoad"])
        self.assertEqual(pl["WorkingDirectory"], os.getcwd())


if __name__ == "__main__":
    if not REGISTER.exists():
        sys.exit(f"no unit register at {REGISTER}")
    unittest.main(verbosity=2)
