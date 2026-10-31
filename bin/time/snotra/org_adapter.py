#!/usr/bin/env python3
"""org_adapter — the abstract base class for organization tool adapters.

WHY: Ymir projects meeting records onto organization tools (Trello, Monday, Asana,
Jira, ClickUp, Notion, Linear). Each tool has its own API, auth, and data model.
Without a shared interface, every projection and automation script would need
to know which tool it is talking to — and adding a new tool would mean rewriting
every script.

WHAT THIS IS: an abstract base class (ABC) that declares the verbs every
organization tool must support. Each tool gets its own adapter module that
implements these verbs. The place's `surface` field selects the adapter at
runtime. The projection and automation scripts call `adapter.<verb>()` — they
never know which tool is behind it.

THE VERBS:
  authenticate()          → token (OAuth2 or API key)
  ensure_board(name, org) → board_id (find or create)
  list_lists(board_id)    → [list_name: str]
  ensure_list(board_id, name) → list_id (find or create)
  create_card(list_id, name, desc, labels, member, due) → card_id
  update_card(card_id, **params) → card
  move_card(card_id, list_id) → card
  add_member(card_id, member_id) → None
  add_checklist(card_id, name, items) → checklist_id
  post_comment(card_id, text) → comment_id
  get_card(card_id) → card
  board_cards(board_id) → [card]
  resolve_member(name, board_id) → member_id | None
  ensure_label(board_id, name, colour) → label_id
  list_statuses(board_id) → [status_name: str]  (Jira/ClickUp workflows)
  transition_card(card_id, status_name) → card   (Jira workflow transitions)
  create_subtask(parent_id, name, desc) → card_id (Asana/ClickUp subtasks)
  add_dependency(card_id, depends_on_id) → None  (Jira/Asana dependencies)
  set_custom_field(card_id, field_name, value) → None (Monday columns, ClickUp fields)
"""
from __future__ import annotations

import abc
from typing import Any


class OrgAdapter(abc.ABC):
    """Abstract base class for organization tool adapters."""

    def __init__(self, place: dict):
        self.place = place
        self.board_name = place.get("board") or ""
        self._token: str | None = None

    # ── authentication ───────────────────────────────────────────────────────
    @abc.abstractmethod
    def authenticate(self) -> str:
        """Return a valid access token. Refresh if expired."""
        ...

    @property
    def token(self) -> str:
        if self._token is None:
            self._token = self.authenticate()
        return self._token

    # ── board ────────────────────────────────────────────────────────────────
    @abc.abstractmethod
    def ensure_board(self, name: str, org: str | None = None) -> str:
        """Find or create a board. Return its id. Never create a duplicate."""
        ...

    @abc.abstractmethod
    def board_id_of(self, name: str) -> str:
        """Resolve a board name to its id. Die if not found."""
        ...

    # ── lists ────────────────────────────────────────────────────────────────
    @abc.abstractmethod
    def list_lists(self, board_id: str) -> list[dict]:
        """Return [{name, id, pos}] for all lists on the board."""
        ...

    @abc.abstractmethod
    def ensure_list(self, board_id: str, name: str) -> str:
        """Find or create a list. Return its id. Never rename an existing list."""
        ...

    @abc.abstractmethod
    def resolve_list(self, board_id: str, name: str) -> str:
        """Resolve a list name to its id. Die if not found."""
        ...

    # ── cards ────────────────────────────────────────────────────────────────
    @abc.abstractmethod
    def create_card(self, list_id: str, board_id: str, name: str, desc: str,
                    label_ids: list[str] | None = None, member_id: str | None = None,
                    due: str | None = None) -> dict:
        """Create a card. Return {id, name, ...}."""
        ...

    @abc.abstractmethod
    def update_card(self, card_id: str, **params) -> dict:
        """Update a card's fields (name, desc, idList, due, idMembers, idLabels)."""
        ...

    @abc.abstractmethod
    def move_card(self, card_id: str, list_id: str) -> dict:
        """Move a card to a different list."""
        ...

    @abc.abstractmethod
    def get_card(self, card_id: str) -> dict:
        """Fetch a single card by id."""
        ...

    @abc.abstractmethod
    def board_cards(self, board_id: str, fields: str = "name,desc,idList") -> list[dict]:
        """Fetch all cards on a board."""
        ...

    # ── members ──────────────────────────────────────────────────────────────
    @abc.abstractmethod
    def resolve_member(self, name: str, board_id: str) -> str | None:
        """Resolve a person's name to their member id. Return None if not found.
        Never invent a person.

        Identity matching (Reygan's challenge #3): if the name doesn't match
        directly, check the speaker-to-user mapping table for this company.
        """
        ...

    @abc.abstractmethod
    def add_member(self, card_id: str, member_id: str) -> None:
        """Add a member to a card (triggers native notification)."""
        ...

    # ── labels ───────────────────────────────────────────────────────────────
    @abc.abstractmethod
    def ensure_label(self, board_id: str, name: str, colour: str) -> str:
        """Find or create a label. Return its id."""
        ...

    # ── checklists ───────────────────────────────────────────────────────────
    @abc.abstractmethod
    def ensure_checklist(self, card_id: str, name: str, items: list[str]) -> str | None:
        """Find or create a checklist with the given items. Return its id."""
        ...

    # ── comments ─────────────────────────────────────────────────────────────
    @abc.abstractmethod
    def post_comment(self, card_id: str, text: str) -> str:
        """Post a comment on a card. Return the comment id."""
        ...

    # ── workflow (Jira/ClickUp) ──────────────────────────────────────────────
    def list_statuses(self, board_id: str) -> list[str]:
        """Return the list of valid statuses for this board (workflow-based tools)."""
        return self.list_lists(board_id).__class__ and [l["name"] for l in self.list_lists(board_id)]

    def transition_card(self, card_id: str, status_name: str) -> dict:
        """Transition a card to a new status (Jira workflow transitions)."""
        # Default: move to the list with that name
        board_id = self.get_card(card_id).get("idBoard", "")
        list_id = self.resolve_list(board_id, status_name)
        return self.move_card(card_id, list_id)

    # ── subtasks (Asana/ClickUp) ─────────────────────────────────────────────
    def create_subtask(self, parent_id: str, name: str, desc: str = "") -> str:
        """Create a subtask under a parent card. Return the subtask id."""
        raise NotImplementedError("subtasks not supported by this adapter")

    # ── dependencies (Jira/Asana) ───────────────────────────────────────────
    def add_dependency(self, card_id: str, depends_on_id: str) -> None:
        """Add a dependency between two cards."""
        raise NotImplementedError("dependencies not supported by this adapter")

    # ── custom fields (Monday columns, ClickUp fields) ───────────────────────
    def set_custom_field(self, card_id: str, field_name: str, value: Any) -> None:
        """Set a custom field value on a card."""
        raise NotImplementedError("custom fields not supported by this adapter")

    # ── helpers ──────────────────────────────────────────────────────────────
    def die(self, msg: str, code: int = 1):
        import sys
        print(f"{self.__class__.__name__}: {msg}", file=sys.stderr)
        raise SystemExit(code)

    def say(self, msg: str):
        print(msg, flush=True)


def load_speaker_map(company: str) -> dict:
    """Load the speaker-to-user mapping table for a company.

    Returns {speaker_name: user_id} or {} if no mapping exists.
    """
    import os
    from pathlib import Path
    # Try YMIR_HOME first
    home = os.environ.get("YMIR_HOME")
    if not home:
        try:
            import subprocess
            root = Path(__file__).resolve().parents[3]
            out = subprocess.check_output(
                ["bash", "-c", f'. "{root}/bin/vault/hoard-lib.sh" >/dev/null 2>&1; out=""; ymir_home_root out; printf "%s" "$out"'],
                timeout=20).decode().strip()
            home = out
        except Exception:
            home = os.path.join(os.path.expanduser("~"), "Documents", "ymirhome")
    p = Path(home) / "hodd" / "identity" / "speaker-map" / f"{company}.yaml"
    if not p.is_file():
        return {}
    try:
        import yaml
        data = yaml.safe_load(p.read_text(encoding="utf-8")) or {}
        return data.get("speakers", {}) or {}
    except Exception:
        return {}


def adapter_for(place: dict) -> OrgAdapter:
    """Factory: return the right adapter for a place's surface."""
    surface = (place.get("surface") or "trello").strip().lower()
    if surface == "trello":
        from trello_adapter import TrelloAdapter
        return TrelloAdapter(place)
    if surface == "monday":
        from monday_adapter import MondayAdapter
        return MondayAdapter(place)
    if surface == "asana":
        from asana_adapter import AsanaAdapter
        return AsanaAdapter(place)
    if surface == "jira":
        from jira_adapter import JiraAdapter
        return JiraAdapter(place)
    if surface == "clickup":
        from clickup_adapter import ClickUpAdapter
        return ClickUpAdapter(place)
    if surface == "notion":
        from notion_adapter import NotionAdapter
        return NotionAdapter(place)
    if surface == "linear":
        from linear_adapter import LinearAdapter
        return LinearAdapter(place)
    raise ValueError(f"unknown surface {surface!r} — no adapter exists for it")
