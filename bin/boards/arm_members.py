#!/usr/bin/env python3
"""arm_members — every arm holder is a member of the board, named so nobody takes a seat for a colleague (plan 327).

    arm-members.sh plan [--json]     who SHOULD be a member (one per live machine), and who already is

The seat is the identity, not the session: one member per machine, whichever session holds its arm tonight.
A member is an agent, so its display name says so — "<holder> · <machine> (agent)" — and its role is member,
never admin. An agent may hold cards; it may not merge (the delivery gate stays a person's).

This door READS. It creates nobody: the board has no API for making an account, so a member is made by the
board's instance admin (or by one sign-in through the board's login), and its token comes from the MCP door's
register as `tool:<machine>-board` (mcp-token.sh on the heart) — never a credential in a repository.

Configuration (Rule 07): `$YMIR_HOME/config/todo-board.yaml` — `agent_mail_domain` (the address domain for
machine members) and `members_place` (a place in the workspace whose members are read; default `place`).
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "bin" / "records"))
import todo_board as tb  # noqa: E402


def ascii_slug(name: str) -> str:
    """Frœði -> froedi, Þóra -> thora: an address is ASCII; the display name keeps the true spelling."""
    for a, b in (("œ", "oe"), ("Œ", "Oe"), ("æ", "ae"), ("Æ", "Ae"), ("ð", "d"), ("Ð", "D"), ("þ", "th"), ("Þ", "Th")):
        name = name.replace(a, b)
    s = name
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def holders(raw: str | None = None) -> list:
    """Parse `arm-send.sh --who`: machine<TAB>state<TAB>"name","harness" (or an error)."""
    if raw is None:
        try:
            raw = subprocess.run(["bash", str(ROOT / "bin" / "fleet" / "arm-send.sh"), "--who"],
                                 capture_output=True, text=True, timeout=90).stdout
        except subprocess.TimeoutExpired:
            raw = ""
    rows = []
    for line in raw.splitlines():
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        machine, state, rest = parts[0].strip(), parts[1].strip(), parts[2].strip()
        name = ""
        if state == "held":
            m = re.match(r'^\s*"([^"]*)"', rest)
            name = m.group(1) if m else ""
        rows.append({"machine": machine, "state": state, "holder": name})
    return rows


def plan(raw=None, board=None, cfg_extra=None) -> list:
    extra = cfg_extra if cfg_extra is not None else tb._yaml(tb.home() / "config" / "todo-board.yaml")
    domain = (extra or {}).get("agent_mail_domain") or ""
    members = set()
    note = ""
    if board is not None:
        try:
            for m in board.call("list_members").get("members") or []:
                members.add(str(m.get("name") or "").casefold())
                if m.get("email"):
                    members.add(str(m["email"]).casefold())
        except (tb.BoardError, tb.BoardDark) as exc:
            note = f"members unread: {exc}"
    out = []
    for h in holders(raw):
        if h["state"] != "held" or not h["holder"]:
            out.append(dict(h, address="", display="", on_board="unknown", why=f"machine {h['state']} — no member proposed"))
            continue
        slug = ascii_slug(h["holder"])
        address = f"{slug}@{domain}" if domain else ""
        shown = h["holder"][:1].upper() + h["holder"][1:] if h["holder"].islower() else h["holder"]
        display = f"{shown} · {h['machine']} (agent)"
        here = bool(members) and (slug in members or address.casefold() in members or display.casefold() in members)
        out.append(dict(h, address=address, display=display, role="member", kind="agent",
                        token_subject=f"tool:{h['machine']}-board",
                        on_board=("yes" if here else ("no" if members else "unknown")),
                        why=note or ("" if domain else "agent_mail_domain unset in config/todo-board.yaml")))
    return out


def main(argv=None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if not argv or argv[0] != "plan":
        print(__doc__.split("\n\n")[1], file=sys.stderr)
        return 2
    cfg = tb.config()
    extra = tb._yaml(tb.home() / "config" / "todo-board.yaml")
    if extra.get("members_place"):
        cfg = dict(cfg, place=extra["members_place"])
    board = tb.Board(cfg) if not tb.configured(cfg) else None
    rows = plan(board=board, cfg_extra=extra)
    if "--json" in argv:
        print(json.dumps(rows, ensure_ascii=False, indent=2))
        return 0
    print(f"arm_members[{len(rows)}]{{machine,holder,address,display,on_board,why}}:")
    for r in rows:
        print('  "%s","%s","%s","%s","%s","%s"' % (r["machine"], r["holder"], r["address"], r["display"],
                                                  r["on_board"], r["why"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
