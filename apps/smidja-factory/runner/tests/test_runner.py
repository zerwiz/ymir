"""The smithy's runner: its doors agree, its refusals hold, and it never touches a real trace.

Every test fences the real paths (the house law, tests-fence-real-paths): SMIDJA_DB,
SMIDJA_DATA_DIR and HOME point into a temp dir, so a stop, an emergency stop or a
steer can only ever act on a trace this test made.
"""

from __future__ import annotations

import json
import os
import re
import sqlite3
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

RUNNER = Path(__file__).resolve().parents[1]
FACTORY = RUNNER.parent
sys.path.insert(0, str(RUNNER))

from smidja_runner import cli, mcp_server, paths, trace, verbs  # noqa: E402

SCHEMA = """
create table sessions (smidja_id text primary key, smidja_name text, request text, status text,
  engineer text, started_at text, ended_at text, total_tokens integer default 0,
  total_cost real default 0, archived integer default 0);
create table phases (phase_id text primary key, smidja_id text, seq integer, name text, kind text,
  owner text, description text, status text, attempt integer default 0, retries integer default 0, error text);
create table events (event_id text primary key, smidja_id text, phase_id text, parent_id text, type text,
  name text, payload_json text, tokens integer, started_at text, ended_at text);
create table envelopes (envelope_id text primary key, smidja_id text, phase_id text, agent text,
  output_type text, payload_json text, valid integer, attempt integer, created_at text);
create table gate_results (id integer primary key autoincrement, smidja_id text, phase_id text,
  attempt integer, gate text, passed integer, violations_json text, checks_json text);
create table processes (id integer primary key autoincrement, smidja_id text, kind text, name text,
  pid integer, command text, started_at text, ended_at text);
"""


class Fenced(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.db = root / "trace" / "smidja.db"
        self.db.parent.mkdir()
        with sqlite3.connect(self.db) as c:
            c.executescript(SCHEMA)
        self.saved = {k: os.environ.get(k) for k in
                      ("SMIDJA_DB", "SMIDJA_DATA_DIR", "CMD_DB", "HOME", "SMIDJA_VIEWER_URL", "YMIR_HOME")}
        os.environ.update({"SMIDJA_DB": str(self.db), "SMIDJA_DATA_DIR": str(self.db.parent),
                           "HOME": str(root / "home"), "SMIDJA_VIEWER_URL": "http://127.0.0.1:9",
                           "YMIR_HOME": str(root / "no-home")})
        os.environ.pop("CMD_DB", None)
        self.children: list[subprocess.Popen] = []

    def tearDown(self):
        for p in self.children:
            if p.poll() is None:
                p.kill()
            p.wait()
        for k, v in self.saved.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v
        self.tmp.cleanup()

    def add_run(self, sid="r1", status="running", child=True):
        with sqlite3.connect(self.db) as c:
            c.execute("insert into sessions (smidja_id, smidja_name, request, status, started_at) values (?,?,?,?,?)",
                      (sid, "smidja_scout", "ask", status, trace.now_iso()))
            c.execute("insert into phases values (?,?,?,?,?,?,?,?,?,?,?)",
                      (f"{sid}-p1", sid, 1, "scout", "agent", "scout", "", "success", 0, 0, None))
        if child:
            p = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"])
            self.children.append(p)
            with sqlite3.connect(self.db) as c:
                c.execute("insert into processes (smidja_id, kind, name, pid, command, started_at) values (?,?,?,?,?,?)",
                          (sid, "agent", "scout", p.pid, f"{sys.executable} -c sleep", trace.now_iso()))
            return p
        return None


class TestPaths(Fenced):
    def test_the_trace_is_the_one_the_env_names(self):
        db, road = paths.db_path()
        self.assertEqual(db, self.db)
        self.assertEqual(road, "SMIDJA_DB")

    def test_without_ymir_home_the_trace_falls_to_xdg_state(self):
        os.environ.pop("SMIDJA_DB")
        db, road = paths.db_path()
        self.assertEqual(road, "XDG state")
        self.assertTrue(str(db).endswith("smidja/smidja.db"))

    def test_a_run_is_launched_with_the_one_trace(self):
        env = paths.run_env(paths.where())
        self.assertEqual(env["SMIDJA_DB"], str(self.db))
        self.assertEqual(env["SMIDJA_DATA_DIR"], str(self.db.parent))


class TestRefusals(Fenced):
    def test_an_ask_without_done_means_is_refused(self):
        code, out = cli.execute(["run", "scout", "look around", "--dry-run"])
        self.assertEqual(code, 1)
        self.assertIn("Done means", out["refused"])

    def test_an_ask_with_done_means_passes_the_check(self):
        code, out = cli.execute(["run", "scout", "look around.\nDone means: a list.", "--dry-run"])
        self.assertEqual(code, 0, out)
        self.assertIn("would_run", out)

    def test_the_kill_switch_blocks_a_run(self):
        paths.kill_switch().write_text("set\n")
        code, out = cli.execute(["run", "scout", "x.\nDone means: y.", "--dry-run"])
        self.assertEqual(code, 1)
        self.assertIn("kill-switch", out["refused"])

    def test_an_unknown_run_is_named(self):
        code, out = cli.execute(["phases", "nope"])
        self.assertEqual(code, 1)
        self.assertIn("no such run", out["refused"])

    def test_a_team_is_never_generated(self):
        code, out = cli.execute(["team", "new"])
        self.assertEqual(code, 1)
        self.assertIn("interviewing the operator", out["refused"])


class TestControl(Fenced):
    def test_stop_kills_the_child_and_closes_the_run(self):
        p = self.add_run()
        code, out = cli.execute(["stop", "r1"])
        self.assertEqual(code, 0, out)
        p.wait(timeout=10)
        self.assertEqual(trace.session(self.db, "r1")["status"], "fail")

    def test_pause_and_continue(self):
        p = self.add_run()
        self.assertEqual(cli.execute(["pause", "r1"])[1]["paused"], 1)
        time.sleep(0.2)
        state = Path(f"/proc/{p.pid}/stat").read_text().split()[2]
        self.assertEqual(state, "T")
        self.assertEqual(cli.execute(["continue", "r1"])[1]["continued"], 1)

    def test_steer_appends_to_the_runs_own_file(self):
        self.add_run(child=False)
        cli.execute(["steer", "r1", "use", "the", "small", "model"])
        cli.execute(["steer", "r1", "second"])
        text = (self.db.parent / "sessions" / "r1" / "steer.md").read_text()
        self.assertIn("use the small model", text)
        self.assertIn("second", text)

    def test_emergency_stop_kills_all_and_marks_aborted(self):
        p = self.add_run()
        code, out = cli.execute(["emergency-stop"])
        self.assertEqual(code, 0)
        p.wait(timeout=10)
        self.assertEqual(trace.session(self.db, "r1")["status"], "aborted")
        self.assertTrue(paths.kill_switch().exists())

    def test_watch_closes_a_run_with_nothing_alive(self):
        self.add_run(child=False)
        out = verbs.watch(paths.where(), once=True)
        self.assertEqual(out["closed_as_interrupted"], ["r1"])

    def test_a_recycled_pid_is_not_signalled(self):
        p = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"])
        self.children.append(p)
        with sqlite3.connect(self.db) as c:
            c.execute("insert into sessions (smidja_id, status) values ('r2','running')")
            c.execute("insert into processes (smidja_id, kind, name, pid, command) values ('r2','agent','x',?, 'pi planner')",
                      (p.pid,))
        self.assertEqual(trace.processes(self.db, "r2"), [])


class TestAudit(Fenced):
    def test_a_claimed_success_with_no_tool_calls_is_flagged(self):
        self.add_run(child=False, status="success")
        out = verbs.audit(paths.where(), "r1")
        self.assertTrue(any("ZERO tool calls" in f for f in out["flags"]))
        self.assertEqual(verbs.diagnose(paths.where(), "r1")["why"], "an agent claimed work it never did")


class TestDoors(Fenced):
    def test_the_mcp_lists_its_tools_and_answers_a_call(self):
        self.add_run(child=False)
        init = mcp_server.handle({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}})
        self.assertEqual(init["result"]["serverInfo"]["name"], "smidja")
        tools = mcp_server.handle({"jsonrpc": "2.0", "id": 2, "method": "tools/list"})["result"]["tools"]
        names = {t["name"] for t in tools}
        self.assertTrue({"smidja_run", "smidja_record", "smidja_control", "smidja_doctor"} <= names)
        for t in tools:
            self.assertIn("on", t["inputSchema"]["properties"], t["name"])
        reply = mcp_server.handle({"jsonrpc": "2.0", "id": 3, "method": "tools/call",
                                   "params": {"name": "smidja_phases", "arguments": {"smidja_id": "r1"}}})
        self.assertFalse(reply["result"]["isError"])
        self.assertEqual(json.loads(reply["result"]["content"][0]["text"])["smidja_id"], "r1")

    def test_a_notification_gets_no_reply(self):
        self.assertIsNone(mcp_server.handle({"jsonrpc": "2.0", "method": "notifications/initialized"}))

    def test_remote_argv_drops_on_and_json(self):
        self.assertEqual(cli._remote_argv(["run", "scout", "x", "--on", "whynot", "--json"]), ["run", "scout", "x"])
        self.assertEqual(cli._remote_argv(["doctor", "--on=whynot"]), ["doctor"])


class TestRunConfig(Fenced):
    """A project without its own engine runs on the installed smithy's: the run gets a config whose
    prompt paths are absolute, because the agents' cwd is the project, not the engine's root."""

    def test_prompt_paths_are_made_absolute_for_another_project(self):
        engine = FACTORY.parent / "smidja"
        if not (engine / "smidja_modules").is_dir():
            engine = FACTORY / "engine"
        project = Path(self.tmp.name) / "project"
        project.mkdir()
        subprocess.run(["git", "init", "-q", str(project)], check=True)
        os.environ["SMIDJA_ENGINE_DIR"] = str(engine)
        try:
            w = paths.where(str(project))
            self.assertNotEqual(w.root.resolve(), w.project.resolve())
            cfg = verbs.run_config(w, "rc1")
            self.assertTrue(str(cfg).startswith(str(self.db.parent)))
            text = cfg.read_text()
            systems = re.findall(r"system: (\S+)", text)
            self.assertTrue(systems)
            for path in systems:
                self.assertTrue(path.startswith("/"), path)
            self.assertIn("SMIDJA_DB", text)        # env placeholders survive for the engine to expand
        finally:
            os.environ.pop("SMIDJA_ENGINE_DIR", None)

    def test_a_project_with_its_own_engine_keeps_its_config(self):
        w = paths.where(str(FACTORY.parent.parent))
        if w.root and w.root.resolve() == w.project.resolve():
            self.assertEqual(verbs.run_config(w, "rc2"), w.config)


class TestTheBooksAreTheSpec(unittest.TestCase):
    """Every `scripts/smidja <verb>` the cookbooks and skills teach is a verb the runner answers."""

    def test_every_taught_verb_exists(self):
        taught = set()
        for book in list((FACTORY / "cookbooks").glob("*.md")) + list((FACTORY / "skills").glob("*/SKILL.md")):
            text = book.read_text()
            # Only command lines count: `scripts/smidja <verb>` anywhere, and `smidja <verb>`
            # where it opens a backtick span — prose that merely says "smidja runs" is not a verb.
            taught |= set(re.findall(r"scripts/smidja ([a-z][a-z-]+)", text))
            taught |= set(re.findall(r"`smidja ([a-z][a-z-]+)", text))
        known = set(re.findall(r'^\s+"([a-z-]+)": lambda', (RUNNER / "smidja_runner" / "cli.py").read_text(), re.M))
        prose = {"is", "the", "and", "skill", "factory", "launcher"}
        missing = sorted(taught - known - prose)
        self.assertEqual(missing, [], f"the books teach verbs the runner does not answer: {missing}")


if __name__ == "__main__":
    unittest.main()
