"""runes — the append-only chained audit ledger, Python-owned.

Runes are what was carved: an append-only JSONL record of every significant
action in the Ymir runtime. Each entry folds the previous entry's checksum into
its own, so a line cannot be altered or removed without breaking every later
line. `bin/runes-append.sh` is a THIN SHIM over this module; the checksum format
and the append-only law are preserved to the byte, because the ledger already
has history and the chain must not move.

The chain law, preserved:

  entry    one JSON object per line, keys in this exact order:
           timestamp · actor · order · realm · event · message · prev · checksum
  fold     checksum = sha256(prev + "\\n" + base), where base is the entry
           without the closing brace and without the checksum
  head     the Markdown head is written once, when the ledger does not exist
  lock     one exclusive flock around read-previous + append, so concurrent
           writers can never fork the chain
  never    an existing entry is never rewritten and the ledger is never truncated

A parity mismatch is a refusal, not an overwrite: this module writes the same
line the shell library wrote, and the ledger's own history is the proof.
"""

from __future__ import annotations

import fcntl
import hashlib
import os
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Mapping

HEAD = (
    "# RUNES Audit Trail\n"
    "> Append-only log of all significant system actions across Ymir\n"
    "\n"
    "---\n"
    "\n"
)
MARK_NEW = "\n"


def _env(env: Mapping[str, str] | None) -> dict[str, str]:
    return dict(os.environ) if env is None else dict(env)


def ymir_home(env: Mapping[str, str] | None = None) -> Path:
    """The operator's home, resolved the one way (Rule 07)."""
    e = _env(env)
    if e.get("YMIR_HOME"):
        return Path(e["YMIR_HOME"]).expanduser()
    pointer = Path(e.get("YMIR_CONFIG_DIR") or Path(e.get("XDG_CONFIG_HOME") or "~/.config").expanduser() / "ymir")
    try:
        recorded = pointer.joinpath("home").read_text(encoding="utf-8").splitlines()[0].strip()
    except (OSError, IndexError):
        recorded = ""
    return Path(recorded or "~/Documents/ymirhome").expanduser()


def home(env: Mapping[str, str] | None = None) -> Path:
    """`BROKK_HOME` — the home that owns the ledger's lock (the shell contract)."""
    e = _env(env)
    if e.get("BROKK_HOME"):
        return Path(e["BROKK_HOME"]).expanduser()
    return Path(e.get("BROKK_ROOT_OVERRIDE") or Path(__file__).resolve().parents[3]).expanduser()


def file_path(env: Mapping[str, str] | None = None) -> Path:
    e = _env(env)
    if e.get("BROKK_RUNES_FILE"):
        return Path(e["BROKK_RUNES_FILE"]).expanduser()
    base = e.get("BROKK_RUNES_DIR")
    if base:
        return Path(base).expanduser() / "runes_audit.md"
    return ymir_home(e) / "hodd" / "memory" / "runes_audit.md"


def lock_path(env: Mapping[str, str] | None = None) -> Path:
    e = _env(env)
    if e.get("BROKK_RUNES_LOCK"):
        return Path(e["BROKK_RUNES_LOCK"]).expanduser()
    return home(e) / "state" / "runes.lock"


def escape(text: str) -> str:
    """The shell library's JSON escape, in the same order: \\ " newline CR tab."""
    return (
        text.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
    )


def _digest(data: str) -> str:
    return hashlib.sha256(data.encode("utf-8")).hexdigest()


def last_checksum(ledger: Path) -> str:
    try:
        text = ledger.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""
    found = None
    for line in text.splitlines():
        if '"checksum":"' in line:
            for match in _iter_checksums(line):
                found = match
    return found or ""


def _iter_checksums(line: str):
    start = 0
    marker = '"checksum":"'
    while True:
        index = line.find(marker, start)
        if index < 0:
            return
        begin = index + len(marker)
        end = line.find('"', begin)
        if end < 0:
            return
        yield line[begin:end]
        start = end + 1


def ensure_head(ledger: Path) -> bool:
    try:
        ledger.parent.mkdir(parents=True, exist_ok=True)
    except OSError:
        return False
    if ledger.exists():
        return True
    try:
        ledger.write_text(HEAD, encoding="utf-8")
        return True
    except OSError:
        return False


def iso(epoch: float | None = None) -> str:
    moment = datetime.fromtimestamp(epoch if epoch is not None else time.time(), tz=timezone.utc)
    return moment.strftime("%Y-%m-%dT%H:%M:%SZ")


@dataclass(frozen=True)
class Rune:
    """One chained entry — the durable shape, never rewritten."""

    timestamp: str
    actor: str
    event: str
    message: str
    prev: str
    checksum: str
    order: str = ""
    realm: str = ""

    def body(self) -> str:
        """The entry without its closing brace or checksum — the folded base."""
        return (
            f'{{"timestamp":"{self.timestamp}"'
            f',"actor":"{escape(self.actor)}"'
            f',"order":"{escape(self.order)}"'
            f',"realm":"{escape(self.realm)}"'
            f',"event":"{escape(self.event)}"'
            f',"message":"{escape(self.message)}"'
            f',"prev":"{self.prev}"'
        )

    def to_line(self) -> str:
        return f'{self.body()},"checksum":"{self.checksum}"}}'


def compute(timestamp: str, actor: str, event: str, message: str, prev: str,
            order: str = "", realm: str = "") -> str:
    probe = Rune(
        timestamp=timestamp, actor=actor, event=event, message=message,
        prev=prev, checksum="", order=order, realm=realm,
    )
    return _digest(prev + MARK_NEW + probe.body())


def append(
    actor: str,
    event: str,
    message: str,
    *,
    order: str = "",
    realm: str = "",
    env: Mapping[str, str] | None = None,
    ledger: Path | None = None,
    lock: Path | None = None,
    timestamp: str | None = None,
) -> Rune:
    """Append one chained entry under one exclusive lock. Never rewrites."""
    target = ledger or file_path(env)
    lock_file = lock or lock_path(env)
    if not ensure_head(target):
        raise OSError(f"cannot write the Runes ledger at {target}")
    stamp = timestamp or _env(env).get("BROKK_RUNES_TIMESTAMP") or iso()
    lock_file.parent.mkdir(parents=True, exist_ok=True)
    with lock_file.open("a", encoding="utf-8") as handle:
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
        try:
            prev = last_checksum(target)
            checksum = compute(stamp, actor, event, message, prev, order=order, realm=realm)
            rune = Rune(
                timestamp=stamp, actor=actor, event=event, message=message,
                prev=prev, checksum=checksum, order=order, realm=realm,
            )
            with target.open("a", encoding="utf-8") as out:
                out.write(rune.to_line() + "\n")
            return rune
        finally:
            fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


def verify(ledger: Path) -> tuple[bool, str]:
    """Re-fold the chain: True when every line links to the one before it."""
    import json

    prev = ""
    try:
        lines = ledger.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError as exc:
        return False, str(exc)
    for line in lines:
        if not line.startswith("{") or '"checksum":"' not in line:
            continue
        entry = json.loads(line)
        recomputed = compute(
            entry["timestamp"], entry["actor"], entry["event"], entry["message"],
            prev, order=entry.get("order", ""), realm=entry.get("realm", ""),
        )
        if entry.get("prev", "") != prev or entry["checksum"] != recomputed:
            return False, f"chain break at {entry.get('timestamp', '?')}"
        prev = entry["checksum"]
    return True, prev
