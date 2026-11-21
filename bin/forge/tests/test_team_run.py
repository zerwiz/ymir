#!/usr/bin/env python3
"""test_team_run.py — the run door sends the smithy where the operator says, and says so plainly.

Everything is fenced: a temp home, a stand-in `smidja` and a stand-in `ssh` that record what they were
asked and answer from the environment. Proved: the runtime comes from the machine's config and a flag
overrides it; a remote run goes over ssh through the machine's own alias; `auto` takes the least
loaded machine; the link is the machine's published one or says it is local; the phone answer is six
lines and names the runtime; a later status finds the machine the run went to.

Run: python3 bin/forge/tests/test_team_run.py   ·   exit 0 all pass, 1 a failure.
"""
from __future__ import annotations

import json
import os
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

DOOR = Path(__file__).resolve().parents[1] / "team-run.sh"

SMIDJA = """#!/usr/bin/env bash
echo "$@" >> "$FAKE_LOG"
case "$1" in
  run)    echo '{"smidja_id":"ab12cd34","chain":"smidja_scout","state":"running","team":"(the config default)","runtime":"'"$(printf '%s\\n' "$@" | grep -A1 -- --runtime | tail -1)"'","viewer":"http://127.0.0.1:8437/#/sessions/ab12cd34"}' ;;
  status) echo '{"smidja_id":"ab12cd34","state":"running","alive":true,"runtime":"herdr","team":"(default)","phase":"scout","phases_done":0,"phases_total":2,"last":"tool_call read","viewer":"http://127.0.0.1:8437/#/sessions/ab12cd34"}' ;;
  tail)   echo '{"smidja_id":"ab12cd34","events":[{"type":"tool_call","name":"read"},{"type":"log","name":"console"}]}' ;;
  stop)   echo '{"smidja_id":"ab12cd34","stopped":true}' ;;
esac
"""

SSH = """#!/usr/bin/env bash
echo "SSH $@" >> "$FAKE_LOG"
last="${@: -1}"
case "$last" in
  *loadavg*) host="$(printf '%s\\n' "$@" | grep -E '^(alpha|beta)$' | head -1)"
             case "$host" in alpha) echo "6.00 5 5 1/1 1"; echo 4 ;; beta) echo "0.40 1 1 1/1 1"; echo 4 ;; esac
             echo smithy ;;
  *bash\\ -lc*) echo '{"smidja_id":"zz99","chain":"smidja_scout","state":"running","team":"t","runtime":"herdr","viewer":"http://127.0.0.1:8437/#/sessions/zz99"}' ;;
esac
"""


class Door(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = Path(self.tmp.name)
        self.home = t / "home"
        (self.home / "hodd" / "data").mkdir(parents=True)
        (self.home / "hodd" / "data" / "fleet.json").write_text(json.dumps(
            {"hosts": {"alpha": {"roles": ["dev"]}, "beta": {"roles": ["dev"]}, "gamma": {"roles": ["dev"]}}}))
        for host, body in (("alpha", "runtime: herdr\nssh: alpha-t\nproject: /work/a\nlink: https://smithy-a.example.org\n"),
                           ("beta", "runtime: internal\nproject: /work/b\n")):
            d = self.home / "config" / "machines" / host
            d.mkdir(parents=True)
            (d / "smidja.yaml").write_text(body)
        self.bin = t / "bin"
        self.bin.mkdir()
        for name, text in (("smidja", SMIDJA), ("ssh", SSH)):
            f = self.bin / name
            f.write_text(text)
            f.chmod(f.stat().st_mode | stat.S_IXUSR)
        self.log = t / "calls.log"
        self.env = {**os.environ, "YMIR_HOME": str(self.home), "SMIDJA_BIN": str(self.bin / "smidja"),
                    "PATH": f"{self.bin}:{os.environ['PATH']}", "FAKE_LOG": str(self.log), "YMIR_HOSTNAME": "alpha"}

    def tearDown(self):
        self.tmp.cleanup()

    def door(self, *args):
        out = subprocess.run(["bash", str(DOOR), *args], capture_output=True, text=True, env=self.env, timeout=60)
        return out.returncode, out.stdout.strip()

    def calls(self):
        return self.log.read_text() if self.log.exists() else ""

    def test_the_runtime_comes_from_the_machines_config(self):
        code, out = self.door("run", "--task", "look", "--on", "alpha", "--json")
        self.assertEqual(code, 0, out)
        data = json.loads(out)
        self.assertEqual(data["runtime"], "herdr")
        self.assertIn("--runtime herdr", self.calls())
        self.assertIn("--project /work/a", self.calls())

    def test_a_flag_overrides_the_configured_runtime_for_one_run(self):
        code, out = self.door("run", "--task", "look", "--on", "alpha", "--runtime", "internal", "--json")
        self.assertEqual(json.loads(out)["runtime"], "internal")
        self.assertIn("--runtime internal", self.calls())

    def test_a_machine_with_no_config_runs_internal(self):
        code, out = self.door("run", "--task", "look", "--on", "gamma", "--project", "/p", "--json")
        # gamma is in the registry but is another machine: it is reached over ssh, by name
        self.assertEqual(code, 0, out)
        self.assertIn("SSH", self.calls())
        self.assertIn("--runtime internal", self.calls())

    def test_an_unknown_runtime_is_refused(self):
        code, out = self.door("run", "--task", "look", "--on", "alpha", "--runtime", "docker")
        self.assertEqual(code, 2)

    def test_a_remote_run_goes_over_ssh_through_the_machines_own_alias(self):
        code, out = self.door("run", "--task", "look", "--on", "gamma", "--project", "/p", "--json")
        self.assertEqual(code, 0, out)
        ssh = [l for l in self.calls().splitlines() if l.startswith("SSH")][0]
        self.assertIn("gamma", ssh)
        self.assertIn("bash -lc", ssh)
        self.assertEqual(json.loads(out)["machine"], "gamma")

    def test_the_ssh_alias_in_the_config_is_used(self):
        self.env["YMIR_HOSTNAME"] = "beta"
        code, out = self.door("run", "--task", "look", "--on", "alpha", "--json")
        self.assertEqual(code, 0, out)
        self.assertIn("alpha-t", self.calls())

    def test_auto_takes_the_least_loaded_machine(self):
        # alpha is this machine (the stand-in smidja is local); beta is probed over ssh at 0.10 per core.
        self.env["FAKE_LOG"] = str(self.log)
        code, out = self.door("run", "--task", "look", "--json")
        self.assertEqual(code, 0, out)
        data = json.loads(out)
        self.assertEqual(data["chosen"]["picked_by"], "lowest load per core")

    def test_a_published_link_is_used_and_a_missing_one_says_it_is_local(self):
        code, out = self.door("run", "--task", "look", "--on", "alpha", "--json")
        d = json.loads(out)
        self.assertEqual(d["link"], "https://smithy-a.example.org/#/sessions/ab12cd34")
        self.assertEqual(d["link_kind"], "published")
        self.env["YMIR_HOSTNAME"] = "beta"
        code, out = self.door("run", "--task", "look", "--on", "beta", "--json")
        d = json.loads(out)
        self.assertTrue(d["link_kind"].startswith("local to beta"))

    def test_the_phone_answer_is_at_most_six_lines_and_names_the_runtime(self):
        code, out = self.door("run", "--task", "look", "--on", "alpha", "--phone")
        self.assertEqual(code, 0, out)
        lines = out.splitlines()
        self.assertLessEqual(len(lines), 6)
        self.assertIn("herdr", out)
        self.assertIn("alpha", out)
        self.assertIn("https://smithy-a.example.org", lines[-1])

    def test_status_finds_the_machine_the_run_went_to(self):
        self.door("run", "--task", "look", "--on", "alpha", "--json")
        self.log.write_text("")
        code, out = self.door("status", "ab12cd34", "--phone")
        self.assertEqual(code, 0, out)
        self.assertIn("alpha", out)
        self.assertIn("herdr", out)

    def test_no_project_is_a_refusal_that_says_where_to_set_one(self):
        self.env["YMIR_HOSTNAME"] = "gamma"
        code, out = self.door("run", "--task", "look", "--on", "gamma")
        self.assertEqual(code, 1)
        self.assertIn("smidja.yaml", out)

    def test_an_empty_task_is_refused(self):
        code, out = self.door("run", "--task", " ", "--on", "alpha")
        self.assertEqual(code, 1)

    def test_an_unknown_machine_is_named(self):
        code, out = self.door("run", "--task", "look", "--on", "nowhere")
        self.assertEqual(code, 1)
        self.assertIn("nowhere", out)

    def test_where_lists_the_machines_with_their_runtime(self):
        code, out = self.door("where", "--json")
        self.assertEqual(code, 0, out)
        names = {m["host"]: m["runtime"] for m in json.loads(out)["machines"]}
        self.assertEqual(names.get("alpha"), "herdr")


if __name__ == "__main__":
    unittest.main()
