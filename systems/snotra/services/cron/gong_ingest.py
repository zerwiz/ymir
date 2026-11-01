#!/usr/bin/env python3
"""gong_ingest — Gong transcript ingestion adapter."""
from __future__ import annotations
import json, os, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from transcript_ingest import TranscriptSource
GONG_API = "https://api.gong.io/v2"


class GongSource(TranscriptSource):
    def authenticate(self) -> str:
        t = os.environ.get("GONG_TOKEN")
        if t: return t
        try:
            d = json.load(open(os.path.expanduser("~/.pi/agent/mcp-auth.json")))
            v = d.get("mcp__gong|https://api.gong.io")
            if v: return v["tokens"]["access_token"]
        except (OSError, KeyError): pass
        self.die("no Gong token — set GONG_TOKEN (basic auth: access_key:access_key_secret)")

    def _api(self, method, path, params=None, data=None):
        import urllib.request, urllib.parse
        url = GONG_API + path
        if params: url += "?" + urllib.parse.urlencode(params)
        body = json.dumps(data).encode() if data else None
        req = urllib.request.Request(url, data=body, method=method, headers={"Authorization": f"Bearer {self.token}", "Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=60) as r: return json.loads(r.read().decode())

    def list_meetings(self, since=None, until=None):
        data = {}
        if since: data["filter"] = {"fromDateTime": since}
        if until: data.setdefault("filter", {})["toDateTime"] = until
        result = self._api("POST", "/calls", data=data)
        meetings = []
        for c in result.get("calls", []):
            meetings.append({"id": c.get("id", ""), "title": c.get("title", ""),
                "started_at": c.get("started", ""), "ended_at": c.get("ended", ""),
                "participants": c.get("parties", []), "source": "gong"})
        return meetings

    def get_transcript(self, meeting_id):
        result = self._api("GET", f"/calls/{meeting_id}/transcript")
        segments = []
        for seg in result.get("transcript", []):
            for sentence in seg.get("sentences", []):
                segments.append({"speaker": seg.get("speakerId", "unknown"),
                    "timestamp": sentence.get("start", ""), "text": sentence.get("text", "")})
        return {"segments": segments, "meeting_id": meeting_id, "source": "gong"}
