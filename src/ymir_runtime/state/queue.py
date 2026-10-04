"""queues — the durable wake queue, Python-owned, appended atomically.

The wake queue is how a worker reaches Brokk with no arm and no session: one
TSV record per line, `<epoch>\\t<seq>\\t<kind>\\t<key>\\t<payload>`. The durable
queue is the authority — a key is present exactly while its record is queued and
unacknowledged, and the drain consumes it.

`bin/time/brokk-wake-lib.sh` (`fm_wake_append` / `fm_wake_queued_keys_locked`) is the
thin shim over this module: the shell keeps the field cleaning and the recovery
marker, and hands the append here. Two append modes exist and the difference is
deliberate:

  locked      the module takes an exclusive flock on `<queue>.lock` around
              read-seq → bump → append (a direct Python caller)
  assumed     the caller already holds the queue lock (the shell shim holds its
              own directory lock) — the append is still a single O_APPEND write

Either way the line is written in ONE write, so a reader never sees half of it.
"""

from __future__ import annotations

import fcntl
import os
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Mapping

WAKE_KINDS = ("signal", "stale", "check", "heartbeat")


def _env(env: Mapping[str, str] | None) -> dict[str, str]:
    return dict(os.environ) if env is None else dict(env)


def clean_field(text: str) -> str:
    """The shell library's `tr '\\t\\r\\n' '   '` — one line, no separators."""
    return text.replace("\t", " ").replace("\r", " ").replace("\n", " ")


@dataclass(frozen=True)
class Wake:
    """One durable wake — the shape the drain prints as `WAKE <line>`."""

    epoch: int
    seq: int
    kind: str
    key: str
    payload: str

    def to_line(self) -> str:
        return f"{self.epoch}\t{self.seq}\t{self.kind}\t{self.key}\t{self.payload}"

    @classmethod
    def parse(cls, line: str) -> "Wake | None":
        fields = line.rstrip("\n").split("\t")
        if len(fields) < 5:
            return None
        epoch, seq, kind, key = fields[0], fields[1], fields[2], fields[3]
        if not epoch.isdigit() or not seq.isdigit():
            return None
        payload = "\t".join(fields[4:])
        return cls(epoch=int(epoch), seq=int(seq), kind=kind, key=key, payload=payload)


def parse_all(text: str) -> list[Wake]:
    wakes: list[Wake] = []
    for line in text.splitlines():
        wake = Wake.parse(line)
        if wake is not None:
            wakes.append(wake)
    return wakes


@dataclass(frozen=True)
class WakeQueue:
    path: Path
    lock_path: Path
    seq_path: Path

    @classmethod
    def resolve(
        cls,
        env: Mapping[str, str] | None = None,
        *,
        path: Path | str | None = None,
    ) -> "WakeQueue":
        from . import lock as lock_mod

        e = _env(env)
        queue = Path(path or e.get("BROKK_WAKE_QUEUE") or (lock_mod.state_dir(e) / ".wake-queue")).expanduser()
        lock = Path(e.get("BROKK_WAKE_QUEUE_LOCK") or Path(str(queue) + ".lock")).expanduser()
        return cls(path=queue, lock_path=lock, seq_path=Path(str(queue) + ".seq"))

    def append(
        self,
        kind: str,
        key: str,
        payload: str,
        *,
        epoch: int | None = None,
        assume_locked: bool = False,
    ) -> Wake:
        if kind not in WAKE_KINDS:
            raise ValueError(f"invalid wake kind: {kind}")
        clean_key = clean_field(key)
        clean_payload = clean_field(payload)
        moment = int(epoch if epoch is not None else time.time())
        self.path.parent.mkdir(parents=True, exist_ok=True)
        if assume_locked:
            return self._append_locked(moment, kind, clean_key, clean_payload)
        self.lock_path.parent.mkdir(parents=True, exist_ok=True)
        with self.lock_path.open("a", encoding="utf-8") as handle:
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
            try:
                return self._append_locked(moment, kind, clean_key, clean_payload)
            finally:
                fcntl.flock(handle.fileno(), fcntl.LOCK_UN)

    def _append_locked(self, epoch: int, kind: str, key: str, payload: str) -> Wake:
        wake = Wake(epoch=epoch, seq=self._next_seq(), kind=kind, key=key, payload=payload)
        with self.path.open("a", encoding="utf-8") as out:
            out.write(wake.to_line() + "\n")
        return wake

    def _next_seq(self) -> int:
        try:
            raw = self.seq_path.read_text(encoding="utf-8", errors="replace").strip()
        except OSError:
            raw = ""
        seq = int(raw) + 1 if raw.isdigit() else 1
        self.seq_path.write_text(f"{seq}\n", encoding="utf-8")
        return seq

    def read(self) -> list[Wake]:
        try:
            text = self.path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            return []
        return parse_all(text)

    def queued_keys(self, kind: str) -> list[str]:
        if kind not in WAKE_KINDS:
            raise ValueError(f"invalid wake kind: {kind}")
        seen: set[str] = set()
        keys: list[str] = []
        for wake in self.read():
            if wake.kind == kind and wake.key not in seen:
                seen.add(wake.key)
                keys.append(wake.key)
        return keys

    def pending(self) -> int:
        return len(self.read())

    def acknowledge(self) -> None:
        """Drop the queue once its wakes have been handled (the drain's `ack`)."""
        try:
            self.path.write_text("", encoding="utf-8")
        except OSError:
            pass


def dedupe(wakes: Iterable[Wake]) -> list[Wake]:
    """The watcher's presentation order: heartbeat collapses, others by kind+key."""
    order: list[tuple[str, str]] = []
    latest: dict[tuple[str, str], Wake] = {}
    for wake in wakes:
        token = ("heartbeat", "") if wake.kind == "heartbeat" else (wake.kind, wake.key)
        if token not in latest:
            order.append(token)
        latest[token] = wake
    return [latest[token] for token in order]
