#!/usr/bin/env python3
"""meet_ingest — Google Meet transcript ingestion adapter."""
from __future__ import annotations
import json, os, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from transcript_ingest import TranscriptSource
MEET_API = "https://meet.googleapis.com/v2"


class MeetSource(TranscriptSource):
    def authenticate(self) -> str:
        t = os.environ.get("MEET_TOKEN")
        if t: return t
        try:
            d = json.load(open(os.path.expanduser("~/.pi/agent/mcp-auth.json")))
            v = d.get("mcp__meet|https://meet.googleapis.com")
            if v: return v["tokens"]["access_token"]
        except (OSError, KeyError): pass
        self.die("no Google Meet token — set MEET_TOKEN (Google OAuth)")

    def _api(self, method, path, params=None):
        import urllib.request, urllib.parse
        url = MEET_API + path
        if params: url += "?" + urllib.parse.urlencode(params)
        req = urllib.request.Request(url, method=method, headers={"Authorization": f"Bearer {self.token}", "Accept": "application/json"})
        with urllib.request.urlopen(req, timeout=60) as r: return json.loads(r.read().decode())

    def list_meetings(self, since=None, until=None):
        result = self._api("GET", "/conferenceRecords")
        meetings = []
        for m in result.get("conferenceRecords", []):
            meetings.append({"id": m.get("name", ""), "title": m.get("space", {}).get("config", {}).get("accessType", "Meeting"),
                "started_at": m.get("startTime", ""), "ended_at": m.get("endTime", ""),
                "participants": [], "source": "meet"})
        return meetings

    def get_transcript(self, meeting_id):
        # Google Meet transcripts are stored in Google Drive
        result = self._api("GET", f"/conferenceRecords/{meeting_id}/transcripts")
        segments = []
        for t in result.get("transcripts", []):
            segments.append({"speaker": "unknown", "timestamp": t.get("startTime", ""), "text": t.get("text", "")})
        return {"segments": segments, "meeting_id": meeting_id, "source": "meet"}
