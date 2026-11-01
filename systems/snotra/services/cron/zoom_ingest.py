#!/usr/bin/env python3
"""zoom_ingest — Zoom transcript ingestion adapter."""
from __future__ import annotations
import json, os, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from transcript_ingest import TranscriptSource
ZOOM_API = "https://api.zoom.us/v2"


class ZoomSource(TranscriptSource):
    def authenticate(self) -> str:
        t = os.environ.get("ZOOM_TOKEN")
        if t: return t
        try:
            d = json.load(open(os.path.expanduser("~/.pi/agent/mcp-auth.json")))
            v = d.get("mcp__zoom|https://api.zoom.us")
            if v: return v["tokens"]["access_token"]
        except (OSError, KeyError): pass
        self.die("no Zoom token — set ZOOM_TOKEN")

    def _api(self, method, path, params=None):
        import urllib.request, urllib.parse
        url = ZOOM_API + path
        if params: url += "?" + urllib.parse.urlencode(params)
        req = urllib.request.Request(url, method=method, headers={"Authorization": f"Bearer {self.token}", "Accept": "application/json"})
        with urllib.request.urlopen(req, timeout=60) as r: return json.loads(r.read().decode())

    def list_meetings(self, since=None, until=None):
        params = {"type": "previous_meetings"}
        if since: params["from"] = since[:10]
        if until: params["to"] = until[:10]
        result = self._api("GET", "/users/me/meetings", params)
        meetings = []
        for m in result.get("meetings", []):
            meetings.append({"id": str(m.get("id", "")), "title": m.get("topic", ""),
                "started_at": m.get("start_time", ""), "ended_at": "", "participants": [],
                "source": "zoom"})
        return meetings

    def get_transcript(self, meeting_id):
        # Zoom: get recording transcript
        result = self._api("GET", f"/meetings/{meeting_id}/recordings")
        segments = []
        for f in result.get("recording_files", []):
            if f.get("file_type") == "TRANSCRIPT":
                # Download transcript file
                import urllib.request
                req = urllib.request.Request(f.get("download_url", ""), headers={"Authorization": f"Bearer {self.token}"})
                with urllib.request.urlopen(req, timeout=60) as r:
                    text = r.read().decode("utf-8", "replace")
                for line in text.splitlines():
                    if line.strip():
                        segments.append({"speaker": "unknown", "timestamp": "", "text": line.strip()})
        return {"segments": segments, "meeting_id": meeting_id, "source": "zoom"}
