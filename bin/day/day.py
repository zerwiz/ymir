#!/usr/bin/env python3
"""day.py — the day's door: his acts, and what the house measured, each with its as_of.

    day.py                  print the day
    day.py --json           the same, for a surface to render
    day.py acts             only his half, numbered (what `open N` refers to)
    day.py clock            only the schedule, with due · fired · missed · whose role
    day.py open N [--run]   the door behind act N — print it, or run it in a pane
    day.py --carry          counts and acts only — the only mode a notifier may call
    day.py --quiet          the same, kept as an alias
    day.py privacy          print the contract, and check THIS file against it

The rule this file obeys, and the reason it exists (plan 207):

  • his half is READ, never written. `hodd/life/personal/me/todo.md` is his;
  • every derived line carries its source and its `as_of`;
  • a source that cannot be read prints **unable** with the reason — never a zero, because a
    zero is a fact and an unreadable source is not;
  • nothing here invents a number, a date or a priority.

Private data (plan 207 §14, RULES/04 and 15):

  read    his own file, the mail store, this seat's schedule and state, the plans, the calendar
          door — and never the vault, never another account, never another seat's state;
  print   to his own terminal: acts, senders, subjects, counts;
  carry   acts, counts and dates ONLY. A sender or a subject may not leave the house unless he
          asks for it on the command line, and a push is a copy outside the home;
  write   nothing. Ever. No cache, no log, no temp file. `privacy` proves it on demand.

Exit: 0 · 1 nothing could be read at all · 2 usage.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import subprocess
import sys
from pathlib import Path

HOME = None


def home() -> Path:
    global HOME
    if HOME:
        return HOME
    env = os.environ.get("YMIR_HOME")
    if env:
        HOME = Path(env).expanduser()
        return HOME
    record = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "ymir" / "home"
    try:
        first = record.read_text(encoding="utf-8").splitlines()[0].strip()
        if first:
            HOME = Path(first).expanduser()
            return HOME
    except (OSError, IndexError):
        pass
    HOME = Path.home() / "Documents" / "ymirhome"
    return HOME


def now() -> str:
    return dt.datetime.now().astimezone().strftime("%Y-%m-%d %H:%M %Z")


def repo_root() -> Path:
    here = Path(__file__).resolve()
    for parent in here.parents:
        if (parent / "RULES").is_dir() and (parent / ".agents").is_dir():
            return parent
    return here.parents[1]


# ── his half ─────────────────────────────────────────────────────────────────────────────────────

HIS_FILE = Path("hodd/life/personal/me/todo.md")


def acts() -> tuple[list[dict], str]:
    """The unchecked lines under his half, with the section they sit in."""
    path = home() / HIS_FILE
    if not path.is_file():
        return [], "unable — %s is not there" % HIS_FILE
    text = path.read_text(encoding="utf-8")
    # his half ends where the derived half begins
    cut = re.split(r"\n#\s+The derived half", text)[0]
    out, section = [], ""
    for line in cut.splitlines():
        m = re.match(r"^##\s+(.*\S)\s*$", line)
        if m:
            section = m.group(1)
            continue
        m = re.match(r"^-\s+\[( |x|X)\]\s+\*\*(.+?)\*\*\s*(.*)$", line)
        if m:
            out.append({"done": m.group(1).lower() == "x",
                        "act": m.group(2), "detail": m.group(3).strip(" —"), "section": section})
    open_acts = [a for a in out if not a["done"]]
    for i, a in enumerate(open_acts, 1):
        a["n"] = i
    return open_acts, str(path.relative_to(home()))


# ── the derived facts ────────────────────────────────────────────────────────────────────────────

def mail_fact() -> dict:
    path = home() / "hodd/memory/mail/messages.jsonl"
    if not path.is_file():
        return {"unable": "no mail store at hodd/memory/mail/messages.jsonl"}
    rows, bad = [], 0
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if not line.strip():
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            bad += 1
    latest: dict[str, dict] = {}       # the store appends; a re-judged message's newest row wins
    for r in rows:
        latest[str(r.get("id") or len(latest))] = r
    inbound = [r for r in latest.values() if r.get("direction") == "in"]
    unhandled = [r for r in inbound if not r.get("handled_at")]
    # What he owes is counted per conversation, by the comms door's one rule (plan 261): the last word
    # is theirs, it asks him something, and nothing has been sent back. A message count overstates it.
    try:
        sys.path.insert(0, str(repo_root() / "bin" / "records"))
        import comms  # noqa: PLC0415
        conv = comms.owed_conversations(comms.mail_rows())
    except Exception as exc:                       # the door is absent or broken: say so, never guess
        return {"unable": f"the comms door could not count what is owed ({exc.__class__.__name__})"}
    cut = dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=14)
    fresh = [c for c in conv if c["at"] >= cut]
    return {
        "inbound": len(inbound), "unhandled": len(unhandled), "unreadable_lines": bad,
        "owed": len(conv), "owed_recent": len(fresh),
        "recent": [{"at": c["last"]["at"][:16],
                    "from": (c["last"]["_mail"].get("from") or {}).get("name") or c["sender"],
                    "subject": (c["first"] or "")[:70],
                    "class": c["last"]["_mail"].get("classification") or ""} for c in fresh[:4]],
        "as_of": max((r.get("ingested_at") or r.get("received_at") or "") for r in rows)[:19] if rows else "",
        "source": "gná's store (hodd/memory/mail/messages.jsonl)",
    }


def log_fact() -> dict:
    """Today's daily log against his list (plan 274): entries, those marked open, those not listed yet."""
    list_file = home() / "hodd/life/personal/me/todo.md"
    if not list_file.is_file():                         # no list is said, never counted as an empty one
        return {"unable": "no to-do list at hodd/life/personal/me/todo.md"}
    try:
        sys.path.insert(0, str(repo_root() / "bin" / "records"))
        import comms  # noqa: PLC0415
        j = comms.log_join(list_file.read_text(encoding="utf-8"))
    except Exception as exc:
        return {"unable": f"the comms door could not read the daily log ({exc.__class__.__name__})"}
    j["source"] = "the daily log (hodd/memory/daily) and his list"
    return j


def role() -> str:
    for cand in (repo_root() / "bin/skuld/role.sh",):
        if cand.is_file():
            try:
                out = subprocess.run(["bash", str(cand), "resolve"], capture_output=True, text=True, timeout=20)
                if out.returncode == 0 and out.stdout.strip():
                    return out.stdout.strip().splitlines()[0]
            except (OSError, subprocess.SubprocessError):
                pass
    return os.environ.get("BROKK_ROLES", "dev").split(",")[0]


def cron_rows() -> list[dict]:
    path = home() / "config/cron.yaml"
    if not path.is_file():
        return []
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        m = re.match(r"^(@[a-z]+)\s+([0-9]{2}:[0-9]{2}|@\w+(?::[0-9]{2})?)\s+(.*)$", line) or \
            re.match(r"^([0-9]{2}:[0-9]{2}|@\w+(?::[0-9]{2})?)\s+(@[a-z]+)?\s*(.*)$", line)
        if not m:
            continue
        g1, g2, rest = m.group(1), m.group(2), m.group(3)
        gate, at = (g1, g2) if g1.startswith("@") and not g1.startswith("@hourly") and not g1.startswith("@daily") else (g2 or "", g1)
        cmd = (rest or "").strip()
        if not cmd:
            continue
        rows.append({"gate": gate.lstrip("@") if gate else "", "at": at, "cmd": cmd})
    return rows


def clock_fact() -> dict:
    rows = cron_rows()
    if not rows:
        return {"unable": "no readable rows in config/cron.yaml"}
    this_role = role()
    today = dt.date.today().isoformat()
    stamp_dir = home() / "state/.cron-fired"
    fired_today, missed, foreign = [], [], []
    now_hm = dt.datetime.now().strftime("%H:%M")
    for row in rows:
        key = re.sub(r"[^A-Za-z0-9._-]", "_", row["cmd"])
        stamp = stamp_dir / key
        fired = stamp.is_file() and stamp.read_text(encoding="utf-8").strip() == today
        mine = row["gate"] in ("", this_role)
        at = row["at"]
        due = bool(re.match(r"^\d\d:\d\d$", at)) and at <= now_hm
        entry = {**row, "fired_today": fired, "mine": mine, "due": due}
        if fired:
            fired_today.append(entry)
        elif mine and due:
            missed.append(entry)
        elif not mine:
            foreign.append(entry)
    return {"declared": len(rows), "role": this_role, "fired": len(fired_today),
            "missed": len(missed), "foreign": len(foreign),
            "missed_rows": missed[:6], "foreign_rows": foreign[:6],
            "as_of": now(), "source": "config/cron.yaml · role · state/.cron-fired"}


def calendar_fact() -> dict:
    door = repo_root() / "systems/snotra/services/calendar/calendar-ask.sh"
    if not door.is_file():
        return {"unable": "the calendar door is not in this tree"}
    try:
        out = subprocess.run(["bash", str(door), "what"], capture_output=True, text=True, timeout=45)
    except (OSError, subprocess.SubprocessError) as exc:
        return {"unable": "the door did not answer: %s" % exc}
    try:
        data = json.loads(out.stdout)
    except json.JSONDecodeError:
        return {"unable": "the door printed no JSON (rc=%s)" % out.returncode}
    if data.get("status") != "current":
        return {"unable": "%s — %s" % (data.get("status"), data.get("reason") or "no reason given"),
                "as_of": (data.get("as_of") or "")[:19], "source": "mánagandr"}
    events = data.get("events") or []
    upcoming = [e for e in events if (e.get("start") or "") >= dt.datetime.now().astimezone().isoformat()[:19]]
    return {"count": len(events), "next": [{"start": (e.get("start") or "")[:16], "summary": e.get("summary") or ""}
                                           for e in sorted(upcoming, key=lambda e: e.get("start") or "")[:3]],
            "as_of": (data.get("as_of") or "")[:19], "source": "mánagandr"}


def evidence_fact() -> dict:
    doc = home() / "svartalfaheim/example-2/docs/what-we-are-better-at.md"
    gate = repo_root() / "bin/collab/kit/scripts/advantage-audit.sh"
    if not doc.is_file():
        return {"unable": "no client-facing claims document"}
    if not gate.is_file():
        return {"unable": "the advantage gate is not in this tree"}
    try:
        out = subprocess.run(["bash", str(gate), "--json", str(doc)], capture_output=True, text=True, timeout=45)
        data = json.loads(out.stdout)
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError) as exc:
        return {"unable": "the gate did not answer: %s" % exc}
    return {"total": data.get("total", 0), "unsupported": data.get("unsupported", 0),
            "as_of": now(), "source": "advantage-audit"}


# ── printing ─────────────────────────────────────────────────────────────────────────────────────

def render(as_json: bool, quiet: bool, carry: bool = False) -> int:
    open_acts, his_path = acts()
    facts = {"mail": mail_fact(), "log": log_fact(), "clock": clock_fact(), "calendar": calendar_fact(), "evidence": evidence_fact()}
    subject = os.environ.get("DAY_SUBJECT") or os.environ.get("USER") or "operator"
    if as_json:
        print(json.dumps({"as_of": now(), "subject": subject, "his_file": his_path,
                          "acts": open_acts, "facts": facts}, indent=2))
        return 0

    def unable(fact: dict) -> str:
        return "unable — %s%s" % (fact["unable"], (" (as of %s)" % fact["as_of"]) if fact.get("as_of") else "")

    mail, clock = facts["mail"], facts["clock"]
    cal, ev = facts["calendar"], facts["evidence"]

    print("THE DAY · %s · as_of %s" % (subject, now()))
    print()
    print("HIS ACTS — read from %s, never written here" % his_path)
    if not open_acts:
        print("  none open, or his half was not found")
    for a in open_acts:
        print("  %d  [%s] %s" % (a["n"], a["section"] or "-", a["act"]))
        if a["detail"] and not quiet:
            print("       %s" % a["detail"][:150])
    print()
    print("THE MAIL · %s" % mail.get("source", ""))
    if "unable" in mail:
        print("  " + unable(mail))
    else:
        print("  %d inbound · you owe a reply in %d conversations (%d from the last 14 days) · as_of %s"
              % (mail["inbound"], mail["owed"], mail["owed_recent"], mail["as_of"]))
        if carry:
            print("    sender and subject withheld: this is a carried copy, outside the home")
        elif not quiet:
            for r in mail["recent"]:
                print("    %s  %-18s %s" % (r["at"], r["from"][:18], r["subject"]))
    print()
    lg = facts["log"]
    print("THE LOG · %s" % lg.get("source", ""))
    if lg.get("unable"):
        print("  " + unable(lg))
    else:
        print("  today's log: %d entries · %d marked open, %d of them not on your list yet"
              % (lg["entries"], lg["open"], lg["not_listed"]))
        if lg["not_listed"]:
            print("    bin/records/comms.sh offers them as proposals; nothing is written without your yes")
    print()
    print("THE CLOCK · %s" % clock.get("source", ""))
    if "unable" in clock:
        print("  " + unable(clock))
    else:
        print("  %d declared · role %s · %d fired today · %d missed · %d belong to another role · as_of %s"
              % (clock["declared"], clock["role"], clock["fired"], clock["missed"], clock["foreign"], clock["as_of"]))
        for r in clock["missed_rows"]:
            print("    MISSED  %s  %s" % (r["at"], r["cmd"][:78]))
        if not quiet:
            for r in clock["foreign_rows"][:4]:
                print("    %-8s %s  %s" % (r["gate"] or "-", r["at"], r["cmd"][:70]))
    print()
    print("THE CALENDAR · %s" % cal.get("source", ""))
    if "unable" in cal:
        print("  " + unable(cal))
    else:
        print("  %d events in the window · as_of %s" % (cal["count"], cal["as_of"]))
        for e in cal["next"]:
            print("    %s  %s" % (e["start"], e["summary"][:60]))
    print()
    print("THE EVIDENCE · %s" % ev.get("source", ""))
    if "unable" in ev:
        print("  " + unable(ev))
    else:
        print("  %d claims · %d unsupported · as_of %s" % (ev["total"], ev["unsupported"], ev["as_of"]))
        if ev["unsupported"]:
            print("    the client-facing page cannot be sent until each carries a measurement")
    return 0


def open_act(n: int, run: bool) -> int:
    open_acts, _ = acts()
    match = [a for a in open_acts if a["n"] == n]
    if not match:
        print("day: no act %d on the list (there are %d)" % (n, len(open_acts)), file=sys.stderr)
        return 2
    act = match[0]
    door = repo_root() / "bin/seat/herdr-run.sh"
    print("act %d: %s" % (act["n"], act["act"]))
    print("  section: %s" % (act["section"] or "-"))
    if act["detail"]:
        print("  detail:  %s" % act["detail"])
    if not run:
        print("  open it with: day.sh open %d --run   (%s)" % (n, "herdr pane" if door.is_file() else "no pane door in this tree"))
        return 0
    if not door.is_file():
        print("day: no pane door at %s — printing the act instead of guessing" % door, file=sys.stderr)
        return 1
    cmd = ["bash", str(door), "--title", "act-%d" % n, "--", "bash", "-lc",
           "cd %s && bash bin/day/day.sh acts" % repo_root()]
    print("  running: %s" % " ".join(cmd))
    return subprocess.call(cmd)


PRIVACY_CONTRACT = [
    ("read", "his own file, the mail store, this seat's schedule and state, the plans, the calendar"),
    ("read-not", "the vault, another account, another seat's state, a counterpart's rung"),
    ("print", "to his own terminal only: acts, senders, subjects, counts"),
    ("carry", "acts, counts and dates — never a sender, a subject or a body"),
    ("write", "nothing: no cache, no log, no temp file"),
    ("model", "never — his mail is not sent to a model, not even to summarise it"),
]


def privacy() -> int:
    """Print the contract, then check this file against it."""
    src = Path(__file__).read_text(encoding="utf-8")
    body = "\n".join(l for l in src.splitlines() if not l.strip().startswith("#"))
    findings = []
    # a write-mode open() anywhere in the file
    if re.search(r"open\([^)]*(['\"])(w|a|w\+|a\+|x)", body):
        findings.append("a write-mode open() is in this file")
    # the vault, by any name it is reached by — needles built from pieces so that this check
    # does not match its own source text (the house has been bitten by a self-matching ward)
    needles = ["sec" + "rets/platform.env", "hodd/" + "secrets", "age." + "key"]
    for word in needles:
        if word in body:
            findings.append("this file names the vault (%s)" % word)
    # a second mail account: the store path must be the one under hodd/memory/mail
    for m in re.finditer(r"messages\.jsonl", body):
        line = body[:m.start()].splitlines()[-1] if body[:m.start()].splitlines() else ""
        if "hodd/memory/mail" not in line and "MAIL" not in line:
            findings.append("a mail store path that is not hodd/memory/mail")
    print("day · private data contract (plan 207 §14)")
    for name, what in PRIVACY_CONTRACT:
        print("  %-9s %s" % (name, what))
    print()
    if findings:
        print("REFUSED — this door breaks its own contract:")
        for f in findings:
            print("  - %s" % f)
        return 1
    print("held — no write-mode open(), no vault path, one mail store, no model call")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("what", nargs="?", default="day",
                    choices=["day", "acts", "clock", "mail", "calendar", "evidence", "open", "privacy"])
    ap.add_argument("n", nargs="?", type=int)
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--quiet", action="store_true")
    ap.add_argument("--carry", action="store_true",
                    help="counts and acts only: the only mode a notifier may call")
    ap.add_argument("--run", action="store_true")
    args = ap.parse_args()

    if args.what == "privacy":
        return privacy()

    if args.what == "acts":
        open_acts, his_path = acts()
        if args.json:
            print(json.dumps({"his_file": his_path, "acts": open_acts}, indent=2))
            return 0
        for a in open_acts:
            print("%d\t%s\t%s" % (a["n"], a["section"] or "-", a["act"]))
        return 0
    if args.what == "open":
        if args.n is None:
            print("day: open needs a number — `day.sh acts` lists them", file=sys.stderr)
            return 2
        return open_act(args.n, args.run)
    if args.what in ("clock", "mail", "calendar", "evidence"):
        fact = {"clock": clock_fact, "mail": mail_fact,
                "calendar": calendar_fact, "evidence": evidence_fact}[args.what]()
        print(json.dumps(fact, indent=2))
        return 0
    return render(args.json, args.quiet or args.carry, carry=(args.carry and not args.json))


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
