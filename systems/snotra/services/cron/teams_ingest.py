#!/usr/bin/env python3
"""teams_ingest — Microsoft Teams transcript ingestion adapter."""
from __future__ import annotations
import json, os, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from transcript_ingest import TranscriptSource
TEAMS_API = "https://graph.microsoft.com/v1.0"


class TeamsSource(TranscriptSource):
    def authenticate(self) -> str:
        t = os.environ.get("TEAMS_TOKEN")
        if t: return t
        try:
            d = json.load(open(os.path.expanduser("~/.pi/agent/mcp-auth.json")))
            v = d.get("mcp__teams|https://graph.microsoft.com")
            if v: return v["tokens"]["access_token"]
        except (OSError, KeyError): pass
        self.die("no Teams token — set TEAMS_TOKEN (Azure AD OAuth)")

    def _api(self, method, path, params=None):
        import urllib.request, urllib.parse
        url = TEAMS_API + path
        if params: url += "?" + urllib.parse.urlencode(params)
        req = urllib.request.Request(url, method=method, headers={"Authorization": f"Bearer {self.token}", "Accept": "application/json"})
        with urllib.request.urlopen(req, timeout=60) as r: return json.loads(r.read().decode())

    def list_meetings(self, since=None, until=None):
        params = {}
        if since: params["$filter"] = f"start/dateTime ge '{since}'"
        result = self._api("GET", "/me/onlineMeetings", params)
        meetings = []
        for m in result.get("value", []):
            meetings.append({"id": m.get("id", ""), "title": m.get("subject", ""),
                "started_at": m.get("startDateTime", ""), "ended_at": m.get("endDateTime", ""),
                "participants": [], "source": "teams"})
        return meetings

    def get_transcript(self, meeting_id):
        result = self._api("GET", f"/me/onlineMeetings/{meeting_id}/transcripts")
        segments = []
        for t in result.get("value", []):
            # Fetch transcript content
            content = self._api("GET", f"/me/onlineMeetings/{meeting_id}/transcripts/{t['id']}/content", {"format": "text/vtt"})
            for line in (content if isinstance(content, str) else "").splitlines():
                if line.strip() and not line.startswith("WEBVTT") and "-->" not in line:
                    segments.append({"speaker": "unknown", "timestamp": "", "text": line.strip()})
        return {"segments": segments, "meeting_id": meeting_id, "source": "teams"}
