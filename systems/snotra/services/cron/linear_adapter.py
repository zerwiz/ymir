#!/usr/bin/env python3
"""linear_adapter — the Linear implementation of OrgAdapter.

WHY: Linear is a modern issue tracker popular with engineering teams. Its GraphQL
API supports teams, projects, issues, cycles, comments, and labels.

WHAT IT DOES: implements every OrgAdapter verb using the Linear GraphQL API.
Linear's model: teams contain projects and issues. Issues have states (backlog,
todo, in progress, done, canceled). Cycles are time-boxed sprints.

NOTE: This is a functional stub. Full implementation requires Linear OAuth2 grant
and API testing against a live Linear account.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from org_adapter import OrgAdapter

LINEAR_API = "https://api.linear.app/graphql"


class LinearAdapter(OrgAdapter):
    """Linear implementation of the organization tool adapter."""

    def authenticate(self) -> str:
        token = os.environ.get("LINEAR_TOKEN")
        if token:
            return token
        try:
            d = json.load(open(os.path.expanduser("~/.pi/agent/mcp-auth.json")))
            v = d.get("mcp__linear|https://api.linear.app")
            if v:
                return v["tokens"]["access_token"]
        except (OSError, KeyError):
            pass
        self.die("no Linear token — set LINEAR_TOKEN or connect the Linear MCP server")

    def _graphql(self, query: str, variables: dict | None = None) -> dict:
        import urllib.request
        data = json.dumps({"query": query, "variables": variables or {}}).encode()
        req = urllib.request.Request(LINEAR_API, data=data,
                                     headers={"Authorization": self.token, "Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read().decode())

    def ensure_board(self, name: str, org: str | None = None) -> str:
        q = 'query { projects { nodes { id name } } }'
        result = self._graphql(q)
        for p in result.get("data", {}).get("projects", {}).get("nodes", []):
            if p["name"].strip().lower() == name.strip().lower():
                return p["id"]
        # Create project
        q = 'mutation ($name: String!) { projectCreate (input: { name: $name }) { project { id } } }'
        result = self._graphql(q, {"name": name})
        return result["data"]["projectCreate"]["project"]["id"]

    def board_id_of(self, name: str) -> str:
        return self.ensure_board(name)

    def list_lists(self, board_id: str) -> list[dict]:
        # Linear: workflow states
        q = 'query { workflowStates { nodes { id name type } } }'
        result = self._graphql(q)
        states = result.get("data", {}).get("workflowStates", {}).get("nodes", [])
        return [{"name": s["name"], "id": s["id"], "pos": i} for i, s in enumerate(states)]

    def ensure_list(self, board_id: str, name: str) -> str:
        for l in self.list_lists(board_id):
            if l["name"].strip().lower() == name.strip().lower():
                return l["id"]
        self.die(f"Linear state {name!r} not found")

    def resolve_list(self, board_id: str, name: str) -> str:
        return self.ensure_list(board_id, name)

    def create_card(self, list_id: str, board_id: str, name: str, desc: str,
                    label_ids: list[str] | None = None, member_id: str | None = None,
                    due: str | None = None) -> dict:
        # Get team id
        q = 'query { teams { nodes { id } } }'
        result = self._graphql(q)
        team_id = result.get("data", {}).get("teams", {}).get("nodes", [{}])[0].get("id", "")
        q = 'mutation ($title: String!, $teamId: String!, $stateId: String) { issueCreate (input: { title: $title, teamId: $teamId, stateId: $stateId }) { issue { id } } }'
        result = self._graphql(q, {"title": name, "teamId": team_id, "stateId": list_id})
        issue_id = result["data"]["issueCreate"]["issue"]["id"]
        if desc:
            q = 'mutation ($id: String!, $description: String!) { issueUpdate (id: $id, input: { description: $description }) { issue { id } } }'
            self._graphql(q, {"id": issue_id, "description": desc})
        return {"id": issue_id, "name": name}

    def update_card(self, card_id: str, **params) -> dict:
        data = {}
        if "name" in params:
            data["title"] = params["name"]
        if "desc" in params:
            data["description"] = params["desc"]
        if data:
            q = 'mutation ($id: String!, $input: IssueUpdateInput!) { issueUpdate (id: $id, input: $input) { issue { id } } }'
            self._graphql(q, {"id": card_id, "input": data})
        return {"id": card_id}

    def move_card(self, card_id: str, list_id: str) -> dict:
        q = 'mutation ($id: String!, $stateId: String!) { issueUpdate (id: $id, input: { stateId: $stateId }) { issue { id } } }'
        self._graphql(q, {"id": card_id, "stateId": list_id})
        return {"id": card_id}

    def get_card(self, card_id: str) -> dict:
        q = 'query ($id: String!) { issue (id: $id) { id title description state { name } } }'
        result = self._graphql(q, {"id": card_id})
        return result.get("data", {}).get("issue", {"id": card_id})

    def board_cards(self, board_id: str, fields: str = "name,desc,idList") -> list[dict]:
        q = 'query ($projectId: String!) { issues (filter: { project: { id: { eq: $projectId } } }) { nodes { id title description state { name } } } }'
        result = self._graphql(q, {"projectId": board_id})
        cards = []
        for issue in result.get("data", {}).get("issues", {}).get("nodes", []):
            cards.append({"id": issue["id"], "name": issue.get("title", ""),
                          "desc": issue.get("description", ""), "idList": issue.get("state", {}).get("name", "")})
        return cards

    def resolve_member(self, name: str, board_id: str) -> str | None:
        q = 'query { users { nodes { id name } } }'
        result = self._graphql(q)
        for u in result.get("data", {}).get("users", {}).get("nodes", []):
            if u.get("name", "").strip().lower() == name.strip().lower():
                return u["id"]
        return None

    def add_member(self, card_id: str, member_id: str) -> None:
        q = 'mutation ($id: String!, $assigneeId: String!) { issueUpdate (id: $id, input: { assigneeId: $assigneeId }) { issue { id } } }'
        self._graphql(q, {"id": card_id, "assigneeId": member_id})

    def ensure_label(self, board_id: str, name: str, colour: str) -> str:
        q = 'mutation ($name: String!) { issueLabelCreate (input: { name: $name }) { issueLabel { id } } }'
        result = self._graphql(q, {"name": name})
        return result.get("data", {}).get("issueLabelCreate", {}).get("issueLabel", {}).get("id", f"label:{name}")

    def ensure_checklist(self, card_id: str, name: str, items: list[str]) -> str | None:
        # Linear: no native checklists; add as comments
        for item in items:
            self.post_comment(card_id, f"- [ ] {item}")
        return None

    def post_comment(self, card_id: str, text: str) -> str:
        q = 'mutation ($issueId: String!, $body: String!) { commentCreate (input: { issueId: $issueId, body: $body }) { comment { id } } }'
        result = self._graphql(q, {"issueId": card_id, "body": text[:16000]})
        return result.get("data", {}).get("commentCreate", {}).get("comment", {}).get("id", "posted")

    def create_subtask(self, parent_id: str, name: str, desc: str = "") -> str:
        # Linear: sub-issues
        q = 'mutation ($title: String!, $parentId: String!) { issueCreate (input: { title: $title, parentId: $parentId }) { issue { id } } }'
        result = self._graphql(q, {"title": name, "parentId": parent_id})
        return result.get("data", {}).get("issueCreate", {}).get("issue", {}).get("id", parent_id)
