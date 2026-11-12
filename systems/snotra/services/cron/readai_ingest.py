#!/usr/bin/env python3
"""readai_ingest — Read AI transcript ingestion adapter.

WHY: Read AI is one of the most popular AI meeting notetakers. Its REST API
(open beta) provides meeting data and transcripts.

WHAT IT DOES: implements TranscriptSource using the Read AI REST API.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from transcript_ingest import TranscriptSource

READAI_API = "https://api.read.ai/v1"


class ReadAISource(TranscriptSource):
    def authenticate(self) -> str:
        token = os.environ.get("READAI_TOKEN")
        if token:
            return token
        try:
            d = json.load(open(os.path.expanduser("~/.pi/agent/mcp-auth.json")))
            v = d.get("mcp__readai|https://api.read.ai")
            if v:
                return v["tokens"]["access_token"]
        except (OSError, KeyError):
            pass
        self.die("no Read AI token — set READAI_TOKEN")

    def _api(self, method: str, path: str, params: dict | None = None) -> dict:
        import urllib.request, urllib.parse
        url = READAI_API + path
        if params:
            url += "?" + urllib.parse.urlencode(params)
        req = urllib.request.Request(url, method=method,
                                     headers={"Authorization": f"Bearer {self.token}", "Accept": "application/json"})
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read().decode())

    def list_meetings(self, since=None, until=None) -> list[dict]:
        params = {}
        if since:
            params["start_date"] = since
        if until:
            params["end_date"] = until
        result = self._api("GET", "/meetings", params)
        meetings = []
        for m in result.get("meetings", result.get("data", [])):
            meetings.append({
                "id": m.get("id", ""),
                "title": m.get("title", m.get("name", "")),
                "started_at": m.get("start_time", m.get("started_at", "")),
                "ended_at": m.get("end_time", m.get("ended_at", "")),
                "participants": m.get("participants", []),
                "source": "read-ai",
            })
        return meetings

    def get_transcript(self, meeting_id: str) -> dict:
        result = self._api("GET", f"/meetings/{meeting_id}/transcript")
        segments = []
        for s in result.get("transcript", result.get("segments", [])):
            segments.append({
                "speaker": s.get("speaker", s.get("speaker_name", "unknown")),
                "timestamp": s.get("timestamp", s.get("start_time", "")),
                "text": s.get("text", s.get("content", "")),
            })
        return {"segments": segments, "meeting_id": meeting_id, "source": "read-ai"}
