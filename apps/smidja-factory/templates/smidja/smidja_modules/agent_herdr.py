"""herdr coding-agent interface — the smidja seats its agent in a pane.

The third surface beside `agent_pi` (v1) and `agent_opencode`. Where those two
own a child process and read its stdout, herdr owns the TERMINAL: the agent runs
interactively in a pane a person can watch, and the smidja speaks to it and
reads what it said.

That difference is the whole reason this module exists, and it is also where it
must be careful. A pane is not a pipe:

  * the raise goes through the ONE spawn path (`bin/seat/herdr-run.sh`), so the
    house's own laws — isolation, the model allow-list, the one-local-model lock,
    the seat guard — still apply to a factory agent;
  * the prompt goes in as a stamped turn (`bin/agents/eindri-send.sh`), so the
    pane can tell the smidja from the Allfather;
  * the reply is read from the terminal (`herdr agent read <pane>`), which is
    what a person sees — but a TUI wraps and renders, so the exact words are
    taken from the agent's own session record when the rendered text does not
    parse. Both roads are reported; neither is guessed.

Envelope parsing is NOT done here. This module returns the agent's text in a
`PiResult`, exactly as `agent_pi.run` does, and `agents._parse_with_retries`
parses it against the declared output type — so a bad JSON re-prompts the SAME
session (the same pane, the same context window) with the same bounded retries.
One parser, three surfaces.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import time
from pathlib import Path
from typing import Callable, Optional

from . import agent_pi
from .data_types import PiRequest, PiResult
from .utils import now_iso, operator_env

HERDR_PATH = os.environ.get("HERDR_PATH", "herdr")


def _repo_root() -> Path:
    """The tree that owns `bin/` — found, never assumed.

    This module sits at `<repo>/smidja/smidja_modules/` in a stamped repo and at
    `<repo>/apps/smidja/smidja_modules/` in the smithy's own checkout, so the
    depth is not a constant. Walk up for the door itself.
    """
    for candidate in Path(__file__).resolve().parents:
        if (candidate / "bin" / "seat" / "herdr-run.sh").is_file():
            return candidate
    return Path(__file__).resolve().parents[3]


ROOT = _repo_root()
HDR_RUN = ROOT / "bin" / "seat" / "herdr-run.sh"
SEND = ROOT / "bin" / "agents" / "eindri-send.sh"
WATCH = ROOT / "bin" / "agents" / "eindri-watch.sh"

READY_TIMEOUT_S = int(os.environ.get("SMIDJA_HERDR_READY_S", "120"))
TURN_TIMEOUT_S = int(os.environ.get("SMIDJA_HERDR_TURN_S", "1800"))
READ_LINES = int(os.environ.get("SMIDJA_HERDR_READ_LINES", "4000"))
SEAT_FILE = "herdr_seat.json"

# pi's footer, as it renders in a pane:
#   ↑197k ↓130k R42M CH99.8% $0.233 31.4%/1.0M (auto)
_FOOTER = re.compile(
    r"↑(?P<up>\d+(?:\.\d+)?[kKmM]?)\s+↓(?P<down>\d+(?:\.\d+)?[kKmM]?)(?P<rest>.*)")
_PERCENT = re.compile(r"(?P<pct>\d+(?:\.\d+)?)%/(?P<window>\d+(?:\.\d+)?[kKmM])")
_COST = re.compile(r"\$(?P<cost>\d+(?:\.\d+)?)")


# ── the seat record ──────────────────────────────────────────────────────────

def seat_path(raw_output_path: str | Path) -> Path:
    """Where an agent's seat is recorded — beside its raw output, one per agent."""
    return Path(raw_output_path).parent / SEAT_FILE


def load_seat(raw_output_path: str | Path) -> dict:
    path = seat_path(raw_output_path)
    try:
        return json.loads(path.read_text())
    except (OSError, json.JSONDecodeError):
        return {}


def save_seat(raw_output_path: str | Path, seat: dict) -> None:
    path = seat_path(raw_output_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(seat, indent=2))


def seat_for(raw_output_path: str | Path) -> Optional[dict]:
    """The recorded seat for this agent, if it names a live pane."""
    seat = load_seat(raw_output_path)
    return seat if seat.get("pane") else None


def close_seats(session_dir: str | Path) -> list[str]:
    """Close every herdr pane this run opened, and retire its watch.

    Called when a run finishes. A factory that leaves its panes behind is the
    27-shells fault the house already paid for once: a shell whose owner is gone
    still answers `agent list`, so the board shows a team that no longer exists.
    """
    closed: list[str] = []
    for seat_file in sorted(Path(session_dir).glob(f"*/{SEAT_FILE}")):
        try:
            seat = json.loads(seat_file.read_text())
        except (OSError, json.JSONDecodeError):
            continue
        pane, tab, name = seat.get("pane"), seat.get("tab"), seat.get("name")
        if not pane:
            continue
        if seat.get("keep") or os.environ.get("SMIDJA_HERDR_KEEP") == "1":
            seat["state"] = "kept"
            seat_file.write_text(json.dumps(seat, indent=2))
            continue
        # The PANE, not the tab: a tab may hold another seat, and `tab close`
        # takes a tab id, not a pane id (measured: `tab close wN:p5` is a
        # tab_not_found, `pane close wN:p5` is the seat going away).
        _hdr(["pane", "close", pane], timeout=20)
        if WATCH.is_file() and name:
            subprocess.run(["bash", str(WATCH), "retire", str(name)],
                           capture_output=True, text=True, timeout=30)
        seat["state"] = "closed"
        seat["closed_at"] = now_iso()
        seat_file.write_text(json.dumps(seat, indent=2))
        closed.append(pane)
    return closed


# ── the pane, as herdr sees it ───────────────────────────────────────────────

def _hdr(args: list[str], timeout: int = 60) -> subprocess.CompletedProcess:
    return subprocess.run([HERDR_PATH, *args], capture_output=True, text=True,
                          timeout=timeout, env=operator_env(), check=False)


def _agents() -> list[dict]:
    """Every agent herdr knows about, or [] when it cannot answer."""
    out = _hdr(["agent", "list"], timeout=30)
    if out.returncode != 0:
        return []
    try:
        return (json.loads(out.stdout or "{}").get("result") or {}).get("agents") or []
    except json.JSONDecodeError:
        return []


def _agent_by_name(name: str) -> Optional[dict]:
    for agent in _agents():
        if agent.get("name") == name:
            return agent
    return None


def _agent_by_pane(pane: str) -> Optional[dict]:
    for agent in _agents():
        if agent.get("pane_id") == pane:
            return agent
    return None


def _status(agent: Optional[dict]) -> str:
    return str((agent or {}).get("agent_status") or (agent or {}).get("status") or "unknown")


def available() -> tuple[bool, str]:
    """Can a seat be raised here at all? A clean no names why (Rule 25)."""
    if os.environ.get("SMIDJA_HERDR") == "0":
        return False, "SMIDJA_HERDR=0 — the herdr surface is switched off for this run"
    if os.environ.get("HERDR_ENV") != "1":
        return False, "not inside herdr (HERDR_ENV unset) — a pane needs a herdr session"
    if not shutil.which(HERDR_PATH):
        return False, f"{HERDR_PATH} is not on PATH"
    if not HDR_RUN.is_file():
        return False, f"the one spawn path is missing: {HDR_RUN}"
    if not _agents() and _hdr(["status"], timeout=20).returncode != 0:
        return False, "herdr answers neither `agent list` nor `status`"
    return True, "ok"


# ── the raise ────────────────────────────────────────────────────────────────

def _seat_name(request: PiRequest) -> str:
    """A stable, greppable seat name: `smj-<run8>-<agent>`."""
    agent = request.agent or Path(request.session_dir).parent.name or "agent"
    run = (request.smidja_id or "run")[:8]
    return f"smj-{run}-{agent}"


def seat_brief(request: PiRequest) -> str:
    """What the door injects at the raise: who is seated, and what comes next.

    It is a TASK by the door's own test (`worth-a-smith` wants a verb and words),
    and it is true: the agent's real brief follows as the next turn.
    """
    return (f"You are seated by the Smíðja to build run {request.smidja_id or 'unknown'} "
            f"as {request.agent or 'an agent'} — read the brief in the next message and "
            f"carry out the work it describes, then answer with the Report JSON it asks for.")


def raise_seat(request: PiRequest, brief: str) -> dict:
    """Raise one agent in its own pane, through the ONE spawn path.

    `herdr-run.sh eindri` is asked with the run's own tree as the seat's cwd and
    the agent's rendered system prompt as an appended system prompt — the two
    facts the smithy has and the door did not. The watch is not armed: a factory
    seat is watched by the run's trace, not by the errand handoff (an armed watch
    would file a REPORT and wake the helm for every phase).
    """
    ok, why = available()
    if not ok:
        raise RuntimeError(f"cannot seat a herdr agent: {why}")

    name = _seat_name(request)
    existing = _agent_by_name(name)
    if existing and existing.get("pane_id"):
        seat = {"name": name, "pane": existing["pane_id"], "tab": existing.get("tab_id", ""),
                "raised_at": now_iso(), "reused": True, "cwd": str(request.cwd)}
        save_seat(request.raw_output_path, seat)
        return seat

    system_file = Path(request.raw_output_path).parent / "herdr_system.md"
    system_file.parent.mkdir(parents=True, exist_ok=True)
    system_file.write_text(request.system_prompt)

    cmd = ["bash", str(HDR_RUN), "eindri", name,
           "--kind", "pi",
           "--model", request.model,
           "--seat-cwd", str(Path(request.cwd).resolve()),
           "--system-prompt-file", str(system_file.resolve()),
           "--", brief]
    env = operator_env()
    env["YMIR_HERDR_AGENT_WAIT"] = "0"       # this module does its own waiting
    env["YMIR_HERDR_WATCH"] = "0"            # a factory seat is watched by the trace
    proc = subprocess.run(cmd, capture_output=True, text=True, cwd=str(Path(request.cwd).resolve()),
                          env=env, timeout=READY_TIMEOUT_S + 60, check=False)
    if proc.returncode != 0:
        raise RuntimeError(
            "herdr-run.sh refused the seat "
            f"(exit {proc.returncode}): {(proc.stderr or proc.stdout).strip()[-800:]}")

    deadline = time.monotonic() + READY_TIMEOUT_S
    agent = None
    while time.monotonic() < deadline:
        agent = _agent_by_name(name)
        if agent and agent.get("pane_id") and agent.get("interactive_ready", True):
            break
        time.sleep(2)
    if not agent or not agent.get("pane_id"):
        raise RuntimeError(f"the pane was made but no agent answered to {name!r} — "
                           f"read it with `herdr agent read` (see {HDR_RUN} output)")

    seat = {
        "name": name,
        "pane": agent["pane_id"],
        "tab": agent.get("tab_id", ""),
        "cwd": str(Path(request.cwd).resolve()),
        "raised_at": now_iso(),
        "agent": request.agent,
        "model": request.model,
        "session_id": request.session_id,
    }
    save_seat(request.raw_output_path, seat)
    return seat


# ── the word in, the word out ────────────────────────────────────────────────

def send(pane: str, text: str, sender: str = "smidja") -> None:
    """One stamped turn into the seated agent, through the house's send door."""
    proc = subprocess.run(["bash", str(SEND), "--from", sender, pane, text],
                          capture_output=True, text=True, env=operator_env(),
                          timeout=120, check=False)
    if proc.returncode != 0:
        raise RuntimeError(f"eindri-send.sh failed for {pane}: "
                           f"{(proc.stderr or proc.stdout).strip()[-400:]}")


def _turns(session_path: str) -> int:
    """How many user turns the agent's own record holds — the landing signal."""
    count = 0
    if not session_path:
        return 0
    try:
        with open(session_path, encoding="utf-8", errors="replace") as handle:
            for line in handle:
                if '"role":"user"' in line.replace(" ", ""):
                    count += 1
    except OSError:
        return 0
    return count


def send_confirmed(pane: str, text: str, sender: str = "smidja",
                   tries: int = 3, settle_s: int = 20) -> bool:
    """Send, then PROVE the agent took it. A prompt that lands while pi is still
    booting is swallowed in silence — the failure this house has already paid for
    once ("it started but nothing was injected"). So the door's exit code is not
    the proof: a new user turn in the agent's own record is.
    """
    before = _turns(_session_path(pane))
    for attempt in range(1, tries + 1):
        send(pane, text, sender=sender)
        deadline = time.monotonic() + settle_s
        while time.monotonic() < deadline:
            if _turns(_session_path(pane)) > before:
                return True
            if _status(_agent_by_pane(pane)) == "working":
                return True
            time.sleep(1)
    return False


def wait_turn(pane: str, timeout_s: int = TURN_TIMEOUT_S) -> str:
    """Block until the pane stops working. Returns the state it settled in.

    `agent wait` matches the FIRST of done|idle it sees — and an agent that has
    not started yet is idle, which is why this waits for `working` first.
    """
    deadline = time.monotonic() + min(60, timeout_s)
    while time.monotonic() < deadline:
        if _status(_agent_by_pane(pane)) == "working":
            break
        time.sleep(1)
    _hdr(["agent", "wait", pane, "--until", "done", "--until", "idle",
          "--timeout", str(timeout_s * 1000)], timeout=timeout_s + 30)
    return _status(_agent_by_pane(pane))


def read_pane(pane: str) -> str:
    """What the pane says, as a person sees it."""
    out = _hdr(["agent", "read", pane, "--source", "recent-unwrapped",
                "--lines", str(READ_LINES), "--format", "text"], timeout=60)
    return out.stdout if out.returncode == 0 else ""


def _session_path(pane: str) -> str:
    """The agent's own session record, as herdr reports it for this pane."""
    agent = _agent_by_pane(pane) or {}
    session = agent.get("agent_session") or {}
    value = str(session.get("value") or "")
    return value if session.get("kind") == "path" and value else ""


def read_session(path: str) -> dict:
    """The last assistant turn from the agent's own record: text, usage, id.

    A pane renders and wraps; a session record is the exact bytes. This is the
    second road, used for the envelope when the terminal text does not parse and
    always for the usage numbers a pane only prints in a footer.
    """
    found: dict = {"text": "", "session_id": "", "usage": {}, "finish": ""}
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                try:
                    record = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if record.get("type") == "session" and record.get("id"):
                    found["session_id"] = str(record["id"])
                if record.get("type") != "message":
                    continue
                message = record.get("message") or {}
                if message.get("role") != "assistant":
                    continue
                text = "".join(part.get("text", "")
                               for part in message.get("content") or []
                               if isinstance(part, dict) and part.get("type") == "text")
                if text:
                    found["text"] = text
                found["usage"] = message.get("usage") or found["usage"]
                found["finish"] = str(message.get("stopReason") or "")
    except OSError:
        return found
    return found


# ── the envelope, found in what was said ─────────────────────────────────────

def _balanced_objects(text: str) -> list[str]:
    """Every top-level {...} in `text`, outermost first, in order."""
    found, depth, start = [], 0, -1
    in_string = escaped = False
    for i, char in enumerate(text):
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue
        if char == '"':
            in_string = True
        elif char == "{":
            if depth == 0:
                start = i
            depth += 1
        elif char == "}":
            if depth:
                depth -= 1
                if depth == 0 and start >= 0:
                    found.append(text[start:i + 1])
    return found


def extract_envelope(text: str) -> str:
    """The last JSON object in `text` that parses, or "" when none does.

    A pane wraps long lines mid-token (`multi-agent` arrives as `multi Asian`),
    so the candidate is also tried with every newline removed: inside a JSON
    document a line break is never significant, and a JSON string cannot contain
    a raw newline — so removing them is exact, not a guess.
    """
    if not text:
        return ""
    candidates: list[str] = []
    for block in re.findall(r"```(?:json)?\s*(.*?)```", text, re.S):
        candidates.extend(_balanced_objects(block))
    candidates.extend(_balanced_objects(text))
    for candidate in reversed(candidates):
        for attempt in (candidate, candidate.replace("\n", "").replace("\r", "")):
            try:
                json.loads(attempt)
            except json.JSONDecodeError:
                continue
            return attempt
    return ""


# ── usage, as the pane prints it ─────────────────────────────────────────────

def _count(token: str) -> int:
    token = token.strip()
    suffix = token[-1:].upper()
    scale = {"K": 1_000, "M": 1_000_000}.get(suffix, 1)
    try:
        return int(float(token[:-1] if scale > 1 else token) * scale)
    except ValueError:
        return 0


def read_footer(text: str) -> dict:
    """The numbers pi prints at the foot of a pane: tokens, cost, occupancy."""
    foot = {"input_tokens": 0, "output_tokens": 0, "cost": 0.0,
            "context_tokens": 0, "percent": 0.0}
    match = None
    for match in _FOOTER.finditer(text or ""):
        pass                                  # the last footer wins
    if not match:
        return foot
    foot["input_tokens"] = _count(match.group("up"))
    foot["output_tokens"] = _count(match.group("down"))
    rest = match.group("rest") or ""
    if cost := _COST.search(rest):
        foot["cost"] = float(cost.group("cost"))
    if pct := _PERCENT.search(rest):
        foot["percent"] = float(pct.group("pct"))
        foot["context_tokens"] = int(_count(pct.group("window")) * foot["percent"] / 100)
    return foot


def _window(model: str) -> int:
    """The model's ceiling from pi's catalog — never a table here."""
    try:
        provider, model_id = agent_pi.resolve_model(model)
        return agent_pi.context_window(provider, model_id)
    except Exception:                                    # noqa: BLE001 — a missing catalog is not fatal
        return 0


# ── the interface entry point ────────────────────────────────────────────────

def run(request: PiRequest, on_event: Optional[Callable[[dict], None]] = None,
        on_spawn: Optional[Callable[[int], None]] = None,
        on_exit: Optional[Callable[[int], None]] = None) -> PiResult:
    """One turn with an agent seated in a herdr pane.

    First call for a session raises the pane; every later call — a JSON retry, a
    gate correction, a continuation — speaks into the SAME pane, so the agent's
    context is intact and the human keeps watching the same seat.
    """
    seat = load_seat(request.raw_output_path)
    live = seat.get("pane") and _agent_by_pane(seat["pane"])
    if not live:
        # The raise carries a SEAT BRIEF, not the work: the door injects it the
        # moment the pane exists, and pi may still be booting. The work goes in
        # afterwards through eindri-send, where it can be confirmed.
        seat = raise_seat(request, seat_brief(request))

    pane = seat["pane"]
    sender = f"smidja {request.smidja_id or ''}".strip()
    if not send_confirmed(pane, request.prompt, sender=sender):
        # One more, slower, before failing: a slow model start is not a refusal.
        if not send_confirmed(pane, request.prompt, sender=sender, tries=2, settle_s=45):
            raise RuntimeError(
                f"the prompt never landed in {pane} — the agent's own record shows no "
                f"new turn. Read the pane: `herdr agent read {pane}`")

    state = wait_turn(pane)
    pane_text = read_pane(pane)
    session_path = _session_path(pane)
    session = read_session(session_path) if session_path else {}

    # THE EXACT WORDS FIRST. A pane is a RENDER — box borders, hard wraps, a
    # footer — so a JSON object pulled out of it can come back subtly wrong (a
    # token split across a wrap arrives as two). The agent's own session record
    # is the byte-exact reply, which is what `agent_pi` parses from its stdout.
    # The pane is still read, still recorded, and is the fallback when herdr
    # cannot name a session file.
    envelope = extract_envelope(session.get("text", ""))
    road = "session" if envelope else ""
    if not envelope:
        envelope = extract_envelope(pane_text)
        road = "pane" if envelope else "none"

    raw_path = Path(request.raw_output_path)
    raw_path.parent.mkdir(parents=True, exist_ok=True)
    with raw_path.open("a") as raw:
        raw.write(json.dumps({"type": "herdr_read", "at": now_iso(), "pane": pane,
                              "state": state, "road": road,
                              "envelope_found": bool(envelope),
                              "session": session_path,
                              "text": pane_text[-200_000:]}) + "\n")

    # The numbers come from the agent's own record first — the same `usage`
    # object pi writes for every turn, which is what `agent_pi` reads from its
    # stdout. The pane's footer is the fallback, because a footer is a render
    # (it can be captured mid-paint, and a pane read that lands between turns
    # shows the previous frame's numbers).
    footer = read_footer(pane_text)
    usage = session.get("usage") or {}
    tokens = int(usage.get("totalTokens") or sum(usage.get(k) or 0
                                                 for k in ("input", "output", "cacheRead", "cacheWrite")))
    cost = float((usage.get("cost") or {}).get("total") or 0.0) if isinstance(usage.get("cost"), dict) else 0.0
    result = PiResult(
        text=envelope or session.get("text", "") or pane_text,
        returncode=0,
        session_id=session.get("session_id") or request.session_id,
        tokens=tokens or (footer["input_tokens"] + footer["output_tokens"]),
        cost=cost or footer["cost"],
        context_tokens=tokens or footer["context_tokens"],
        context_window=_window(request.model),
        last_usage=usage,
        last_finish=session.get("finish", ""),
    )
    if usage:
        result.usage.add_turn(usage, tokens)
    if on_spawn:
        on_spawn(0)          # a pane is not a pid; the tracer records the pane instead
    if on_event:
        on_event({"type": "herdr_turn", "pane": pane, "state": state,
                  "road": road, "surface": "herdr",
                  "tokens": result.tokens, "cost": result.cost})
    if on_exit:
        on_exit(0)

    seat.update({"session_id": result.session_id, "last_state": state,
                 "last_road": road, "last_turn_at": now_iso()})
    save_seat(request.raw_output_path, seat)
    return result
