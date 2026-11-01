#!/usr/bin/env python3
"""transcript_ingest — the transcript ingestion adapter interface.

WHY: Snotra needs to ingest transcripts from multiple sources (Read AI, Fathom,
Zoom, Teams, Meet, Gong, Otter, Knit). Each source has its own API, auth, and
data format. Without a shared interface, each source would need its own pipeline.

WHAT THIS IS: an abstract base class (ABC) that declares the verbs every
transcript source must support. Each source gets its own adapter module that
implements these verbs. The ingestion CLI selects the adapter by --source flag.

THE VERBS:
  authenticate()          → token (OAuth2 or API key)
  list_meetings(since, until) → [meeting: {id, title, started_at, ended_at, participants}]
  get_transcript(meeting_id)  → segments.json shape (speaker, timestamp, text)
  normalize(raw)          → segments.json shape
"""
from __future__ import annotations

import abc
import json
from pathlib import Path
from typing import Any


class TranscriptSource(abc.ABC):
    """Abstract base class for transcript ingestion sources."""

    def __init__(self, config: dict | None = None):
        self.config = config or {}
        self._token: str | None = None

    @abc.abstractmethod
    def authenticate(self) -> str:
        """Return a valid access token."""
        ...

    @property
    def token(self) -> str:
        if self._token is None:
            self._token = self.authenticate()
        return self._token

    @abc.abstractmethod
    def list_meetings(self, since: str | None = None, until: str | None = None) -> list[dict]:
        """List meetings in a date range. Return [{id, title, started_at, ended_at, participants}]."""
        ...

    @abc.abstractmethod
    def get_transcript(self, meeting_id: str) -> dict:
        """Fetch the transcript for a meeting. Return segments.json shape."""
        ...

    def normalize(self, raw: Any) -> dict:
        """Normalize raw source data to segments.json shape. Override in subclasses."""
        return raw

    def die(self, msg: str, code: int = 1):
        import sys
        print(f"{self.__class__.__name__}: {msg}", file=sys.stderr)
        raise SystemExit(code)


def source_for(name: str, config: dict | None = None) -> TranscriptSource:
    """Factory: return the right source adapter for a given name."""
    name = (name or "").strip().lower()
    if name == "knit":
        from knit_ingest import KnitSource
        return KnitSource(config)
    if name == "read-ai":
        from readai_ingest import ReadAISource
        return ReadAISource(config)
    if name == "fathom":
        from fathom_ingest import FathomSource
        return FathomSource(config)
    if name == "zoom":
        from zoom_ingest import ZoomSource
        return ZoomSource(config)
    if name == "teams":
        from teams_ingest import TeamsSource
        return TeamsSource(config)
    if name == "meet":
        from meet_ingest import MeetSource
        return MeetSource(config)
    if name == "gong":
        from gong_ingest import GongSource
        return GongSource(config)
    if name == "otter":
        from otter_ingest import OtterSource
        return OtterSource(config)
    raise ValueError(f"unknown transcript source {name!r}")
