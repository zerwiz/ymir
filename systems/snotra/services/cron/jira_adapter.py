#!/usr/bin/env python3
"""jira_adapter — the Jira implementation of OrgAdapter.

WHY: Jira is the enterprise organization tool. Its REST API v3, project/issue/board
model maps to the place contract's board/lists/cards. Jira's workflow-based status
transitions are the main difference from Trello's list-based model.

WHAT IT DOES: implements every OrgAdapter verb using the Jira Cloud REST API v3.
Jira's model: projects contain issues. Boards are visual (Kanban/Scrum). Workflows
define issue status transitions. Issues have types (Task, Bug, Story, etc.).

NOTE: This is a functional stub. Full implementation requires Jira OAuth2 (3LO)
grant and API testing against a live Jira instance.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from org_adapter import OrgAdapter

JIRA_API = "https://your-domain.atlassian.net/rest/api/3"


class JiraAdapter(OrgAdapter):
    """Jira Cloud implementation of the organization tool adapter."""

    def authenticate(self) -> str:
        token = os.environ.get("JIRA_TOKEN")
        if token:
            return token
        try:
            d = json.load(open(os.path.expanduser("~/.pi/agent/mcp-auth.json")))
            v = d.get("mcp__jira|https://your-domain.atlassian.net")
            if v:
                return v["tokens"]["access_token"]
        except (OSError, KeyError):
            pass
        self.die("no Jira token — set JIRA_TOKEN or connect the Jira MCP server")

    @property
    def base_url(self) -> str:
        return os.environ.get("JIRA_BASE_URL", "https://your-domain.atlassian.net")

    def _api(self, method: str, path: str, params: dict | None = None, data: dict | None = None) -> dict:
        import urllib.request, urllib.parse
        url = f"{self.base_url}/rest/api/3{path}"
        if params:
            url += "?" + urllib.parse.urlencode(params)
        body = json.dumps(data).encode() if data else None
        req = urllib.request.Request(url, data=body, method=method,
                                     headers={"Authorization": f"Bearer {self.token}",
                                              "Content-Type": "application/json",
                                              "Accept": "application/json"})
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read().decode()) if r.read() else {}

    def ensure_board(self, name: str, org: str | None = None) -> str:
        # Jira: find project by key/name
        result = self._api("GET", "/project/search", {"query": name})
        for p in result.get("values", []):
            if p["name"].strip().lower() == name.strip().lower():
                return p["id"]
        self.die(f"Jira project {name!r} not found — create it in Jira first")

    def board_id_of(self, name: str) -> str:
        return self.ensure_board(name)

    def list_lists(self, board_id: str) -> list[dict]:
        # Jira: statuses for the project's default workflow
        result = self._api("GET", f"/project/{board_id}/statuses")
        statuses = []
        for issue_type in result:
            for status in issue_type.get("statuses", []):
                if status["name"] not in [s["name"] for s in statuses]:
                    statuses.append({"name": status["name"], "id": status["id"], "pos": len(statuses)})
        return statuses

    def ensure_list(self, board_id: str, name: str) -> str:
        # Jira statuses are workflow-defined; cannot create new ones via API
        for l in self.list_lists(board_id):
            if l["name"].strip().lower() == name.strip().lower():
                return l["id"]
        self.die(f"Jira status {name!r} not found in project {board_id}")

    def resolve_list(self, board_id: str, name: str) -> str:
        return self.ensure_list(board_id, name)

    def create_card(self, list_id: str, board_id: str, name: str, desc: str,
                    label_ids: list[str] | None = None, member_id: str | None = None,
                    due: str | None = None) -> dict:
        data = {
            "fields": {
                "project": {"id": board_id},
                "summary": name,
                "description": {
                    "type": "doc", "version": 1,
                    "content": [{"type": "paragraph", "content": [{"type": "text", "text": desc}]}],
                },
                "issuetype": {"name": "Task"},
            }
        }
        if label_ids:
            data["fields"]["labels"] = [l.replace("label:", "") for l in label_ids]
        if member_id:
            data["fields"]["assignee"] = {"accountId": member_id}
        if due:
            data["fields"]["duedate"] = due[:10]
        result = self._api("POST", "/issue", data=data)
        return {"id": result["id"], "key": result.get("key", ""), "name": name}

    def update_card(self, card_id: str, **params) -> dict:
        data = {"fields": {}}
        if "name" in params:
            data["fields"]["summary"] = params["name"]
        if "desc" in params:
            data["fields"]["description"] = {
                "type": "doc", "version": 1,
                "content": [{"type": "paragraph", "content": [{"type": "text", "text": params["desc"]}]}],
            }
        if "due" in params:
            data["fields"]["duedate"] = params["due"][:10] if params["due"] else None
        if data["fields"]:
            self._api("PUT", f"/issue/{card_id}", data=data)
        return {"id": card_id}

    def move_card(self, card_id: str, list_id: str) -> dict:
        # Jira: transition the issue to the new status
        transitions = self._api("GET", f"/issue/{card_id}/transitions")
        for t in transitions.get("transitions", []):
            if t["to"]["name"].strip().lower() == list_id.strip().lower():
                self._api("POST", f"/issue/{card_id}/transitions", data={"transition": {"id": t["id"]}})
                return {"id": card_id}
        self.die(f"no transition to {list_id} for issue {card_id}")

    def transition_card(self, card_id: str, status_name: str) -> dict:
        return self.move_card(card_id, status_name)

    def get_card(self, card_id: str) -> dict:
        return self._api("GET", f"/issue/{card_id}")

    def board_cards(self, board_id: str, fields: str = "name,desc,idList") -> list[dict]:
        result = self._api("GET", "/search", {"jql": f"project = {board_id}", "maxResults": 1000})
        cards = []
        for issue in result.get("issues", []):
            cards.append({"id": issue["id"], "key": issue.get("key", ""),
                          "name": issue["fields"].get("summary", ""),
                          "desc": (issue["fields"].get("description") or {}).get("content", [{}])[0].get("content", [{}])[0].get("text", ""),
                          "idList": issue["fields"].get("status", {}).get("name", "")})
        return cards

    def resolve_member(self, name: str, board_id: str) -> str | None:
        result = self._api("GET", "/user/search", {"query": name})
        for u in result:
            if u.get("displayName", "").strip().lower() == name.strip().lower():
                return u["accountId"]
        return None

    def add_member(self, card_id: str, member_id: str) -> None:
        self._api("PUT", f"/issue/{card_id}", data={"fields": {"assignee": {"accountId": member_id}}})

    def ensure_label(self, board_id: str, name: str, colour: str) -> str:
        return f"label:{name}"

    def ensure_checklist(self, card_id: str, name: str, items: list[str]) -> str | None:
        # Jira: add items as subtasks
        for item in items:
            self.create_subtask(card_id, item)
        return None

    def post_comment(self, card_id: str, text: str) -> str:
        result = self._api("POST", f"/issue/{card_id}/comment", data={
            "body": {"type": "doc", "version": 1,
                     "content": [{"type": "paragraph", "content": [{"type": "text", "text": text[:16000]}]}]},
        })
        return result.get("id", "posted")

    def create_subtask(self, parent_id: str, name: str, desc: str = "") -> str:
        # Find parent issue's project
        parent = self.get_card(parent_id)
        project_id = parent.get("fields", {}).get("project", {}).get("id", "")
        data = {
            "fields": {
                "project": {"id": project_id},
                "summary": name,
                "issuetype": {"name": "Sub-task"},
                "parent": {"id": parent_id},
            }
        }
        if desc:
            data["fields"]["description"] = {
                "type": "doc", "version": 1,
                "content": [{"type": "paragraph", "content": [{"type": "text", "text": desc}]}],
            }
        result = self._api("POST", "/issue", data=data)
        return result["id"]

    def add_dependency(self, card_id: str, depends_on_id: str) -> None:
        self._api("POST", f"/issue/{card_id}/remotelink", data={
            "object": {"url": f"{self.base_url}/browse/{depends_on_id}", "title": f"Depends on {depends_on_id}"},
        })
