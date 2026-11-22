#!/usr/bin/env python3
"""veil.py — the Veil's ledger and its roads (bin/agents/veil.sh is the door; read its header)."""
from __future__ import annotations

import fcntl
import json
import os
import re
import secrets
import socket
import subprocess
import sys
import time
from pathlib import Path

STATE = Path(os.environ["VEIL_STATE"])
LEDGER = STATE / "ledger.jsonl"
RECEIPT_S = int(os.environ.get("VEIL_RECEIPT_S", "120") or 120)
RED_S = int(os.environ.get("VEIL_RED_S", "600") or 600)
PANE_TRIES = int(os.environ.get("VEIL_PANE_TRIES", "3") or 3)
TELL = os.environ.get("VEIL_TELL_DOOR", "")
PANE = os.environ.get("VEIL_PANE_DOOR", "")
REPLY = os.environ.get("VEIL_REPLY_DOOR", "")
HERMES = os.environ.get("VEIL_HERMES_CLI", "hermes")
ANSWERS = {"received": "RECEIVED", "accepted": "ACCEPTED", "rework": "REWORK"}


def die(msg: str, code: int = 2) -> None:
    print(f"veil: {msg}", file=sys.stderr)
    sys.exit(code)


def q(v) -> str:
    return '"' + str(v).replace('"', "'") + '"'


def flat(text: str) -> str:
    return " ".join(str(text).split())


def append(event: dict) -> None:
    STATE.mkdir(parents=True, exist_ok=True)
    event.setdefault("ts", int(time.time()))
    with open(LEDGER, "a", encoding="utf-8") as fh:
        fcntl.flock(fh, fcntl.LOCK_EX)
        fh.write(json.dumps(event, ensure_ascii=False) + "\n")
        fh.flush()
        fcntl.flock(fh, fcntl.LOCK_UN)


def items() -> dict[str, dict]:
    out: dict[str, dict] = {}
    if not LEDGER.exists():
        return out
    for raw in LEDGER.read_text(encoding="utf-8", errors="replace").splitlines():
        try:
            ev = json.loads(raw)
        except ValueError:
            continue
        iid, kind = ev.get("id"), ev.get("event")
        if not iid:
            continue
        it = out.setdefault(iid, {"id": iid, "events": []})
        it["events"].append(kind)
        if kind == "sent":
            it.update({k: ev.get(k, "") for k in ("from", "kind", "text", "reply_to", "host")})
            it["sent"] = ev.get("ts", 0)
        elif kind in ANSWERS:
            it[kind] = ev.get("ts", 0)
            it[kind + "_by"] = ev.get("by", "")
            it[kind + "_note"] = ev.get("note", "")
        elif kind in ("delivered", "resent", "alarmed", "undelivered"):
            it[kind] = ev.get("ts", 0)
            if kind == "undelivered" and ev.get("road") == "pane":
                it["pane_tries"] = it.get("pane_tries", 0) + 1
            it[kind + "_road"] = ev.get("road", "")
    return out


def stage(it: dict) -> str:
    for k in ("accepted", "rework", "received"):
        if it.get(k):
            return ANSWERS[k]
    return "UNRECEIVED"


def run(argv: list[str], timeout: int = 60) -> tuple[int, str]:
    try:
        done = subprocess.run(argv, capture_output=True, text=True, timeout=timeout, stdin=subprocess.DEVNULL)
        return done.returncode, ((done.stdout or "") + (done.stderr or "")).strip()
    except Exception as exc:  # a road that cannot answer has not carried anything
        return 127, str(exc)


def line_for(it: dict) -> str:
    return (f"[veil {it['id']}] {it.get('kind', 'report')} from {it.get('from', '?')}: {flat(it.get('text', ''))}"
            f" — answer: bin/agents/veil.sh received {it['id']} (then accepted|rework {it['id']})")


def to_target(target: str, frm: str, msg: str) -> tuple[bool, str]:
    """Hand one line to a named agent (bin/agents/tell.sh). A Hermes session whose gateway is not
    listening is reached through its own command line instead (`hermes --resume <id> -z`)."""
    rc, out = (127, "no reply door")
    if REPLY:
        rc, out = run([REPLY, "--from", frm, target, msg], 180)
    if rc == 0:
        return True, "tell"
    if target.startswith("hermes:") and target != "hermes:desktop":
        sid = target.split(":", 1)[1]
        rc2, out2 = run([HERMES, "--resume", sid, "-z", f"[from {frm}] {msg}"], 600)
        if rc2 == 0:
            return True, "hermes-cli"
        out = out + " | hermes-cli: " + out2[-120:]
    return False, out[-200:]


def to_pane(it: dict, why: str) -> tuple[bool, str]:
    if not PANE or not os.access(PANE, os.X_OK):
        return False, "no pane door"
    rc, out = run([PANE, "--from", f"veil {it['id']}", "--", line_for(it) + f" ({why})"], 90)
    # the pane door has said "the chat injection did not happen" with exit 0 (measured 2026-11-22):
    # a resend counts only when it LANDED, never because a door returned
    landed = rc == 0 and not re.search(r"did not (happen|accept)|could not inject|not injected", out)
    return landed, (out.splitlines() or [""])[-1][:160]


def cmd_send(args: list[str]) -> int:
    frm, kind, reply_to, queued, iid, text = os.environ.get("YMIR_MSG_FROM", "script veil"), "report", "", False, "", []
    i = 0
    while i < len(args):
        a = args[i]
        if a in ("--from", "--kind", "--reply-to", "--id") and i + 1 < len(args):
            v = args[i + 1]
            if a == "--from":
                frm = v
            elif a == "--kind":
                if v not in ("report", "finding", "steer"):
                    die(f"--kind takes report, finding or steer, not '{v}'")
                kind = v
            elif a == "--reply-to":
                reply_to = v
            else:
                iid = v
            i += 2
            continue
        if a == "--queued":
            queued = True
            i += 1
            continue
        if a.startswith("--"):
            die(f"unknown flag {a}")
        text.append(a)
        i += 1
    body = flat(" ".join(text))
    if not body:
        die('send needs a message: veil.sh send --from "agent x" "what was built, and its proof"')
    iid = iid or f"veil-{int(time.time())}-{secrets.token_hex(2)}"
    if iid in items():
        die(f"the id {iid} is already in the ledger", 2)
    it = {"id": iid, "event": "sent", "from": flat(frm), "kind": kind, "text": body, "reply_to": reply_to,
          "host": socket.gethostname().split(".")[0]}
    append(dict(it))
    road, ok = "queued-by-caller", True
    if not queued:
        rc, out = run([TELL, "tell", "--from", flat(frm), "--class", "report", line_for(it)], 60)
        if rc == 0:
            road = "arm"
        else:
            ok, why = to_pane(it, "the arm refused: " + (out.splitlines() or ["no answer"])[-1][:80])
            road = "pane" if ok else "none"
    append({"id": iid, "event": "delivered" if ok else "undelivered", "road": road})
    print("veil-send[1]{id,kind,road,delivered,answer_with}:")
    print(f"  {q(iid)},{q(kind)},{q(road)},{q('yes' if ok else 'no')},{q('bin/agents/veil.sh received ' + iid)}")
    if not ok:
        print(f"veil: {iid} reached neither the arm nor the holder's pane — the sweep tries again", file=sys.stderr)
        return 1
    return 0


def cmd_answer(event: str, args: list[str]) -> int:
    if not args:
        die(f"{event} needs an id")
    iid, by, note = args[0], os.environ.get("YMIR_MSG_FROM", "") or os.environ.get("YMIR_SEAT_NAME", "the arm holder"), []
    i = 1
    while i < len(args):
        if args[i] == "--by" and i + 1 < len(args):
            by = args[i + 1]
            i += 2
            continue
        note.append(args[i])
        i += 1
    if event == "rework" and not note:
        die("rework needs its why: veil.sh rework <id> \"the test it lacks\"")
    it = items().get(iid)
    if not it or not it.get("sent"):
        die(f"no item {iid} in the ledger ({LEDGER})", 3)
    if event != "received" and not it.get("received"):
        append({"id": iid, "event": "received", "by": flat(by), "note": "(implied by " + event + ")"})
    append({"id": iid, "event": event, "by": flat(by), "note": flat(" ".join(note))})
    back = "-"
    if it.get("reply_to") and it.get("kind") != "steer":
        msg = f"{ANSWERS[event]} {iid}" + (f" — {flat(' '.join(note))}" if note else "")
        sent_ok, road = to_target(it["reply_to"], f"the arm holder ({flat(by)})", msg)
        back = f"told ({road})" if sent_ok else "not-told"
        append({"id": iid, "event": "answered-sender", "road": it["reply_to"], "ok": sent_ok, "why": road})
    print("veil-answer[1]{id,answer,by,sender}:")
    print(f"  {q(iid)},{q(ANSWERS[event])},{q(flat(by))},{q(back)}")
    return 0


def cmd_steer(args: list[str]) -> int:
    """The arm holder steers an agent (a pane, an errand, a Hermes session): the line carries an id the
    agent answers with `veil.sh received <id>`, so the holder knows the steer landed."""
    frm, to, text, i = os.environ.get("YMIR_MSG_FROM", "the arm holder"), "", [], 0
    while i < len(args):
        if args[i] in ("--to", "--from") and i + 1 < len(args):
            if args[i] == "--to":
                to = args[i + 1]
            else:
                frm = args[i + 1]
            i += 2
            continue
        text.append(args[i])
        i += 1
    body = flat(" ".join(text))
    if not to or not body:
        die('steer needs --to <agent> and a line: veil.sh steer --to hermes:<session> "do this"')
    iid = f"veil-{int(time.time())}-{secrets.token_hex(2)}"
    append({"id": iid, "event": "sent", "from": flat(frm), "kind": "steer", "text": body, "reply_to": to,
            "host": socket.gethostname().split(".")[0]})
    msg = (f"[veil {iid}] steer: {body} — say you have it: run `bin/agents/veil.sh received {iid}` "
           f"(from the Ymir runtime), and report back with `bin/agents/veil.sh send`")
    ok, road = to_target(to, flat(frm), msg)
    append({"id": iid, "event": "delivered" if ok else "undelivered", "road": to + ":" + road})
    print("veil-steer[1]{id,to,road,delivered}:")
    print(f"  {q(iid)},{q(to)},{q(road[:80])},{q('yes' if ok else 'no')}")
    return 0 if ok else 1


def row(it: dict, now: int) -> str:
    return (f"  {q(it['id'])},{q(stage(it))},{q(it.get('kind', ''))},{q(it.get('from', ''))},"
            f"{now - int(it.get('sent', now))},{q('yes' if it.get('resent') else 'no')},{q(it.get('text', '')[:120])}")


def cmd_status(args: list[str]) -> int:
    if not args:
        die("status needs an id")
    it = items().get(args[0])
    if not it or not it.get("sent"):
        die(f"no item {args[0]}", 3)
    print("veil-status[1]{id,stage,kind,from,age_s,resent,text}:")
    print(row(it, int(time.time())))
    return 0


def cmd_wait(args: list[str]) -> int:
    if not args:
        die("wait needs an id")
    limit = RECEIPT_S
    if "--timeout" in args:
        limit = int(args[args.index("--timeout") + 1])
    end = time.time() + limit
    while True:
        it = items().get(args[0])
        if not it:
            die(f"no item {args[0]}", 3)
        if stage(it) != "UNRECEIVED":
            print(f"veil: {args[0]} {stage(it)} by {it.get('received_by', '?')}")
            return 0
        if time.time() >= end:
            print(f"veil: {args[0]} not received within {limit}s — the sweep resends it to the holder's pane", file=sys.stderr)
            return 4
        time.sleep(2)


def unreceived(now: int) -> list[dict]:
    rows = [it for it in items().values() if it.get("sent") and stage(it) == "UNRECEIVED" and it.get("kind") != "steer"]
    return sorted(rows, key=lambda it: it["sent"])


def cmd_pending(args: list[str]) -> int:
    now = int(time.time())
    rows = unreceived(now)
    if "--json" in args:
        print(json.dumps({"now": now, "red_s": RED_S, "receipt_s": RECEIPT_S,
                          "items": [{"id": it["id"], "from": it.get("from"), "kind": it.get("kind"),
                                     "age_s": now - it["sent"], "resent": bool(it.get("resent"))} for it in rows]}))
        return 0
    print(f"veil-pending[{len(rows)}]{{id,stage,kind,from,age_s,resent,text}}:")
    for it in rows:
        print(row(it, now))
    return 0


def cmd_sweep(args: list[str]) -> int:
    dry = "--dry-run" in args
    now = int(time.time())
    resent, red = 0, 0
    for it in unreceived(now):
        age = now - it["sent"]
        # at least once: a pane resend that did not land is tried again on the next sweep, three times at most
        if age >= RECEIPT_S and not it.get("resent") and it.get("pane_tries", 0) < PANE_TRIES:
            if dry:
                resent += 1
            else:
                ok, why = to_pane(it, f"no RECEIVED in {age}s — resent")
                append({"id": it["id"], "event": "resent" if ok else "undelivered", "road": "pane", "why": why})
                resent += ok
        if age >= RED_S:
            red += 1
            if not it.get("alarmed") and not dry:
                append({"id": it["id"], "event": "alarmed", "road": "trouble:receipts"})
    print("veil-sweep[1]{resent,red,receipt_s,red_s,dry}:")
    print(f"  {resent},{red},{RECEIPT_S},{RED_S},{q('yes' if dry else 'no')}")
    return 1 if red else 0


def main(argv: list[str]) -> int:
    if not argv:
        die("a verb is owed: send · steer · received · accepted · rework · status · wait · pending · sweep")
    verb, rest = argv[0], argv[1:]
    if verb == "send":
        return cmd_send(rest)
    if verb in ANSWERS:
        return cmd_answer(verb, rest)
    table = {"steer": cmd_steer, "status": cmd_status, "wait": cmd_wait, "pending": cmd_pending, "sweep": cmd_sweep}
    if verb in table:
        return table[verb](rest)
    die(f"unknown verb {verb}")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
