"""envelopes — the durable, typed wrappers state files travel in.

An envelope is a named, timestamped record with a flat payload: the shape the
runtime writes whenever it needs a durable hand-off (a seat record, a wake, a
decision marker). Two encodings exist because two readers do:

  meta     `key=value` lines — what the shell doors and the harness extensions
           have always read (`<state>/<id>.meta`), last value wins
  json     one object — what a typed consumer reads

Both are written ATOMICALLY (temp beside the target, then `os.replace`), so a
torn envelope can never be read as a lying one. This module owns the encoding;
callers own the keys.
"""

from __future__ import annotations

import json
import os
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Mapping


def _atomic_write(path: Path, body: str, mode: int = 0o644) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(f".{path.name}.{os.getpid()}.{int(time.time() * 1000)}")
    temp.write_text(body, encoding="utf-8")
    os.chmod(temp, mode)
    os.replace(temp, path)
    return path


@dataclass(frozen=True)
class Envelope:
    """A durable record: kind · id · created · payload."""

    kind: str
    payload: Mapping[str, Any] = field(default_factory=dict)
    id: str = ""
    created: str = ""

    @classmethod
    def of(cls, kind: str, **payload: Any) -> "Envelope":
        return cls(kind=kind, payload=payload, created=_stamp())

    def to_meta(self) -> str:
        return "".join(f"{key}={value}\n" for key, value in self.payload.items())

    def to_json(self) -> str:
        body = {"kind": self.kind, "id": self.id, "created": self.created}
        body.update(self.payload)
        return json.dumps(body, ensure_ascii=False) + "\n"

    def write_meta(self, path: Path, mode: int = 0o644) -> Path:
        return _atomic_write(path, self.to_meta(), mode)

    def write_json(self, path: Path, mode: int = 0o644) -> Path:
        return _atomic_write(path, self.to_json(), mode)

    @classmethod
    def from_meta(cls, text: str, *, kind: str = "") -> "Envelope":
        payload: dict[str, str] = {}
        for line in text.splitlines():
            if "=" not in line:
                continue
            key, _, value = line.partition("=")
            payload[key.strip()] = value.strip()
        return cls(kind=kind, payload=payload)

    @classmethod
    def from_json(cls, text: str) -> "Envelope":
        body = json.loads(text)
        kind = str(body.pop("kind", ""))
        identifier = str(body.pop("id", ""))
        created = str(body.pop("created", ""))
        return cls(kind=kind, payload=body, id=identifier, created=created)

    @classmethod
    def read_meta(cls, path: Path, *, kind: str = "") -> "Envelope":
        return cls.from_meta(path.read_text(encoding="utf-8", errors="replace"), kind=kind)

    @classmethod
    def read_json(cls, path: Path) -> "Envelope":
        return cls.from_json(path.read_text(encoding="utf-8", errors="replace"))


def _stamp() -> str:
    from datetime import datetime, timezone

    return datetime.now(tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
