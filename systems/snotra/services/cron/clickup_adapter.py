#!/usr/bin/env python3
"""clickup_adapter — the ClickUp implementation of OrgAdapter.

WHY: ClickUp is a flexible task management platform with a hierarchical model
(workspace → space → folder → list → task). Its REST API supports tasks, subtasks,
custom fields, comments, and webhooks.

WHAT IT DOES: implements every OrgAdapter verb using the ClickUp REST API v2.
ClickUp's model: workspaces contain spaces, spaces contain folders, folders contain
lists, lists contain tasks. Tasks support subtasks, dependencies, custom fields.

NOTE: This is a functional stub. Full implementation requires ClickUp OAuth2 grant
and API testing against a live ClickUp account.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from org_adapter import OrgAdapter

CLICKUP_API = "https://api.clickup.com/api/v2"


class ClickUpAdapter(OrgAdapter):
    """ClickUp implementation of the organization tool adapter."""

    def authenticate(self) -> str:
        token = os.environ.get("CLICKUP_TOKEN")
        if token:
            return token
        try:
            d = json.load(open(os.path.expanduser("~/.pi/agent/mcp-auth.json")))
            v = d.get("mcp__clickup|https://api.clickup.com")
            if v:
                return v["tokens"]["access_token"]
        except (OSError, KeyError):
            pass
        self.die("no ClickUp token — set CLICKUP_TOKEN or connect the ClickUp MCP server")

    def _api(self, method: str, path: str, params: dict | None = None, data: dict | None = None) -> dict:
        import urllib.request, urllib.parse
        url = CLICKUP_API + path
        if params:
            url += "?" + urllib.parse.urlencode(params)
        body = json.dumps(data).encode() if data else None
        req = urllib.request.Request(url, data=body, method=method,
                                     headers={"Authorization": self.token, "Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read().decode())

    def ensure_board(self, name: str, org: str | None = None) -> str:
        # ClickUp: find list by name in the workspace
        ws_id = os.environ.get("CLICKUP_WORKSPACE", "")
        if not ws_id:
            result = self._api("GET", "/team")
            teams = result.get("teams", [])
            if teams:
                ws_id = teams[0]["id"]
        # Search for a list with this name
        result = self._api("GET", f"/team/{ws_id}/space")
        for space in result.get("spaces", []):
            result2 = self._api("GET", f"/space/{space['id']}/list")
            for lst in result2.get("lists", []):
                if lst["name"].strip().lower() == name.strip().lower():
                    return lst["id"]
        # Create in first space
        spaces = result.get("spaces", [])
        if spaces:
            result = self._api("POST", f"/space/{spaces[0]['id']}/list", data={"name": name})
            return result["id"]
        self.die(f"no ClickUp space found for {name!r}")

    def board_id_of(self, name: str) -> str:
        return self.ensure_board(name)

    def list_lists(self, board_id: str) -> list[dict]:
        # ClickUp: statuses within a list
        result = self._api("GET", f"/list/{board_id}")
        statuses = result.get("statuses", [])
        return [{"name": s["status"], "id": s["status"], "pos": i} for i, s in enumerate(statuses)]

    def ensure_list(self, board_id: str, name: str) -> str:
        # ClickUp statuses are list-level; cannot create new ones via API
        for l in self.list_lists(board_id):
            if l["name"].strip().lower() == name.strip().lower():
                return l["id"]
        self.die(f"ClickUp status {name!r} not found in list {board_id}")

    def resolve_list(self, board_id: str, name: str) -> str:
        return self.ensure_list(board_id, name)

    def create_card(self, list_id: str, board_id: str, name: str, desc: str,
                    label_ids: list[str] | None = None, member_id: str | None = None,
                    due: str | None = None) -> dict:
        data = {"name": name}
        if desc:
            data["description"] = desc
        if due:
            data["due_date"] = int(due[:10].replace("-", "")) if due else None
        if member_id:
            data["assignees"] = [int(member_id)]
        result = self._api("POST", f"/list/{board_id}/task", data=data)
        return {"id": result["id"], "name": name}

    def update_card(self, card_id: str, **params) -> dict:
        data = {}
        if "name" in params:
            data["name"] = params["name"]
        if "desc" in params:
            data["description"] = params["desc"]
        if "due" in params:
            data["due_date"] = int(params["due"][:10].replace("-", "")) if params["due"] else None
        if data:
            self._api("PUT", f"/task/{card_id}", data=data)
        return {"id": card_id}

    def move_card(self, card_id: str, list_id: str) -> dict:
        self._api("PUT", f"/task/{card_id}", data={"status": list_id})
        return {"id": card_id}

    def get_card(self, card_id: str) -> dict:
        return self._api("GET", f"/task/{card_id}")

    def board_cards(self, board_id: str, fields: str = "name,desc,idList") -> list[dict]:
        result = self._api("GET", f"/list/{board_id}/task")
        cards = []
        for t in result.get("tasks", []):
            cards.append({"id": t["id"], "name": t.get("name", ""),
                          "desc": t.get("description", ""), "idList": t.get("status", {}).get("status", "")})
        return cards

    def resolve_member(self, name: str, board_id: str) -> str | None:
        ws_id = os.environ.get("CLICKUP_WORKSPACE", "")
        if not ws_id:
            result = self._api("GET", "/team")
            teams = result.get("teams", [])
            if teams:
                ws_id = teams[0]["id"]
        result = self._api("GET", f"/team/{ws_id}/member")
        for m in result.get("members", []):
            if m.get("username", "").strip().lower() == name.strip().lower():
                return str(m["id"])
        return None

    def add_member(self, card_id: str, member_id: str) -> None:
        self._api("POST", f"/task/{card_id}/assignee", data={"assignees": [int(member_id)]})

    def ensure_label(self, board_id: str, name: str, colour: str) -> str:
        return f"tag:{name}"

    def ensure_checklist(self, card_id: str, name: str, items: list[str]) -> str | None:
        result = self._api("POST", f"/task/{card_id}/checklist", data={"name": name})
        cl_id = result.get("checklist", {}).get("id")
        if cl_id:
            for item in items:
                self._api("POST", f"/checklist/{cl_id}/checklist_item", data={"name": item})
        return cl_id

    def post_comment(self, card_id: str, text: str) -> str:
        result = self._api("POST", f"/task/{card_id}/comment", data={"comment_text": text[:16000]})
        return result.get("id", "posted")

    def create_subtask(self, parent_id: str, name: str, desc: str = "") -> str:
        data = {"name": name, "parent": parent_id}
        if desc:
            data["description"] = desc
        result = self._api("POST", f"/list/{parent_id}/task", data=data)
        return result["id"]

    def set_custom_field(self, card_id: str, field_name: str, value: Any) -> None:
        # ClickUp custom fields require field ID lookup
        pass
