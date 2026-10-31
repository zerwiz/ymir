#!/usr/bin/env python3
"""notion_adapter — the Notion implementation of OrgAdapter.

WHY: Notion is a block-based knowledge base and database tool. Its REST API
supports databases (tables), pages (rows), blocks (content), and comments.

WHAT IT DOES: implements every OrgAdapter verb using the Notion REST API.
Notion's model: databases contain pages. Pages contain blocks (content). A "board"
maps to a database, "lists" map to a status property (select), and "cards" map to
pages.

NOTE: Notion does NOT support native webhooks. Card-movement rules require
polling. This is a functional stub.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from org_adapter import OrgAdapter

NOTION_API = "https://api.notion.com/v1"


class NotionAdapter(OrgAdapter):
    """Notion implementation of the organization tool adapter."""

    def authenticate(self) -> str:
        token = os.environ.get("NOTION_TOKEN")
        if token:
            return token
        try:
            d = json.load(open(os.path.expanduser("~/.pi/agent/mcp-auth.json")))
            v = d.get("mcp__notion|https://api.notion.com")
            if v:
                return v["tokens"]["access_token"]
        except (OSError, KeyError):
            pass
        self.die("no Notion token — set NOTION_TOKEN or connect the Notion MCP server")

    def _api(self, method: str, path: str, data: dict | None = None) -> dict:
        import urllib.request
        url = NOTION_API + path
        body = json.dumps(data).encode() if data else None
        req = urllib.request.Request(url, data=body, method=method,
                                     headers={"Authorization": f"Bearer {self.token}",
                                              "Content-Type": "application/json",
                                              "Notion-Version": "2022-06-28"})
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read().decode())

    def ensure_board(self, name: str, org: str | None = None) -> str:
        # Notion: search for a database with this name
        result = self._api("POST", "/search", {"query": name, "filter": {"value": "database", "property": "object"}})
        for db in result.get("results", []):
            title = "".join(t.get("plain_text", "") for t in db.get("title", []))
            if title.strip().lower() == name.strip().lower():
                return db["id"]
        self.die(f"Notion database {name!r} not found — create it in Notion first")

    def board_id_of(self, name: str) -> str:
        return self.ensure_board(name)

    def list_lists(self, board_id: str) -> list[dict]:
        # Notion: get the database schema to find status/select property values
        db = self._api("GET", f"/databases/{board_id}")
        for prop_name, prop in db.get("properties", {}).items():
            if prop.get("type") in ("select", "status"):
                options = prop.get(prop["type"], {}).get("options", [])
                return [{"name": o["name"], "id": o["id"], "pos": i} for i, o in enumerate(options)]
        return []

    def ensure_list(self, board_id: str, name: str) -> str:
        for l in self.list_lists(board_id):
            if l["name"].strip().lower() == name.strip().lower():
                return l["id"]
        self.die(f"Notion status {name!r} not found in database {board_id}")

    def resolve_list(self, board_id: str, name: str) -> str:
        return self.ensure_list(board_id, name)

    def create_card(self, list_id: str, board_id: str, name: str, desc: str,
                    label_ids: list[str] | None = None, member_id: str | None = None,
                    due: str | None = None) -> dict:
        # Find the status property name
        db = self._api("GET", f"/databases/{board_id}")
        status_prop = None
        for prop_name, prop in db.get("properties", {}).items():
            if prop.get("type") in ("select", "status"):
                status_prop = prop_name
                break
        properties = {"Name": {"title": [{"text": {"content": name}}]}}
        if status_prop and list_id:
            properties[status_prop] = {"select": {"name": list_id}}
        data = {"parent": {"database_id": board_id}, "properties": properties}
        if desc:
            data["children"] = [{"object": "block", "type": "paragraph",
                                 "paragraph": {"rich_text": [{"type": "text", "text": {"content": desc[:2000]}}]}}]
        result = self._api("POST", "/pages", data)
        return {"id": result["id"], "name": name}

    def update_card(self, card_id: str, **params) -> dict:
        data = {"properties": {}}
        if "name" in params:
            data["properties"]["Name"] = {"title": [{"text": {"content": params["name"]}}]}
        if "desc" in params:
            # Notion: append a new paragraph block
            self._api("PATCH", f"/blocks/{card_id}/children", {
                "children": [{"object": "block", "type": "paragraph",
                              "paragraph": {"rich_text": [{"type": "text", "text": {"content": params["desc"][:2000]}}]}}]
            })
        if data["properties"]:
            self._api("PATCH", f"/pages/{card_id}", data)
        return {"id": card_id}

    def move_card(self, card_id: str, list_id: str) -> dict:
        # Notion: update the status property
        self._api("PATCH", f"/pages/{card_id}", {"properties": {"Status": {"select": {"name": list_id}}}})
        return {"id": card_id}

    def get_card(self, card_id: str) -> dict:
        return self._api("GET", f"/pages/{card_id}")

    def board_cards(self, board_id: str, fields: str = "name,desc,idList") -> list[dict]:
        result = self._api("POST", f"/databases/{board_id}/query", {})
        cards = []
        for page in result.get("results", []):
            title = ""
            for prop, val in page.get("properties", {}).items():
                if val.get("type") == "title":
                    title = "".join(t.get("plain_text", "") for t in val.get("title", []))
            cards.append({"id": page["id"], "name": title, "idList": ""})
        return cards

    def resolve_member(self, name: str, board_id: str) -> str | None:
        # Notion: users are workspace members
        result = self._api("GET", "/users")
        for u in result.get("results", []):
            if u.get("name", "").strip().lower() == name.strip().lower():
                return u["id"]
        return None

    def add_member(self, card_id: str, member_id: str) -> None:
        # Notion: people property
        self._api("PATCH", f"/pages/{card_id}", {"properties": {"Assignee": {"people": [{"id": member_id}]}}})

    def ensure_label(self, board_id: str, name: str, colour: str) -> str:
        return f"label:{name}"

    def ensure_checklist(self, card_id: str, name: str, items: list[str]) -> str | None:
        # Notion: checklist as to-do blocks
        children = [{"object": "block", "type": "to_do", "to_do": {"rich_text": [{"type": "text", "text": {"content": item}}], "checked": False}} for item in items]
        self._api("PATCH", f"/blocks/{card_id}/children", {"children": children})
        return None

    def post_comment(self, card_id: str, text: str) -> str:
        result = self._api("POST", "/comments", {"parent": {"page_id": card_id}, "rich_text": [{"type": "text", "text": {"content": text[:2000]}}]})
        return result.get("id", "posted")
