#!/usr/bin/env python3
"""test_arm_members — one member per live machine, ASCII addresses, agents named as agents. No network."""
import importlib.util
import sys
from pathlib import Path

spec = importlib.util.spec_from_file_location("arm_members", Path(__file__).resolve().parents[1] / "arm_members.py")
am = importlib.util.module_from_spec(spec)
spec.loader.exec_module(am)

RAW = ('host-a\tno answer\tssh: connect to host host-a port 22: Connection timed out\n'
       'host-b\theld\t  "ada","unknown"\n'
       'host-c\theld\t  "Frœði","claude"\n'
       'host-d\theld\t  "Þóra","counsellor"\n')


class Fake:
    def call(self, tool, **a):
        assert tool == "list_members"
        return {"members": [{"name": "froedi", "role": 15}]}


fails = []


def check(name, cond, got=""):
    print(("ok   " if cond else "FAIL ") + name + ("" if cond else f" — {got}"))
    if not cond:
        fails.append(name)


check("slug Frœði", am.ascii_slug("Frœði") == "froedi", am.ascii_slug("Frœði"))
check("slug Þóra", am.ascii_slug("Þóra") == "thora", am.ascii_slug("Þóra"))
rows = am.plan(RAW, board=Fake(), cfg_extra={"agent_mail_domain": "agents.example.org"})
check("one row per machine", [r["machine"] for r in rows] == ["host-a", "host-b", "host-c", "host-d"])
check("dark machine proposes nobody", rows[0]["address"] == "" and rows[0]["on_board"] == "unknown")
check("address is ascii", rows[2]["address"] == "froedi@agents.example.org", rows[2]["address"])
check("display says agent and machine", rows[1]["display"] == "Ada · host-b (agent)", rows[1]["display"])
check("member role, never admin", all(r.get("role", "member") == "member" for r in rows))
check("token subject per machine", rows[3]["token_subject"] == "tool:host-d-board")
check("existing member seen", rows[2]["on_board"] == "yes" and rows[3]["on_board"] == "no")
nodomain = am.plan(RAW, board=None, cfg_extra={})
check("no domain is named, not guessed", nodomain[1]["address"] == "" and "agent_mail_domain" in nodomain[1]["why"])
print(f"{'PASS' if not fails else 'FAIL'}: {len(fails)} failed")
sys.exit(1 if fails else 0)
