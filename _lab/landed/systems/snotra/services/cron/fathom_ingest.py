#!/usr/bin/env python3
"""fathom_ingest — Fathom transcript ingestion adapter."""
from __future__ import annotations
import json, os, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from transcript_ingest import TranscriptSource
FATHOM_API = "https://api.fathom.ai/v1"


class FathomSource(TranscriptSource):
    def authenticate(self) -> str:
        t = os.environ.get("FATHOM_TOKEN")
        if t: return t
        try:
            d = json.load(open(os.path.expanduser("~/.pi/agent/mcp-auth.json")))
            v = d.get("mcp__fathom|https://api.fathom.ai")
            if v: return v["tokens"]["access_token"]
        except (OSError, KeyError): pass
        self.die("no Fathom token — set FATHOM_TOKEN")

    def _api(self, method, path, params=None):
        import urllib.request, urllib.parse
        url = FATHOM_API + path
        if params: url += "?" + urllib.parse.urlencode(params)
        req = urllib.request.Request(url, method=method, headers={"Authorization": f"Bearer {self.token}", "Accept": "application/json"})
        with urllib.request.urlopen(req, timeout=60) as r: return json.loads(r.read().decode())

    def list_meetings(self, since=None, until=None):
        params = {}
        if since: params["start_date"] = since
        if until: params["end_date"] = until
        result = self._api("GET", "/meetings", params)
        meetings = []
        for m in result.get("meetings", result.get("data", [])):
            meetings.append({"id": m.get("id", ""), "title": m.get("title", m.get("name", "")),
                "started_at": m.get("start_time", m.get("started_at", "")), "ended_at": m.get("end_time", m.get("ended_at", "")),
                "participants": m.get("participants", []), "source": "fathom"})
        return meetings

    def get_transcript(self, meeting_id):
        result = self._api("GET", f"/meetings/{meeting_id}/transcript")
        segments = []
        for s in result.get("transcript", result.get("segments", [])):
            segments.append({"speaker": s.get("speaker", s.get("speaker_name", "unknown")),
                "timestamp": s.get("timestamp", s.get("start_time", "")), "text": s.get("text", s.get("content", ""))})
        return {"segments": segments, "meeting_id": meeting_id, "source": "fathom"}
