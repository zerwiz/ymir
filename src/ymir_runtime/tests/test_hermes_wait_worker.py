"""wait-worker (plan 317 slice 9): finished means not-working AND a handoff; a waiter announces only
what finished after it started; delivery waits out a busy session and never writes into a paused one."""

from __future__ import annotations

import sqlite3
from pathlib import Path

import pytest

from ymir_runtime.hermes import common as C
from ymir_runtime.hermes import wait_worker as W


def agent(name: str, status: str, cwd: Path) -> dict:
    return {"name": name, "agent_status": status, "cwd": str(cwd)}


def handoff(tree: Path, name: str) -> Path:
    p = tree / "docs" / "handoffs" / f"{name}.md"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text("# done\n")
    return p


@pytest.fixture()
def env(tmp_path: Path) -> dict:
    return {"HOME": str(tmp_path), "YMIR_HERMES_STATE": str(tmp_path / "state"),
            "HERMES_HOME": str(tmp_path / ".hermes")}


def test_idle_without_a_handoff_is_not_finished(tmp_path):
    done, working = W.survey([agent("w-a", "idle", tmp_path), agent("w-b", "working", tmp_path)],
                             prefix="w-", names=[])
    assert done == [] and working == ["w-b"]
    handoff(tmp_path, "w-a")
    done, _ = W.survey([agent("w-a", "idle", tmp_path)], prefix="w-", names=[])
    assert [d.name for d in done] == ["w-a"]


def test_once_announces_a_finish_once_and_cron_is_silent_when_nothing_new(env, tmp_path, monkeypatch):
    handoff(tmp_path, "w-a")
    monkeypatch.setattr(W, "herdr_agents", lambda e: [agent("w-a", "idle", tmp_path)])
    out: list[str] = []
    W.once(env, scope="cron", cron=True, prefix="w-", names=[], out=out.append)
    assert out and out[0].startswith("w-a finished (idle)")
    out.clear()
    W.once(env, scope="cron", cron=True, prefix="w-", names=[], out=out.append)
    assert out == []
    W.once(env, scope="other", cron=True, prefix="w-", names=[], out=out.append)
    assert out, "each consumer keeps its own seen-set"


def test_the_waiter_ignores_earlier_finishes_and_delivers_a_later_one(env, tmp_path):
    old, new = tmp_path / "old", tmp_path / "new"
    handoff(old, "w-old")
    calls = {"n": 0}

    def agents(_e):
        calls["n"] += 1
        rows = [agent("w-old", "idle", old), agent("w-new", "working", new)]
        if calls["n"] >= 3:
            handoff(new, "w-new")
            rows[1] = agent("w-new", "idle", new)
        return rows

    sent: list[tuple[str, str]] = []
    rc = W.foreground(env, session="s1", prefix="w-", names=[], poll=0, limit=60, include_finished=False,
                      out=lambda s: None, sleep=lambda s: None,
                      deliver_fn=lambda e, s, t: (sent.append((s, t)) or (True, "delivered")),
                      agents_fn=agents)
    assert rc == 0
    assert len(sent) == 1 and sent[0][0] == "s1"
    assert "w-new finished" in sent[0][1] and "w-old" not in sent[0][1]
    assert sent[0][1].startswith(W.STAMP)


def test_a_busy_session_is_retried_not_dropped(env, tmp_path):
    handoff(tmp_path, "w-a")
    answers = iter([(False, "busy: the session is mid-turn"), (True, "delivered")])
    log: list[str] = []
    rc = W.foreground(env, session="s1", prefix="w-", names=["w-a"], poll=0, limit=60, include_finished=True,
                      out=log.append, sleep=lambda s: None, deliver_fn=lambda e, s, t: next(answers),
                      agents_fn=lambda e: [agent("w-a", "idle", tmp_path)])
    assert rc == 0
    assert any("not yet delivered (busy" in ln for ln in log)
    assert any(ln.startswith("delivered:") for ln in log)


def test_delivery_refuses_a_paused_session(env, tmp_path):
    db = Path(env["HERMES_HOME"]) / "state.db"
    db.parent.mkdir(parents=True)
    con = sqlite3.connect(db)
    con.execute("CREATE TABLE session_admissions (target_session_id TEXT, status TEXT, seq INTEGER)")
    con.execute("INSERT INTO session_admissions VALUES ('s1', 'unknown', 1)")
    con.execute("INSERT INTO session_admissions VALUES ('s2', 'started', 1)")
    con.commit()
    con.close()
    ok, why = W.deliver(env, "s1", "x")
    assert not ok and why.startswith("paused")
    ok, why = W.deliver(env, "s2", "x")
    assert not ok and why.startswith("busy")


def test_no_session_is_a_named_refusal():
    with pytest.raises(C.HermesError) as exc:
        W.resolve_session({}, "")
    assert "--session" in exc.value.remedy


def test_supervise_starts_a_transient_unit_carrying_the_session(env, monkeypatch):
    seen: dict = {}

    def fake_run(argv, **kw):
        seen["argv"] = list(argv)
        return C.Result(0, "", "")

    monkeypatch.setattr(C, "run", fake_run)
    out: list[str] = []
    assert W.supervise(env, session="local-abc", prefix="w-", names=["w-a"], poll=30, limit=60,
                       include_finished=False, out=out.append) == 0
    argv = seen["argv"]
    assert argv[:3] == ["systemd-run", "--user", "--unit"]
    assert "--collect" in argv and "--foreground" in argv
    assert argv[argv.index("--session") + 1] == "local-abc"
    assert "PYTHONUNBUFFERED=1" in argv
    assert out[0].startswith("supervised: unit ymir-wait-worker-")


def test_a_bad_handoff_flag_is_refused():
    with pytest.raises(C.HermesError):
        W.parse_handoffs(["no-equals"])
