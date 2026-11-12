#!/usr/bin/env python3
"""knit_ingest — Knit unified meeting API adapter.

WHY: Knit covers Gong, Chorus, Fireflies, Fathom, Google Meet, and Teams in one
integration. One adapter covers 6 tools.

WHAT IT DOES: implements TranscriptSource using the Knit unified meeting API.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from transcript_ingest import TranscriptSource

KNIT_API = "https://api.getknit.dev/v1.0"


class KnitSource(TranscriptSource):
    def authenticate(self) -> str:
        token = os.environ.get("KNIT_API_KEY")
        if token:
            return token
        try:
            d = json.load(open(os.path.expanduser("~/.pi/agent/mcp-auth.json")))
            v = d.get("mcp__knit|https://api.getknit.dev")
            if v:
                return v["tokens"]["access_token"]
        except (OSError, KeyError):
            pass
        self.die("no Knit API key — set KNIT_API_KEY")

    def _api(self, method: str, path: str, params: dict | None = None) -> dict:
        import urllib.request, urllib.parse
        url = KNIT_API + path
        if params:
            url += "?" + urllib.parse.urlencode(params)
        req = urllib.request.Request(url, method=method,
                                     headers={"Authorization": f"Bearer {self.token}",
                                              "X-Knit-Integration-Id": self.config.get("integration_id", ""),
                                              "Accept": "application/json"})
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read().decode())

    def list_meetings(self, since=None, until=None) -> list[dict]:
        params = {}
        if since:
            params["startDateTime"] = since
        if until:
            params["endDateTime"] = until
        result = self._api("GET", "/meeting.meetings.get", params)
        meetings = []
        for m in result.get("data", {}).get("meetings", []):
            meetings.append({
                "id": m["id"],
                "title": m.get("title", ""),
                "started_at": m.get("startDateTime", ""),
                "ended_at": m.get("scheduledEndDateTime", ""),
                "participants": m.get("participants", []),
                "source": "knit",
            })
        return meetings

    def get_transcript(self, meeting_id: str) -> dict:
        result = self._api("GET", "/meeting.transcript.get", {"meetingId": meeting_id})
        segments = []
        for st in result.get("data", {}).get("meetingTranscripts", []):
            for sent in st.get("sentences", []):
                segments.append({
                    "speaker": st.get("speakerId", "unknown"),
                    "timestamp": sent.get("startedAt", ""),
                    "text": sent.get("text", ""),
                })
        return {"segments": segments, "meeting_id": meeting_id, "source": "knit"}
