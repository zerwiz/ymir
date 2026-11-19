#!/usr/bin/env python3
"""board_people.py — a person, as the home's register names them, found among a board's members.

`hodd/identity/members.yaml` is the ONE register of who is on what (plan 266). A person there is a slug
(`ada-lovelace`); a board knows them by an id, a username, a full name or an email. This module turns
the one into the other, and refuses by name when it cannot — it never assigns a near miss silently.

The match, in order:
  1 · an explicit handle on the person's row: `trello: <username>` or `plane: <email or display name>`
  2 · an exact id, username, email or display name equal to what was asked
  3 · every word of the slug (`ada`, `lovelace`) found in the member's full name, display name or username
Two members matching at the same step is a refusal (ambiguous), naming both.
"""
from __future__ import annotations

import os
import re


def _home() -> str:
    # the home resolves as the resolver resolves it (YMIR_HOME, then the install's record, then the default):
    # never a guessed path (defaults-guard, RULES/07)
    env = os.environ.get("YMIR_HOME", "").strip()
    if env:
        return os.path.expanduser(env)
    record = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "ymir", "home")
    try:
        with open(record, encoding="utf-8") as fh:
            first = (fh.readline() or "").strip()
        if first:
            return os.path.expanduser(first)
    except OSError:
        pass
    return os.path.join(os.path.expanduser("~"), "Documents", "ymirhome")


def register_rows(person: str) -> list[dict]:
    path = os.environ.get("YMIR_MEMBERS_FILE") or os.path.join(_home(), "hodd", "identity", "members.yaml")
    try:
        import yaml  # noqa: PLC0415
        with open(path, encoding="utf-8") as fh:
            doc = yaml.safe_load(fh) or {}
    except Exception:  # noqa: BLE001 — no register is not a crash; the match falls to names
        return []
    return [r for r in (doc.get("members") or []) if str(r.get("person", "")).lower() == person.lower()]


def _norm(s) -> str:
    return re.sub(r"\s+", " ", str(s or "")).strip().lower()


def find(asked: str, members: list[dict], engine: str) -> tuple[dict | None, str]:
    """(member, why). `members` rows carry any of: id, username, fullName, display_name, email."""
    want = _norm(asked)
    handles = [want]
    for row in register_rows(asked):
        h = row.get(engine)
        if h:
            handles.insert(0, _norm(h))
    keys = ("id", "username", "email", "display_name", "fullName")
    for h in handles:
        hits = [m for m in members if any(_norm(m.get(k)) == h for k in keys if m.get(k))]
        if len(hits) == 1:
            return hits[0], f"{asked} → {hits[0].get('username') or hits[0].get('display_name') or hits[0].get('id')}"
        if len(hits) > 1:
            return None, f"{asked} is ambiguous on the board: " + ", ".join(
                str(m.get("username") or m.get("display_name") or m.get("id")) for m in hits)
    words = [w for w in re.split(r"[-_.\s]+", want) if w]
    if words:
        hits = [m for m in members
                if all(any(w in _norm(m.get(k)) for k in ("fullName", "display_name", "username", "email"))
                       for w in words)]
        if len(hits) == 1:
            return hits[0], f"{asked} → {hits[0].get('username') or hits[0].get('display_name') or hits[0].get('id')} (by name)"
        if len(hits) > 1:
            return None, f"{asked} is ambiguous on the board: " + ", ".join(
                str(m.get("username") or m.get("display_name") or m.get("id")) for m in hits)
    shown = ", ".join(str(m.get("username") or m.get("display_name") or m.get("id")) for m in members[:20])
    return None, f"{asked} is not a member of this board (members: {shown or 'none'}) — they join first, then they can be assigned"


SOURCE = re.compile(r"^[^\s#]+#[^\s#]+$")


def source_ok(source: str) -> tuple[bool, str]:
    """Provenance (plan 324 F9): an agent-made card names the record it came from, `<path>#<id>`."""
    s = str(source or "").strip()
    if not s:
        return False, "a card made by an agent needs `source: <path>#<id>` — the record it came from (plan 324 F9)"
    if not SOURCE.match(s):
        return False, f"source {s!r} is not `<path>#<id>` (for example meetings/2026-11-19/record.md#A7)"
    return True, s
