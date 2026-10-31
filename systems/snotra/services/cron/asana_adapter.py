#!/usr/bin/env python3
"""asana_adapter — the Asana implementation of OrgAdapter.

WHY: Asana is the third organization tool to support. Its REST API, project/section/
task model maps to the place contract's board/lists/cards.

WHAT IT DOES: implements every OrgAdapter verb using the Asana REST API.
Asana's model: workspaces contain projects, projects contain sections (lists) and
tasks (cards). Tasks support subtasks, dependencies, custom fields, comments.

NOTE: This is a functional stub. Full implementation requires Asana OAuth2 grant
and API testing against a live Asana account.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from org_adapter import OrgAdapter

ASANA_API = "https://app.asana.com/api/1.0"


class AsanaAdapter(OrgAdapter):
    """Asana implementation of the organization tool adapter."""

    def authenticate(self) -> str:
        token = os.environ.get("ASANA_TOKEN")
        if token:
            return token
        try:
            d = json.load(open(os.path.expanduser("~/.pi/agent/mcp-auth.json")))
            v = d.get("mcp__asana|https://app.asana.com")
            if v:
                return v["tokens"]["access_token"]
        except (OSError, KeyError):
            pass
        self.die("no Asana token — set ASANA_TOKEN or connect the Asana MCP server")

    def _api(self, method: str, path: str, params: dict | None = None, data: dict | None = None) -> dict:
        import urllib.request, urllib.parse
        url = ASANA_API + path
        if params:
            url += "?" + urllib.parse.urlencode(params)
        body = json.dumps({"data": data}).encode() if data else None
        req = urllib.request.Request(url, data=body, method=method,
                                     headers={"Authorization": f"Bearer {self.token}",
                                              "Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read().decode())

    def ensure_board(self, name: str, org: str | None = None) -> str:
        # Find project by name
        ws = os.environ.get("ASANA_WORKSPACE", "")
        if not ws:
            # List workspaces
            result = self._api("GET", "/workspaces")
            workspaces = result.get("data", [])
            if workspaces:
                ws = workspaces[0]["gid"]
        result = self._api("GET", "/projects", {"workspace": ws})
        for p in result.get("data", []):
            if p["name"].strip().lower() == name.strip().lower():
                return p["gid"]
        # Create
        result = self._api("POST", "/projects", data={"name": name, "workspace": ws})
        return result["data"]["gid"]

    def board_id_of(self, name: str) -> str:
        return self.ensure_board(name)

    def list_lists(self, board_id: str) -> list[dict]:
        result = self._api("GET", f"/projects/{board_id}/sections")
        return [{"name": s["name"], "id": s["gid"], "pos": i} for i, s in enumerate(result.get("data", []))]

    def ensure_list(self, board_id: str, name: str) -> str:
        for l in self.list_lists(board_id):
            if l["name"].strip().lower() == name.strip().lower():
                return l["id"]
        result = self._api("POST", f"/projects/{board_id}/sections", data={"name": name})
        return result["data"]["gid"]

    def resolve_list(self, board_id: str, name: str) -> str:
        for l in self.list_lists(board_id):
            if l["name"].strip().lower() == name.strip().lower():
                return l["id"]
        self.die(f"project {board_id} has no section matching {name!r}")

    def create_card(self, list_id: str, board_id: str, name: str, desc: str,
                    label_ids: list[str] | None = None, member_id: str | None = None,
                    due: str | None = None) -> dict:
        data = {"name": name, "projects": [board_id]}
        if list_id:
            data["memberships"] = [{"project": board_id, "section": list_id}]
        if desc:
            data["notes"] = desc
        if due:
            data["due_on"] = due[:10]
        if member_id:
            data["assignee"] = member_id
        result = self._api("POST", "/tasks", data=data)
        return {"id": result["data"]["gid"], "name": name}

    def update_card(self, card_id: str, **params) -> dict:
        data = {}
        if "name" in params:
            data["name"] = params["name"]
        if "desc" in params:
            data["notes"] = params["desc"]
        if "due" in params:
            data["due_on"] = params["due"][:10] if params["due"] else None
        if "idList" in params:
            # Move to section
            self._api("POST", f"/tasks/{card_id}/addProject", data={"project": params.get("board_id", ""), "section": params["idList"]})
        if data:
            self._api("PUT", f"/tasks/{card_id}", data=data)
        return {"id": card_id}

    def move_card(self, card_id: str, list_id: str) -> dict:
        # Asana: add task to section, remove from old
        self._api("POST", f"/tasks/{card_id}/addProject", data={"project": "", "section": list_id})
        return {"id": card_id}

    def get_card(self, card_id: str) -> dict:
        result = self._api("GET", f"/tasks/{card_id}")
        return result.get("data", {"gid": card_id})

    def board_cards(self, board_id: str, fields: str = "name,desc,idList") -> list[dict]:
        result = self._api("GET", f"/projects/{board_id}/tasks", {"opt_fields": "name,notes,due_on,assignee,completed"})
        cards = []
        for t in result.get("data", []):
            cards.append({"id": t["gid"], "name": t.get("name", ""), "desc": t.get("notes", ""),
                          "due": t.get("due_on"), "idList": ""})
        return cards

    def resolve_member(self, name: str, board_id: str) -> str | None:
        # Asana workspace members
        result = self._api("GET", "/users", {"workspace": os.environ.get("ASANA_WORKSPACE", "")})
        for u in result.get("data", []):
            if u.get("name", "").strip().lower() == name.strip().lower():
                return u["gid"]
        return None

    def add_member(self, card_id: str, member_id: str) -> None:
        self._api("PUT", f"/tasks/{card_id}", data={"assignee": member_id})

    def ensure_label(self, board_id: str, name: str, colour: str) -> str:
        # Asana uses tags, not labels
        return f"tag:{name}"

    def ensure_checklist(self, card_id: str, name: str, items: list[str]) -> str | None:
        # Asana: subtasks
        for item in items:
            self.create_subtask(card_id, item)
        return None

    def post_comment(self, card_id: str, text: str) -> str:
        result = self._api("POST", f"/tasks/{card_id}/stories", data={"text": text[:16000]})
        return result.get("data", {}).get("gid", "posted")

    def create_subtask(self, parent_id: str, name: str, desc: str = "") -> str:
        data = {"name": name, "parent": parent_id}
        if desc:
            data["notes"] = desc
        result = self._api("POST", "/tasks", data=data)
        return result["data"]["gid"]

    def add_dependency(self, card_id: str, depends_on_id: str) -> None:
        self._api("POST", f"/tasks/{card_id}/addDependencies", data={"dependencies": [depends_on_id]})
