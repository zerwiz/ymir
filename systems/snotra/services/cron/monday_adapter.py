#!/usr/bin/env python3
"""monday_adapter — the Monday.com implementation of OrgAdapter.

WHY: Monday.com is the second organization tool to support. Its GraphQL API,
board/group/item/column model maps to the place contract's board/lists/cards.

WHAT IT DOES: implements every OrgAdapter verb using the Monday.com GraphQL API v2.
Monday's model: boards contain groups (lists) and items (cards). Columns are typed
(text, status, person, date, etc.) — a card's "status" is a column value, not a list.

NOTE: This is a functional stub. Full implementation requires Monday.com OAuth2
grant and GraphQL query testing against a live Monday account.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from org_adapter import OrgAdapter
import trello_client as T  # noqa: E402  # for home_dir and token helpers

MONDAY_API = "https://api.monday.com/v2"
GRANT_KEY = "mcp__monday|https://api.monday.com"


class MondayAdapter(OrgAdapter):
    """Monday.com implementation of the organization tool adapter."""

    def authenticate(self) -> str:
        token = os.environ.get("MONDAY_TOKEN")
        if token:
            return token
        # Fall back to MCP auth grant (when available)
        try:
            d = json.load(open(os.path.expanduser("~/.pi/agent/mcp-auth.json")))
            v = d.get(GRANT_KEY)
            if v:
                return v["tokens"]["access_token"]
        except (OSError, KeyError):
            pass
        self.die("no Monday.com token — set MONDAY_TOKEN or connect the Monday MCP server")

    def _graphql(self, query: str, variables: dict | None = None) -> dict:
        import urllib.request, urllib.parse
        data = json.dumps({"query": query, "variables": variables or {}}).encode()
        req = urllib.request.Request(
            MONDAY_API, data=data,
            headers={"Authorization": self.token, "Content-Type": "application/json"},
        )
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read().decode())

    def ensure_board(self, name: str, org: str | None = None) -> str:
        # Find by name
        q = 'query { boards (limit: 100) { id name } }'
        result = self._graphql(q)
        for b in result.get("data", {}).get("boards", []):
            if b["name"].strip().lower() == name.strip().lower():
                return b["id"]
        # Create
        q = 'mutation ($name: String!) { create_board (board_name: $name, board_kind: private) { id } }'
        result = self._graphql(q, {"name": name})
        return result["data"]["create_board"]["id"]

    def board_id_of(self, name: str) -> str:
        return self.ensure_board(name)

    def list_lists(self, board_id: str) -> list[dict]:
        q = 'query ($id: [ID!]) { boards (ids: $id) { groups { id title } } }'
        result = self._graphql(q, {"id": [board_id]})
        boards = result.get("data", {}).get("boards", [])
        if not boards:
            return []
        return [{"name": g["title"], "id": g["id"], "pos": i} for i, g in enumerate(boards[0].get("groups", []))]

    def ensure_list(self, board_id: str, name: str) -> str:
        for l in self.list_lists(board_id):
            if l["name"].strip().lower() == name.strip().lower():
                return l["id"]
        q = 'mutation ($board_id: ID!, $group_name: String!) { create_group (board_id: $board_id, group_name: $group_name) { id } }'
        result = self._graphql(q, {"board_id": board_id, "group_name": name})
        return result["data"]["create_group"]["id"]

    def resolve_list(self, board_id: str, name: str) -> str:
        for l in self.list_lists(board_id):
            if l["name"].strip().lower() == name.strip().lower():
                return l["id"]
        self.die(f"board {board_id} has no group matching {name!r}")

    def create_card(self, list_id: str, board_id: str, name: str, desc: str,
                    label_ids: list[str] | None = None, member_id: str | None = None,
                    due: str | None = None) -> dict:
        q = 'mutation ($board_id: ID!, $group_id: String!, $item_name: String!) { create_item (board_id: $board_id, group_id: $group_id, item_name: $item_name) { id } }'
        result = self._graphql(q, {"board_id": board_id, "group_id": list_id, "item_name": name})
        item_id = result["data"]["create_item"]["id"]
        # Set description as an update
        if desc:
            self.update_card(item_id, desc=desc)
        return {"id": item_id, "name": name}

    def update_card(self, card_id: str, **params) -> dict:
        # Monday uses column values for metadata; description goes in an update
        if "desc" in params:
            q = 'mutation ($item_id: ID!, $body: String!) { create_update (item_id: $item_id, body: $body) { id } }'
            self._graphql(q, {"item_id": card_id, "body": params["desc"]})
        return {"id": card_id}

    def move_card(self, card_id: str, list_id: str) -> dict:
        q = 'mutation ($item_id: ID!, $group_id: String!) { move_item_to_group (item_id: $item_id, group_id: $group_id) { id } }'
        result = self._graphql(q, {"item_id": card_id, "group_id": list_id})
        return result.get("data", {}).get("move_item_to_group", {"id": card_id})

    def get_card(self, card_id: str) -> dict:
        q = 'query ($id: [ID!]) { items (ids: $id) { id name group { id title } } }'
        result = self._graphql(q, {"id": [card_id]})
        items = result.get("data", {}).get("items", [])
        return items[0] if items else {"id": card_id}

    def board_cards(self, board_id: str, fields: str = "name,desc,idList") -> list[dict]:
        q = 'query ($id: [ID!]) { boards (ids: $id) { groups { id title items { id name } } } }'
        result = self._graphql(q, {"id": [board_id]})
        cards = []
        for b in result.get("data", {}).get("boards", []):
            for g in b.get("groups", []):
                for item in g.get("items", []):
                    cards.append({"id": item["id"], "name": item["name"], "idList": g["id"]})
        return cards

    def resolve_member(self, name: str, board_id: str) -> str | None:
        q = 'query { users { id name email } }'
        result = self._graphql(q)
        for u in result.get("data", {}).get("users", []):
            if u.get("name", "").strip().lower() == name.strip().lower():
                return u["id"]
        return None

    def add_member(self, card_id: str, member_id: str) -> None:
        # Monday uses people columns; set via column_values
        q = 'mutation ($item_id: ID!, $column_id: String!, $value: JSON!) { change_column_value (item_id: $item_id, column_id: $column_id, value: $value) { id } }'
        self._graphql(q, {"item_id": card_id, "column_id": "person", "value": json.dumps({"personsAndTeams": [{"id": int(member_id), "kind": "person"}]})})

    def ensure_label(self, board_id: str, name: str, colour: str) -> str:
        # Monday uses status columns, not labels. Return a pseudo-id.
        return f"label:{name}"

    def ensure_checklist(self, card_id: str, name: str, items: list[str]) -> str | None:
        # Monday doesn't have native checklists; use subitems instead
        for item in items:
            self.create_subtask(card_id, item)
        return None

    def post_comment(self, card_id: str, text: str) -> str:
        q = 'mutation ($item_id: ID!, $body: String!) { create_update (item_id: $item_id, body: $body) { id } }'
        result = self._graphql(q, {"item_id": card_id, "body": text[:16000]})
        return result.get("data", {}).get("create_update", {}).get("id", "posted")

    def create_subtask(self, parent_id: str, name: str, desc: str = "") -> str:
        q = 'mutation ($parent_id: ID!, $item_name: String!) { create_subitem (parent_item_id: $parent_id, item_name: $item_name) { id } }'
        result = self._graphql(q, {"parent_id": parent_id, "item_name": name})
        return result.get("data", {}).get("create_subitem", {}).get("id", parent_id)

    def set_custom_field(self, card_id: str, field_name: str, value: Any) -> None:
        # Monday columns are identified by column id, not name
        pass
