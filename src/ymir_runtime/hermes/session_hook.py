"""Hermes' session side of the Gná arm: the Sága digest, and its delivery (plan 177 H4, plan 317 slice 7).

Hermes runs this for two shell hooks (`hooks:` in `~/.hermes/config.yaml`), one command each:

    on_session_start  run `bin/time/saga-session-start.sh` once, stash its digest, bind the session.
                      Hermes ignores this event's return, so the digest is stashed, not injected.
    pre_llm_call      on the FIRST turn of the session return {"context": <digest>} — the documented
                      injection shape. If the start hook never stashed one (a surface that skips it,
                      a digest that failed), the digest is taken now, inside the hook's own budget.
                      Every later turn answers {}.

SCOPE (slice 7). RULES/51: Ymir runs globally, so the digest is injected in ANY working directory by
default. `YMIR_HERMES_DIGEST_SCOPE=house` keeps the old behaviour (only inside the house: this tree,
the recorded seat roots and the private home) for an operator who wants client sessions bare.

The wire is Hermes' own: a JSON payload on stdin, an OPTIONAL JSON directive on stdout. This hook
never fails the harness: every path prints a valid `{}` and exits 0; the reason for a skip goes to
stderr, named.
"""

from __future__ import annotations

import json
import socket
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Mapping, TextIO

from .. import paths as paths_mod
from . import common as C

DEFAULT_CAP = 12000
START_TIMEOUT = 180.0
# pre_llm_call runs under Hermes' 60 s hook timeout; the fallback digest must finish inside it.
FIRST_TURN_TIMEOUT = 45.0
HEADER = "=== YMIR SESSION START (Sága) ===\n"


@dataclass(frozen=True)
class Envelope:
    event: str
    session: str
    cwd: str
    first: bool


def envelope(raw: str) -> Envelope:
    try:
        d = json.loads(raw or "{}")
    except ValueError:
        return Envelope("", "", "", False)
    if not isinstance(d, dict):
        return Envelope("", "", "", False)
    extra = d.get("extra") or {}
    event = str(d.get("hook_event_name") or "")
    first = extra.get("is_first_turn", event == "on_session_start") if isinstance(extra, dict) else False
    return Envelope(event, str(d.get("session_id") or ""), str(d.get("cwd") or ""), bool(first))


def house_roots(env: Mapping[str, str], root: Path) -> list[Path]:
    roots = [root]
    seat_roots = C.user_home(env) / ".pi" / "agent" / "extensions" / ".ymir-root"
    try:
        roots += [Path(line.strip()) for line in seat_roots.read_text().splitlines()[:5] if line.strip()]
    except OSError:
        pass
    try:
        roots.append(paths_mod.ymir_home(env))
    except Exception:  # noqa: BLE001 — an unresolvable home only narrows the house
        pass
    return roots


def in_scope(env: Mapping[str, str], cwd: str, root: Path) -> bool:
    if (env.get("YMIR_HERMES_DIGEST_SCOPE") or "any").lower() != "house":
        return True
    if not cwd:
        return False
    here = Path(cwd)
    return any(here == r or r in here.parents for r in house_roots(env, root))


def take_digest(env: Mapping[str, str], root: Path, session: str, timeout: float) -> tuple[bool, str]:
    door = root / "bin" / "time" / "saga-session-start.sh"
    if not door.exists():
        return False, f"no digest door at {door}"
    r = C.run(["bash", str(door)], timeout=timeout, env=env, cwd=str(root))
    if r.rc != 0 or not r.out.strip():
        return False, f"saga-session-start.sh exit {r.rc}: {(r.err or '').strip()[-160:]}"
    state = C.state_dir(env)
    state.mkdir(parents=True, exist_ok=True)
    (state / f"digest.{session}.md").write_text(r.out if r.out.endswith("\n") else r.out + "\n")
    (state / "digest.latest.md").write_text(r.out if r.out.endswith("\n") else r.out + "\n")
    (state / "session").write_text(f"harness=hermes\nsession={session}\nroot={root}\nat={C.now_iso()}\n")
    return True, f"{len(r.out.splitlines())} lines"


def answer_back(env: Mapping[str, str], raw: str, root: Path, session: str, err: TextIO) -> None:
    """The road back: hand the turn's message and final answer to bin/agents/reply.sh, which decides who is owed."""
    door = root / "bin" / "agents" / "reply.sh"
    try:
        extra = json.loads(raw).get("extra") or {}
    except (ValueError, AttributeError):
        return
    prompt, answer = extra.get("user_message"), extra.get("assistant_response")
    if not door.exists() or not isinstance(prompt, str) or not isinstance(answer, str):
        return
    doc = json.dumps({"session": session, "answer": answer,
                      "messages": [{"id": extra.get("turn_id") or "", "text": prompt}]})
    who = f"agent hermes · hermes session {session} · {socket.gethostname().split('.')[0]}"
    try:
        r = subprocess.run(["bash", str(door), "--turn-end"], input=doc, capture_output=True, text=True, timeout=50,
                           env={**env, "YMIR_REPLY_ORIGIN": who})
        if r.returncode:
            print(f"hermes-session-hook: the answer was not delivered — {(r.stdout + r.stderr).strip()[-200:]}", file=err)
    except (OSError, subprocess.TimeoutExpired) as exc:
        print(f"hermes-session-hook: the answer was not delivered — {exc}", file=err)


def handle(env: Mapping[str, str], raw: str, *, root: Path | None = None,
           digest: Callable[[Mapping[str, str], Path, str, float], tuple[bool, str]] = take_digest,
           err: TextIO = sys.stderr) -> str:
    """The hook's stdout for one payload — always valid JSON."""
    root = root or C.tree_root()
    e = envelope(raw)
    if not e.event or not e.session or e.session == "-":
        return "{}"
    if e.event == "post_llm_call":
        answer_back(env, raw, root, e.session, err)
        return "{}"
    state = C.state_dir(env)
    stash = state / f"digest.{e.session}.md"
    if e.event == "on_session_start":
        ok, why = digest(env, root, e.session, START_TIMEOUT)
        print(f"hermes-session-hook: {'digest stashed for ' + e.session + ' (' + why + ')' if ok else 'no digest — ' + why}",
              file=err)
        return "{}"
    if e.event != "pre_llm_call" or not e.first:
        return "{}"
    if not in_scope(env, e.cwd, root):
        print(f"hermes-session-hook: {e.cwd} is outside the house and the scope is 'house' — no digest", file=err)
        return "{}"
    if (state / f"injected.{e.session}").exists():
        return "{}"
    if not stash.exists() or not stash.stat().st_size:
        ok, why = digest(env, root, e.session, FIRST_TURN_TIMEOUT)
        if not ok:
            print(f"hermes-session-hook: no digest on the first turn — {why}", file=err)
            return "{}"
    try:
        body = stash.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        print(f"hermes-session-hook: digest unreadable — {exc}", file=err)
        return "{}"
    cap = int(env.get("YMIR_HERMES_DIGEST_CAP") or DEFAULT_CAP)
    if len(body) > cap:
        body = body[:cap] + (f"\n\n[digest truncated at {cap} characters — the whole of it is {stash}]")
    try:
        (state / f"injected.{e.session}").write_text("1\n")
    except OSError as exc:
        print(f"hermes-session-hook: could not mark the injection — {exc}", file=err)
    return json.dumps({"context": HEADER + body})


def main(env: Mapping[str, str] | None = None, stdin: TextIO = sys.stdin, stdout: TextIO = sys.stdout) -> int:
    env = C.environ(env)
    try:
        raw = stdin.read()
        stdout.write(handle(env, raw) + "\n")
    except Exception as exc:  # noqa: BLE001 — the hook must never fail the harness; the reason is named
        print(f"hermes-session-hook: {type(exc).__name__}: {exc}", file=sys.stderr)
        stdout.write("{}\n")
    return 0
