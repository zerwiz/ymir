"""The Hermes session hook (plan 317 slice 7): the digest on the first turn in ANY cwd, once."""

from __future__ import annotations

import io
import json
from pathlib import Path

from ymir_runtime.hermes import session_hook as H


def payload(event: str, session: str, cwd: str, first: bool = True) -> str:
    return json.dumps({"hook_event_name": event, "session_id": session, "cwd": cwd,
                       "extra": {"is_first_turn": first}})


def fake_digest(calls: list):
    def digest(env, root, session, timeout):
        calls.append(timeout)
        state = Path(env["YMIR_HERMES_STATE"])
        state.mkdir(parents=True, exist_ok=True)
        (state / f"digest.{session}.md").write_text("Sága · the short head\n")
        return True, "1 lines"
    return digest


def env_for(tmp_path: Path, **extra) -> dict:
    return {"HOME": str(tmp_path), "YMIR_HERMES_STATE": str(tmp_path / "state"),
            "YMIR_HOME": str(tmp_path / "home"), **extra}


def test_first_turn_outside_the_house_gets_the_digest_even_without_a_start_stash(tmp_path):
    calls: list = []
    env = env_for(tmp_path)
    out = H.handle(env, payload("pre_llm_call", "s1", "/somewhere/else"), root=tmp_path / "tree",
                   digest=fake_digest(calls), err=io.StringIO())
    got = json.loads(out)
    assert got["context"].startswith(H.HEADER) and "short head" in got["context"]
    assert calls == [H.FIRST_TURN_TIMEOUT], "the fallback digest runs inside the hook's budget"
    again = H.handle(env, payload("pre_llm_call", "s1", "/somewhere/else"), root=tmp_path / "tree",
                     digest=fake_digest(calls), err=io.StringIO())
    assert again == "{}"


def test_the_start_hook_stashes_and_returns_nothing(tmp_path):
    calls: list = []
    env = env_for(tmp_path)
    out = H.handle(env, payload("on_session_start", "s2", str(tmp_path)), root=tmp_path,
                   digest=fake_digest(calls), err=io.StringIO())
    assert out == "{}" and calls == [H.START_TIMEOUT]
    assert (tmp_path / "state" / "digest.s2.md").exists()


def test_house_scope_keeps_client_sessions_bare(tmp_path):
    env = env_for(tmp_path, YMIR_HERMES_DIGEST_SCOPE="house")
    out = H.handle(env, payload("pre_llm_call", "s3", "/client/project"), root=tmp_path / "tree",
                   digest=fake_digest([]), err=io.StringIO())
    assert out == "{}"
    inside = H.handle(env, payload("pre_llm_call", "s4", str(tmp_path / "tree" / "sub")), root=tmp_path / "tree",
                      digest=fake_digest([]), err=io.StringIO())
    assert "context" in json.loads(inside)


def test_later_turns_and_bad_payloads_are_noops(tmp_path):
    env = env_for(tmp_path)
    assert H.handle(env, payload("pre_llm_call", "s5", "/x", first=False), root=tmp_path,
                    digest=fake_digest([]), err=io.StringIO()) == "{}"
    assert H.handle(env, "not json", root=tmp_path, digest=fake_digest([]), err=io.StringIO()) == "{}"


def test_a_failed_digest_is_named_and_still_valid_json(tmp_path):
    err = io.StringIO()
    out = H.handle(env_for(tmp_path), payload("pre_llm_call", "s6", "/x"), root=tmp_path,
                   digest=lambda *a: (False, "saga exit 1"), err=err)
    assert out == "{}" and "saga exit 1" in err.getvalue()


def test_the_turn_end_hands_the_answer_to_the_reply_door(tmp_path):
    door = tmp_path / "tree" / "bin" / "agents" / "reply.sh"
    door.parent.mkdir(parents=True)
    door.write_text('cat > "$OUT"; printf %s "$YMIR_REPLY_ORIGIN" > "$OUT.who"\n')
    env = env_for(tmp_path, OUT=str(tmp_path / "got"), PATH="/usr/bin:/bin")
    raw = json.dumps({"hook_event_name": "post_llm_call", "session_id": "s9", "cwd": "/x",
                      "extra": {"user_message": "[from agent A] q", "assistant_response": "a", "turn_id": "t1"}})
    assert H.handle(env, raw, root=tmp_path / "tree", err=io.StringIO()) == "{}"
    got = json.loads((tmp_path / "got").read_text())
    assert got == {"session": "s9", "answer": "a", "messages": [{"id": "t1", "text": "[from agent A] q"}]}
    assert (tmp_path / "got.who").read_text().startswith("agent hermes · hermes session s9 · ")
