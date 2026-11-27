#!/usr/bin/env python3
"""The answer-back router behind bin/agents/reply.sh (see its header for the verbs).

One parser for the stamp, one choice of road, one ledger. Harness hooks hand it the turn's messages and the
final answer; it decides who, if anyone, is owed that answer.
"""
from __future__ import annotations

import fcntl
import hashlib
import json
import os
import re
import socket
import stat
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
CAP = 1500  # one line typed into a terminal; the whole answer is kept in a file past this

PANE = r"w[0-9A-Za-z]+:p[0-9A-Za-z]+"
MACHINE = r"[A-Za-z0-9._-]+"
STAMP = re.compile(r"^\[(reply from|from) ([^\]\n]*)\]\s*")
WRAP = re.compile(r"^\s*<pasted_content[^>]*>\s*")
# Lines a harness puts into a turn by itself: nobody typed them. U+2063 is the mark of Ymir's own operational
# input (bin/agents/rodd-operational-input.sh).
INJECTED = ("<task-notification", "<system-reminder", "Stop hook feedback", "\u2063", "[brokk-from-primary]\u2063")
# What a sender gets instead of an answer the operator's own turn produced: his conversation stays with him.
RECEIPT = ("Receipt: your line was read here in a turn of the operator's own, so the answer of that turn is not "
           "passed on. Anything meant for you is sent separately.")


def door(env: str, rel: str) -> str:
    return os.environ.get(env) or str(ROOT / "bin" / rel)


def me() -> str:
    return os.environ.get("YMIR_REPLY_HOST") or socket.gethostname().split(".")[0]


def state() -> Path:
    base = os.environ.get("YMIR_REPLY_STATE") or os.path.join(
        os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "ymir", "replies")
    p = Path(base)
    p.mkdir(parents=True, exist_ok=True)
    return p


def flat(text: str) -> str:
    """One line with no control characters: it is typed into terminals."""
    return " ".join(re.sub(r"[\x00-\x08\x0b-\x1f\x7f-\x9f]", " ", text or "").split())


def parse(line: str) -> tuple[str, str]:
    """(kind, origin) of a message: kind is 'from', 'reply' or 'none'. Only a LEADING stamp counts."""
    rest = WRAP.sub("", line or "").lstrip()
    first = ""
    while True:
        m = STAMP.match(rest)
        if not m:
            break
        if m.group(1) == "reply from":  # some roads add their own stamp in front of a reply
            return "reply", m.group(2)
        first = first or m.group(2)
        rest = rest[m.end():]
    return ("from", first) if first else ("none", "")


def present(who: str) -> bool:
    """Is the operator there? Only a message stamped as his own says so; an agent or a script means he is not."""
    return who.startswith(("the Allfather", "Rödd", "a person at terminal"))


def his_turn(messages: list[dict]) -> bool:
    """Is the operator in this turn? A line stamped as his, or one with no stamp that no harness injected."""
    for msg in messages:
        text = str(msg.get("text") or "")
        kind, origin = parse(text)
        if kind == "from" and present(origin.split(" · ")[0].strip()):
            return True
        bare = WRAP.sub("", text).lstrip()
        if kind == "none" and bare and not msg.get("synthetic") and not bare.startswith(INJECTED):
            return True
    return False


def road(origin: str) -> dict:
    parts = [p.strip() for p in origin.split(" · ")]
    who = parts[0]
    machine = parts[-1] if len(parts) > 1 and re.fullmatch(MACHINE, parts[-1]) else me()
    out = {"road": "none", "address": "", "machine": machine, "who": who, "why": "", "him": False}
    him = present(who)
    out["him"] = him
    # "arm <machine>" is the road to that machine's arm holder (bin/agents/sender.sh gives it to a dispatch that
    # had no pane of its own). A pane, a session or a terminal in the same stamp is nearer and wins.
    arm = next((m.group(1) for p in parts[1:] for m in [re.fullmatch(rf"arm ({MACHINE})", p)] if m), "")
    if who.startswith("script") or who.startswith("fleet-tell"):
        if arm:
            return {**out, "road": "arm", "address": "holder", "machine": arm}
        return {**out, "why": f"'{who}' is a script: nobody waits for an answer"}
    # The roads that reach HIM (the room, his chat, his terminal) open only for a message stamped as his own.
    if him and "Rödd" in who:
        return {**out, "road": "rodd", "address": "room"}
    if him and re.search(r"\bTelegram\b", who, re.I):
        return {**out, "road": "telegram", "address": "operator"}
    m = re.fullmatch(r"a person at terminal (/dev/(?:pts/\d+|tty\d+))", who)
    if m:
        return {**out, "road": "terminal", "address": m.group(1)}
    for p in parts:
        m = re.fullmatch(r"hermes session ([A-Za-z0-9._-]+)", p)
        if m:
            return {**out, "road": "hermes", "address": m.group(1)}
    for p in parts:
        m = re.fullmatch(rf"herdr pane ({PANE})", p)
        if m:
            return {**out, "road": "pane", "address": m.group(1)}
    if arm:
        return {**out, "road": "arm", "address": "holder", "machine": arm}
    return {**out, "why": f"the stamp '{origin}' names no pane, room, terminal, chat or session to answer"}


def run(argv: list[str], timeout: int = 90, env: dict | None = None, text: str | None = None) -> tuple[int, str]:
    try:
        r = subprocess.run(argv, capture_output=True, text=True, timeout=timeout, input=text,
                           stdin=None if text is not None else subprocess.DEVNULL,
                           env={**os.environ, **(env or {})})
    except (OSError, subprocess.TimeoutExpired) as exc:
        return 127, str(exc)
    out = (r.stdout + r.stderr).strip()
    return r.returncode, (out.splitlines() or [""])[-1][:160]


def ssh_road(machine: str) -> str:
    reg = os.environ.get("YMIR_FLEET_REGISTRY")
    if not reg:
        rc = subprocess.run(["bash", "-c", '. "$1" && ymir_home_root H && printf %s "$H"', "_",
                             str(ROOT / "bin/vault/hoard-lib.sh")], capture_output=True, text=True)
        reg = os.path.join(rc.stdout.strip(), "hodd/data/fleet.json")
    try:
        h = json.load(open(reg, encoding="utf-8"))["hosts"][machine]
        return f"{h['user']}@{h['tailnet']}"
    except (OSError, KeyError, ValueError, TypeError):
        return ""


def to_arm(r: dict, line: str, why: str) -> tuple[bool, str]:
    """The road refused: the arm holder of that machine gets the line, so it is never lost."""
    note = f"undelivered answer for {r['road']} {r['address']} ({why}): {line}"
    if r["machine"] == me():
        rc, out = run(["bash", door("YMIR_REPLY_ARM", "voice/rodd-arm.sh"), "tell", "--class", "report",
                       "--from", "reply door", note])
    else:
        rc, out = run(["bash", door("YMIR_REPLY_FLEET", "fleet/fleet-tell.sh"), "--arm-only", "--to",
                       r["machine"], "--", note])
    if rc == 0:
        return True, f"queued for the arm holder on {r['machine']} ({why})"
    return False, f"{why}; the arm did not take it either: {out}"


def is_holder(r: dict) -> bool:
    """Is that pane the arm holder's? Asked of the machine it stands on (bin/fleet/arm-holder-pane.sh)."""
    if r["machine"] == me():
        _, out = run(["bash", door("YMIR_REPLY_HOLDER", "fleet/arm-holder-pane.sh")])
    else:
        dest = ssh_road(r["machine"])
        if not dest:
            return False
        _, out = run(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=6", dest,
                      "bash -lc 'd=${YMIR_RUNTIME_DIR:-$HOME/ymir-runtime}; cd $d && bash bin/fleet/arm-holder-pane.sh'"])
    return out.strip() == r["address"]


def to_holder(r: dict, line: str, origin: str) -> tuple[bool, str]:
    if r["machine"] == me():
        rc, out = run(["bash", door("YMIR_REPLY_ARM", "voice/rodd-arm.sh"), "tell", "--class", "report",
                       "--from", origin, line])
    else:
        rc, out = run(["bash", door("YMIR_REPLY_FLEET", "fleet/fleet-tell.sh"), "--arm-only", "--to",
                       r["machine"], "--", line], 120)
    return (True, "the arm holder's wake queue") if rc == 0 else (False, f"the arm did not take it: {out}")


def deliver(r: dict, answer: str) -> tuple[bool, str]:
    body = flat(answer)
    if len(body) > CAP:
        keep = state() / "long" / (hashlib.sha256(body.encode()).hexdigest()[:16] + ".md")
        keep.parent.mkdir(parents=True, exist_ok=True)
        keep.write_text(answer + "\n", encoding="utf-8")
        body = f"{body[:CAP]} … (the whole answer: {keep} on {me()})"
    origin = flat(os.environ.get("YMIR_REPLY_ORIGIN") or f"agent in a session · {me()}").replace("]", ")")
    line = f"[reply from {origin}] {body}"
    here = r["machine"] == me()
    kind = r["road"]
    if kind == "arm":
        return to_holder(r, line, origin)
    if kind == "pane":
        if is_holder(r):  # its input box is often in use: the wake queue is its road (the fixed core)
            return to_holder(r, line, origin)
        if here:
            rc, out = run(["bash", door("YMIR_REPLY_SEND", "agents/eindri-send.sh"), r["address"], line],
                          env={"EINDRI_SEND_WAIT": os.environ.get("EINDRI_SEND_WAIT", "4")})
        else:
            rc, out = run(["bash", door("YMIR_REPLY_FLEET", "fleet/fleet-tell.sh"), "--to",
                           f"{r['machine']}:{r['address']}", "--", line], 120)
        return (True, "pane") if rc == 0 else to_arm(r, line, f"the pane did not take it: {out}")
    if kind == "rodd":
        if here:
            rc, out = run(["bash", door("YMIR_REPLY_ROOM", "voice/rodd-room.sh"), "reply", f"{origin}: {body}"],
                          env={"RODD_ROOM_FROM": origin})
            if rc == 0:
                return True, "Rödd's room"
        return to_arm(r, line, "only the arm holder writes in Rödd's room — relay it there")
    if kind == "terminal":
        if here:
            try:
                st = os.stat(r["address"])
                if not stat.S_ISCHR(st.st_mode) or st.st_uid != os.getuid():
                    raise OSError("not a terminal of this user")
                fd = os.open(r["address"], os.O_WRONLY | os.O_NOCTTY | os.O_NONBLOCK)
                try:
                    os.write(fd, f"\r\n{line}\r\n".encode())
                finally:
                    os.close(fd)
                return True, "terminal"
            except OSError as exc:
                return to_arm(r, line, f"the terminal is gone: {exc}")
        dest = ssh_road(r["machine"])
        if dest:
            rc, out = run(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=6", dest,
                           f"test -c {r['address']} && cat > {r['address']}"], 30, text=f"\r\n{line}\r\n")
            if rc == 0:
                return True, "terminal"
        return to_arm(r, line, "the terminal could not be reached")
    if kind == "telegram":
        key = "reply." + hashlib.sha256(line.encode()).hexdigest()[:16]
        rc, out = run(["bash", door("YMIR_REPLY_NOTIFY", "notify/send.sh"), "--source", "errand", "--severity",
                       "INFO", "--ask", "--key", key, "--message", line])
        return (True, "telegram") if rc == 0 else to_arm(r, line, f"Telegram refused: {out}")
    if kind == "hermes":
        rc, out = run(["bash", door("YMIR_REPLY_TELL", "agents/tell.sh"), "--from", origin,
                       f"hermes:{r['address']}", line], 180)
        return (True, "hermes") if rc == 0 else to_arm(r, line, f"Hermes refused: {out}")
    return False, r["why"] or "no way back"


def target_id(r: dict) -> str:
    return hashlib.sha256(f"{r['road']}|{r['machine']}|{r['address']}".encode()).hexdigest()[:24]


def is_self(r: dict) -> bool:
    return r["road"] == "pane" and r["machine"] == me() and r["address"] == os.environ.get("YMIR_REPLY_PANE")


def manual_marker(r: dict, session: object = None) -> Path:
    """"I answered that sender by hand", kept per replier: another agent's word to the same sender is not mine."""
    me_here = os.environ.get("YMIR_REPLY_PANE") or str(session or os.environ.get("HERMES_SESSION_ID") or "")
    who = hashlib.sha256(me_here.encode()).hexdigest()[:12]
    return state() / "manual" / f"{who}.{target_id(r)}"


def mark_manual(r: dict) -> None:
    marker = manual_marker(r)
    marker.parent.mkdir(exist_ok=True)
    marker.write_text(f"{time.time()}\n")


def errand_record(errand: str) -> dict:
    """What bin/agents/sender.sh recorded at dispatch: origin= (who sent it) and shelf= (where its question goes)."""
    if not re.fullmatch(r"[A-Za-z0-9_-][A-Za-z0-9._-]*", errand or ""):
        return {}
    try:
        text = (state() / "errands" / errand).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return {}
    got = dict(line.split("=", 1) for line in text.splitlines() if "=" in line)
    return got if got.get("origin") else {}


def errand_here() -> str:
    """The errand this process works for: its seat's variables, else its eindri/<id> branch. Recorded ones only."""
    names = [os.environ.get("YMIR_ERRAND_ID"), os.environ.get("YMIR_SMITH")]
    rc, branch = run(["git", "rev-parse", "--abbrev-ref", "HEAD"], 10)
    if rc == 0 and branch.startswith("eindri/"):
        names.append(branch[len("eindri/"):])
    return next((n for n in names if n and errand_record(n)), "")


def file_question(errand: str, shelf: str, question: str) -> Path:
    box = Path(shelf) / "eindri-questions"
    box.mkdir(parents=True, exist_ok=True)
    path = box / f"{errand}.md"
    new = not path.exists() or not path.stat().st_size
    with open(path, "a", encoding="utf-8") as fh:
        fh.write(f"{question}\n" if new else f"\n{question}\n")
        fh.write(f"\n(asked {datetime.now().astimezone().isoformat(timespec='seconds')})\n")
    return path


def report(rows: list[tuple[str, str, bool, str]]) -> None:
    q = lambda s: '"' + flat(str(s)).replace('"', "'") + '"'  # noqa: E731
    print(f"reply[{len(rows)}]{{road,to,delivered,why}}:")
    for kind, to, ok, why in rows:
        print(f"  {q(kind)},{q(to)},{q('yes' if ok else 'no')},{q(why)}")


def turn_end(doc: dict) -> int:
    """One answer per message; senders only; never an answer to a reply.

    A turn the operator is in answers him: each agent heard in it gets a short receipt, never that answer."""
    answer = str(doc.get("answer") or "").strip()
    if os.environ.get("YMIR_REPLY_AUTO") == "0" or not answer:
        return 0
    done = state() / "done"
    done.mkdir(exist_ok=True)
    owed: dict[str, dict] = {}
    messages = doc.get("messages") or []
    his = his_turn(messages)
    wakes = owed_wakes(float(doc.get("answered_at") or time.time()))
    for n, msg in enumerate([*messages, *wakes]):
        text = str(msg.get("text") or "")
        kind, origin = parse(text)
        if kind != "from":
            continue
        r = road(origin)
        if r["road"] == "none" or is_self(r):
            continue
        session = "wake" if str(msg.get("id", "")).startswith("wake:") else doc.get("session")  # a redelivered wake
        key = hashlib.sha256(f"{session}|{msg.get('id', n)}|{text}".encode()).hexdigest()
        try:
            (done / key).touch(exist_ok=False)  # the claim: two hooks on one turn send once
        except FileExistsError:
            continue
        marker = manual_marker(r, doc.get("session"))
        since = float(msg.get("since") or 0)
        if since and marker.exists() and marker.stat().st_mtime >= since:
            continue  # the agent already answered this sender by hand during the turn
        owed[target_id(r)] = r
    rows = []
    for r in owed.values():
        ok, why = deliver(r, answer if r["him"] or not his else RECEIPT)
        rows.append((r["road"], f"{r['machine']}:{r['address']}", ok, why))
        consume(r)
    if rows:
        report(rows)
    return 0 if all(row[2] for row in rows) else 1


def owe_wakes(lines: list[str], pane: str) -> None:
    """The drain showed the arm holder these queue lines: note each agent sender, to be answered at turn end."""
    box = state() / "owed" / pane
    for line in lines:
        m = re.search(r"(?:^|\t|— )([^\t]*?) to the arm holder: ([^\t]*)", line)
        if not m:
            continue
        origin, text = m.group(1).split("— ")[-1].strip(), m.group(2)
        r = road(origin)
        if r["him"] or r["road"] not in ("pane", "hermes", "arm") or "[reply from " in text:
            continue
        key = hashlib.sha256(line.encode()).hexdigest()[:32]
        (state() / "owed-seen").mkdir(exist_ok=True)
        try:
            (state() / "owed-seen" / key).touch(exist_ok=False)  # a wake shown again is not owed again
        except FileExistsError:
            continue
        box.mkdir(parents=True, exist_ok=True)
        (box / key).write_text(f"[from {origin}] {text}\n", encoding="utf-8")


def owed_wakes(answered_at: float) -> list[dict]:
    """Wakes this pane was shown BEFORE the answer was written: that answer is theirs. Each is taken once."""
    pane = os.environ.get("YMIR_REPLY_PANE")
    box = state() / "owed" / pane if pane else None
    out = []
    for f in sorted(box.glob("*")) if box and box.is_dir() else []:
        seen = f.stat().st_mtime
        if seen <= answered_at:
            out.append({"id": f"wake:{f.name}", "text": f.read_text(encoding="utf-8"), "since": seen})
            f.unlink(missing_ok=True)
    return out


def consume(r: dict) -> None:
    """The message in this pane's inbox is answered: a bare reply must not send a second answer to it."""
    pane = os.environ.get("YMIR_REPLY_PANE")
    box = state() / "inbox" / pane if pane else None
    if box and box.exists():
        kind, origin = parse(box.read_text(encoding="utf-8", errors="replace"))
        if kind != "none" and target_id(road(origin)) == target_id(r):
            box.unlink(missing_ok=True)


def stamp_time(value: object) -> float:
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00")).timestamp()
    except ValueError:
        return 0.0


def entry_text(content: object) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(b.get("text", "") for b in content if isinstance(b, dict) and b.get("type") == "text")
    return ""


def injected(origin: object) -> bool:
    """Claude Code names who opened an entry; anything but a person is the harness's own."""
    return isinstance(origin, dict) and origin.get("kind") not in (None, "human")


def claude_turn(hook: dict) -> dict:
    """The turn that just ended, from Claude Code's transcript: the prompt that opened it, the lines queued into
    it while it ran, and the final answer."""
    messages: list[dict] = []
    answer = ""
    answered_at = 0.0
    with open(hook["transcript_path"], encoding="utf-8", errors="replace") as fh:
        for raw in fh:
            try:
                d = json.loads(raw)
            except ValueError:
                continue
            if d.get("isSidechain"):
                continue
            att = d.get("attachment") or {}
            if d.get("type") == "user" and not d.get("isMeta") and not d.get("isCompactSummary"):
                text = entry_text((d.get("message") or {}).get("content"))
                if not text:
                    continue  # a tool result, not a new turn
                messages = [{"id": d.get("uuid"), "text": text, "since": stamp_time(d.get("timestamp")),
                             "synthetic": injected(d.get("origin"))}]
                answer = ""
            elif d.get("type") == "attachment" and att.get("type") == "queued_command":
                messages.append({"id": att.get("source_uuid") or d.get("uuid"), "text": entry_text(att.get("prompt")),
                                 "since": stamp_time(d.get("timestamp")),
                                 "synthetic": injected(att.get("origin"))})
            elif d.get("type") == "assistant":
                said = entry_text((d.get("message") or {}).get("content"))
                if said:
                    answer, answered_at = said, stamp_time(d.get("timestamp"))
    return {"session": hook.get("session_id"), "messages": messages, "answered_at": answered_at,
            "answer": hook.get("last_assistant_message") or answer}


def verdict(path: str, offset: int) -> str:
    """What Claude Code wrote after this stop: 'blocked' (the turn goes on), 'ended', or '' (not said yet).

    Every Stop hook runs side by side and the verdict is written only when they have all returned, so it is read
    from the transcript afterwards: a block leaves a "Stop hook feedback" entry, an ended turn its summary."""
    with open(path, "rb") as fh:
        fh.seek(offset)
        tail = fh.read().decode("utf-8", "replace")
    ended = False
    for raw in tail.splitlines():
        try:
            d = json.loads(raw)
        except ValueError:
            continue
        if d.get("isSidechain"):
            continue
        att = d.get("attachment") or {}
        if d.get("type") == "assistant" or att.get("type") == "hook_blocking_error":
            return "blocked"
        if d.get("type") == "user" and entry_text((d.get("message") or {}).get("content")).startswith("Stop hook feedback"):
            return "blocked"
        if d.get("type") == "system" and d.get("subtype") in ("stop_hook_summary", "turn_duration"):
            if d.get("preventedContinuation") is not True:
                ended = True
    return "ended" if ended else ""


def anchor(path: str, said: str) -> int:
    """The byte just after the answer this stop is about: the last assistant text in the transcript.

    A file size taken at hook start is too late: each hook's refusal is written as soon as THAT hook returns, often
    before this door is up. The answer itself is always before every verdict. When the harness names the answer and
    it is not written yet, wait a moment for it."""
    limit = time.time() + 5
    while True:
        end = at = 0
        found = ""
        with open(path, "rb") as fh:
            for raw in fh:
                end += len(raw)
                try:
                    d = json.loads(raw)
                except ValueError:
                    continue
                if d.get("type") == "assistant" and not d.get("isSidechain"):
                    text = entry_text((d.get("message") or {}).get("content"))
                    if text:
                        at, found = end, text
        if not said or found.strip() == said.strip() or time.time() >= limit:
            return at
        time.sleep(0.2)


def settle(path: str, offset: int) -> bool:
    """Wait for the verdict. With none inside the limit, the turn is held to be over."""
    limit = time.time() + float(os.environ.get("YMIR_REPLY_SETTLE", "660"))
    while True:
        got = verdict(path, offset)
        if got == "ended":
            time.sleep(float(os.environ.get("YMIR_REPLY_GRACE", "1")))  # a late block still wins
            return verdict(path, offset) != "blocked"
        if got == "blocked":
            return False
        if time.time() >= limit:
            return True
        time.sleep(0.5)


def detach() -> None:
    """Let the hook return now (its verdict waits on it) and carry on alone."""
    sys.stdout.flush()
    if os.fork():
        os._exit(0)
    os.setsid()
    log = os.open(state() / "hook.log", os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
    null = os.open(os.devnull, os.O_RDONLY)
    for src, dst in ((null, 0), (log, 1), (log, 2)):
        os.dup2(src, dst)


def main(argv: list[str]) -> int:
    if argv[0] == "--parse":
        kind, origin = parse(" ".join(argv[1:]))
        r = road(origin) if origin else {"road": "none", "address": "", "machine": ""}
        print("reply-parse[1]{kind,road,machine,address,operator_there}:")
        print(f'  "{kind}","{r["road"]}","{r["machine"]}","{r["address"]}","{"yes" if r.get("him") else "no"}"')
        return 0
    if argv[0] == "--sent":  # bin/agents/eindri-send.sh: this agent just sent a line to that pane by hand
        if len(argv) > 2:
            mark_manual(road(f"agent · herdr pane {argv[2]} · {argv[1]}"))
        return 0
    if argv[0] == "--owe":
        pane = os.environ.get("YMIR_REPLY_PANE")
        if pane:
            owe_wakes(sys.stdin.read().splitlines(), pane)
        return 0
    if argv[0] in ("--turn-end", "--claude-stop"):
        try:
            doc = json.loads(sys.stdin.read() or "{}")
            if argv[0] == "--claude-stop":
                path = doc["transcript_path"]
                offset = anchor(path, str(doc.get("last_assistant_message") or ""))
                if os.environ.get("YMIR_REPLY_FOREGROUND") != "1":
                    detach()
                if not settle(path, offset):
                    return 0  # the stop was refused: nothing is claimed, the stop that ends the turn sends
                doc = claude_turn(doc)
            with open(state() / ".lock", "w") as lock:
                fcntl.flock(lock, fcntl.LOCK_EX)
                return turn_end(doc)
        except (OSError, ValueError, KeyError, AttributeError) as exc:
            print(f"reply: the turn could not be read, so nothing was answered — {exc}", file=sys.stderr)
            return 1
    to, errand, ask, text, i = "", "", False, [], 0
    while i < len(argv):
        if argv[i] in ("--to", "--errand") and i + 1 < len(argv):
            if argv[i] == "--to":
                to = argv[i + 1]
            else:
                errand = argv[i + 1]
            i += 2
            continue
        if argv[i] == "--ask":
            ask, i = True, i + 1
            continue
        text.append(argv[i])
        i += 1
    body = " ".join(text).strip()
    if not body:
        print('reply: give the answer: reply.sh [--to <stamp|pane|machine:pane> | --errand <id>] [--ask] "<text>"',
              file=sys.stderr)
        return 2
    if ask:
        errand = errand or errand_here()
        record = errand_record(errand)
        if not record:
            print("reply: no sender is recorded for this errand — name it with --errand <id>. Nothing was sent.",
                  file=sys.stderr)
            return 3
        try:
            filed = file_question(errand, record.get("shelf") or str(state()), body)
        except OSError as exc:
            print(f"reply: the question could not be filed, so nothing was sent — {exc}", file=sys.stderr)
            return 1
        print(f"reply: question filed at {filed}")
        body = (f"QUESTION from errand {errand}, waiting for your answer: {body} — answer with "
                f"bin/agents/eindri-answer.sh {errand} \"<answer>\" on {me()}")
    pane = os.environ.get("YMIR_REPLY_PANE")
    box = state() / "inbox" / pane if pane else None
    if not to and not errand and not (box and box.exists()):
        errand = errand_here()
    if errand:
        record = errand_record(errand)
        if not record:
            print(f"reply: no sender is recorded for the errand {errand}. Nothing was sent.", file=sys.stderr)
            return 3
        if os.environ.get("YMIR_REPLY_ORIGIN", "").startswith("agent in a session"):
            os.environ["YMIR_REPLY_ORIGIN"] = os.environ["YMIR_REPLY_ORIGIN"].replace("in a session", errand, 1)
    if errand:
        r = road(record["origin"])
    elif to:
        m = re.fullmatch(rf"(?:({MACHINE}):)?({PANE})", to)
        if m:
            r = road(f"agent · herdr pane {m.group(2)} · {m.group(1) or me()}")
        else:
            kind, origin = parse(to)
            r = road(origin if kind != "none" else to)
    else:
        if not box or not box.exists():
            print("reply: no stamped message is waiting for an answer here — name the sender with --to. "
                  "Nothing was sent.", file=sys.stderr)
            return 3
        r = road(parse(box.read_text(encoding="utf-8", errors="replace"))[1])
    if r["road"] == "none":
        print(f"reply: no way back — {r['why']}. Nothing was sent.", file=sys.stderr)
        return 3
    if is_self(r):
        print("reply: that sender is this very pane. Nothing was sent.", file=sys.stderr)
        return 3
    ok, why = deliver(r, body)
    if ok:
        mark_manual(r)
        consume(r)
    report([(r["road"], f"{r['machine']}:{r['address']}", ok, why)])
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
