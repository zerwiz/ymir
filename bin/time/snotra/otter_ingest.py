#!/usr/bin/env python3
"""otter_ingest — Otter.ai transcript ingestion adapter."""
from __future__ import annotations
import json, os, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from transcript_ingest import TranscriptSource
OTTER_API = "https://api.otter.ai/v1"


class OtterSource(TranscriptSource):
    def authenticate(self) -> str:
        t = os.environ.get("OTTER_TOKEN")
        if t: return t
        try:
            d = json.load(open(os.path.expanduser("~/.pi/agent/mcp-auth.json")))
            v = d.get("mcp__otter|https://api.otter.ai")
            if v: return v["tokens"]["access_token"]
        except (OSError, KeyError): pass
        self.die("no Otter token — set OTTER_TOKEN")

    def _api(self, method, path, params=None):
        import urllib.request, urllib.parse
        url = OTTER_API + path
        if params: url += "?" + urllib.parse.urlencode(params)
        req = urllib.request.Request(url, method=method, headers={"Authorization": f"Bearer {self.token}", "Accept": "application/json"})
        with urllib.request.urlopen(req, timeout=60) as r: return json.loads(r.read().decode())

    def list_meetings(self, since=None, until=None):
        result = self._api("GET", "/speeches")
        meetings = []
        for s in result.get("speeches", result.get("data", [])):
            meetings.append({"id": s.get("id", s.get("speech_id", "")), "title": s.get("title", s.get("name", "")),
                "started_at": s.get("created_at", s.get("start_time", "")), "ended_at": s.get("end_time", ""),
                "participants": s.get("speakers", []), "source": "otter"})
        return meetings

    def get_transcript(self, meeting_id):
        result = self._api("GET", f"/speeches/{meeting_id}")
        segments = []
        for u in result.get("transcript", result.get("utterances", [])):
            segments.append({"speaker": u.get("speaker", u.get("speaker_name", "unknown")),
                "timestamp": u.get("start_time", u.get("timestamp", "")), "text": u.get("text", u.get("transcript", ""))})
        return {"segments": segments, "meeting_id": meeting_id, "source": "otter"}
