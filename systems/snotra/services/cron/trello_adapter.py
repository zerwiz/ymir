#!/usr/bin/env python3
"""trello_adapter — the Trello implementation of OrgAdapter.

WHY: Trello is the first and reference implementation of the organization tool
adapter. Every other adapter (Monday, Asana, Jira, etc.) follows this shape.
This module wraps the existing trello_client.py functions into the OrgAdapter
interface so that the projection and automation scripts can call adapter verbs
instead of Trello-specific functions.

WHAT IT DOES: implements every OrgAdapter verb using the Trello REST API v1.
The underlying HTTP, auth, and resolver logic lives in trello_client.py — this
module is the adapter layer on top.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from org_adapter import OrgAdapter
import trello_client as T  # noqa: E402


class TrelloAdapter(OrgAdapter):
    """Trello implementation of the organization tool adapter."""

    def authenticate(self) -> str:
        return T.token()

    def ensure_board(self, name: str, org: str | None = None) -> str:
        # Trello boards are found by name in the map; never created by the adapter
        # (the board ensure is a separate step via snotra-board.py).
        return T.board_id_of(name)

    def board_id_of(self, name: str) -> str:
        return T.board_id_of(name)

    def list_lists(self, board_id: str) -> list[dict]:
        raw = T.api("GET", f"/boards/{board_id}/lists", {"fields": "name,id,pos"})
        return [{"name": l["name"], "id": l["id"], "pos": l.get("pos", 0)} for l in raw]

    def ensure_list(self, board_id: str, name: str) -> str:
        # Find existing; create if missing
        for l in self.list_lists(board_id):
            if l["name"].strip().lower() == name.strip().lower():
                return l["id"]
        made = T.api("POST", "/lists", {"idBoard": board_id, "name": name, "pos": "bottom"})
        return made["id"]

    def resolve_list(self, board_id: str, name: str) -> str:
        for l in self.list_lists(board_id):
            if l["name"].strip().lower() == name.strip().lower():
                return l["id"]
        self.die(f"board {board_id} has no list matching {name!r}")

    def create_card(self, list_id: str, board_id: str, name: str, desc: str,
                    label_ids: list[str] | None = None, member_id: str | None = None,
                    due: str | None = None) -> dict:
        params = {"idList": list_id, "name": name, "desc": desc, "pos": "bottom"}
        if label_ids:
            params["idLabels"] = ",".join(label_ids)
        if member_id:
            params["idMembers"] = member_id
        if due:
            params["due"] = due
        return T.api("POST", "/cards", params)

    def update_card(self, card_id: str, **params) -> dict:
        return T.api("PUT", f"/cards/{card_id}", params)

    def move_card(self, card_id: str, list_id: str) -> dict:
        return T.api("PUT", f"/cards/{card_id}", {"idList": list_id})

    def get_card(self, card_id: str) -> dict:
        return T.api("GET", f"/cards/{card_id}", {"fields": "name,desc,idList,closed,labels,idBoard"})

    def board_cards(self, board_id: str, fields: str = "name,desc,idList") -> list[dict]:
        return T.api("GET", f"/boards/{board_id}/cards", {"fields": fields, "limit": 1000})

    def resolve_member(self, name: str, board_id: str) -> str | None:
        return T.resolve_member(name, board_id)

    def add_member(self, card_id: str, member_id: str) -> None:
        T.api("POST", f"/cards/{card_id}/idMembers", {"value": member_id})

    def ensure_label(self, board_id: str, name: str, colour: str) -> str:
        return T.ensure_label(board_id, name, colour)

    def ensure_checklist(self, card_id: str, name: str, items: list[str]) -> str | None:
        return T.ensure_checklist(card_id, name, items)

    def post_comment(self, card_id: str, text: str) -> str:
        r = T.api("POST", f"/cards/{card_id}/actions/comment", {"text": text[:16000]})
        return r.get("id", "posted")

    def create_subtask(self, parent_id: str, name: str, desc: str = "") -> str:
        # Trello doesn't have native subtasks; use checklists instead
        cl_id = self.ensure_checklist(parent_id, "Subtasks", [name])
        return cl_id or parent_id

    def set_custom_field(self, card_id: str, field_name: str, value: Any) -> None:
        # Trello custom fields require the custom fields power-up; not implemented
        pass


# Re-export for convenience
__all__ = ["TrelloAdapter"]
