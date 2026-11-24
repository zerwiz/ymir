#!/usr/bin/env python3
"""Proofs for the Nornir status resolver (plan 365): a job is judged on the seat that OWNS it.

The heart's account of its runs is a prepared `--last` answer in the resolver's cache (as the ssh ring
would have fetched it); the forge answers nothing and is dark. Three cases are the ones the Allfather
named: a job that is not this seat's is never "DOWN"; the forge being dark names DARK, and MOVED when the
heart ran the row instead; one script at two times of day is judged at each time.

    python3 tests/test_nornir_status.py
"""
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
NOW = 1795521600  # 2026-11-24T12:00:00Z


def main():
    me = os.uname().nodename.split(".")[0]
    d = tempfile.mkdtemp(prefix="nornir-status-")
    state = os.path.join(d, "state")
    os.makedirs(os.path.join(state, ".nornir-status"))
    reg = os.path.join(d, "fleet.json")
    json.dump({"hosts": {me: {"roles": ["dev"]}, "hostb": {"roles": ["heart"], "user": "u"},
                         "hostc": {"roles": ["forge"], "dark_since": "2026-10-26"},
                         "hostd": {"roles": ["old"], "user": "u"}}}, open(reg, "w"))
    cfg = os.path.join(d, "cron.yaml")
    open(cfg, "w").write("\n".join([
        "@heart 06:00 bin/a.sh",            # ran fine on the heart            -> ELSEWHERE
        "@heart 07:00 bin/b.sh",            # the heart's run failed           -> FAILED
        "@heart 07:20 bin/c.sh",            # no run on record, time passed    -> LATE
        "@heart 18:10 bin/d.sh",            # evening row of a script          -> DUE
        "@heart 06:10 bin/d.sh",            # morning row of the same script   -> ELSEWHERE
        "@forge 00:30 bin/e.sh",            # forge dark, heart ran it         -> MOVED
        "@forge 01:00 bin/f.sh",            # forge dark, nobody ran it        -> LATE (fallback) or DARK
        "@old 08:00 bin/g.sh",              # a seat too old to report        -> UNREAD, not counted
        "",
    ]))
    heart = "\n".join([
        "#state\trunning\t42", f"#now\t{NOW}\t+0000", "#log\t/heart/cron.log",
        "bin/a.sh\t2026-11-24T06:00:01Z\t\t\t",
        "bin/b.sh\t2026-11-24T07:00:01Z\t2026-11-24T07:00:01Z\t1\t",
        "bin/d.sh\t2026-11-24T06:10:02Z\t\t\t",
        "bin/e.sh\t2026-11-24T00:30:01Z\t\t\t", ""])
    open(os.path.join(state, ".nornir-status", "hostb.txt"), "w").write(heart)
    open(os.path.join(state, ".nornir-status", "hostd.txt"), "w").write("bin/x.sh\t2026-11-24T06:00:01Z\t\t\t\n")
    env = dict(os.environ, BROKK_STATE_OVERRIDE=state, YMIR_HOME=d, BROKK_ROLES="dev")
    out = subprocess.run([sys.executable, os.path.join(ROOT, "bin/time/nornir-status.py"), "--json", "--no-ssh",
                          "--config", cfg, "--registry", reg, "--state", state], capture_output=True, text=True, env=env)
    res = json.loads(out.stdout)
    got = [(j["cmd"], j["at"], j["status"]) for j in res["jobs"]]
    want = {("bin/a.sh", "06:00"): "ELSEWHERE", ("bin/b.sh", "07:00"): "FAILED", ("bin/c.sh", "07:20"): "LATE",
            ("bin/d.sh", "18:10"): "DUE", ("bin/d.sh", "06:10"): "ELSEWHERE", ("bin/e.sh", "00:30"): "MOVED",
            ("bin/g.sh", "08:00"): "UNREAD"}
    bad = [(k, v, [g for g in got if g[:2] == k]) for k, v in want.items() if (k + (v,)) not in got]
    assert not bad, bad
    assert not any(j["status"] == "DOWN" for j in res["jobs"]), "a job that is not this seat's must never be DOWN"
    f = next(j for j in res["jobs"] if j["cmd"] == "bin/f.sh")
    assert f["status"] in ("LATE", "DARK") and f["next"], f
    # the headline counts only LATE + FAILED + DOWN + DARK
    assert res["needs"] == sum(1 for j in res["jobs"] if j["status"] in ("LATE", "FAILED", "DOWN", "DARK")), res["counts"]
    assert out.returncode == 1  # something needs him
    # solo: no registry, no heart — a heart-gated row is idle, never DARK, and nothing waits on a seat
    json.dump({"hosts": {}}, open(reg, "w"))
    solo = json.loads(subprocess.run([sys.executable, os.path.join(ROOT, "bin/time/nornir-status.py"), "--json", "--no-ssh", "--config", cfg,
                                      "--registry", reg, "--state", state], capture_output=True, text=True, env=env).stdout)
    assert not any(j["status"] in ("DARK", "DOWN") for j in solo["jobs"]), solo["counts"]
    print("ok: nornir-status — %d jobs, counts %s" % (len(got), res["counts"]))


if __name__ == "__main__":
    main()
