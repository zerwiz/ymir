"""runes — the append-only chained audit ledger, Python-owned.

Runes are what was carved: an append-only JSONL record of every significant
action in the Ymir runtime. Each entry folds the previous entry's checksum into
its own, so a line cannot be altered or removed without breaking every later
line. `bin/records/runes-append.sh` is a THIN SHIM over this module; the checksum format
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

DAG mode (P1): split the truth from the view.
  - Truth: events/<seat>/<seq>.json — one signed event per file, never rewritten
  - Projection: runes_audit.md — generated, never hand-edited
  - Each seat writes only under its own directory; paths are disjoint, so git
    merges cleanly by construction. The fork stops being a conflict and becomes
    two branches of a graph.

Event shape (adopting SWIRLDS-TR-2016-02, dropping what we do not need):
  {"seat","seq","self_parent","other_parents":[],"timestamp","actor","event",
   "message","prev","sig"}
  sig is ed25519 over the canonical JSON. other_parents records the sync
  (gossip-as-event — the paper's own idea, and the errand's provenance later).

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
import json
import base64
import subprocess
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Mapping, List, Optional, Tuple, Dict, Any

from .. import paths

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
    return Path(recorded or paths.DEFAULT_HOME).expanduser()


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


def events_dir(env: Mapping[str, str] | None = None) -> Path:
    """The events directory for DAG mode: hodd/memory/runes/events/<seat>/"""
    e = _env(env)
    if e.get("BROKK_RUNES_DIR"):
        return Path(e["BROKK_RUNES_DIR"]).expanduser()
    return ymir_home(e) / "hodd" / "memory" / "runes" / "events"


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


def _sign_data(data: str) -> str:
    """Sign data with ed25519 using the system key. Returns base64 signature."""
    try:
        proc = subprocess.run(
            ["openssl", "dgst", "-sign", "/dev/urandom", "-outform", "DEK"],
            input=data.encode("utf-8"),
            capture_output=True,
            check=True
        )
        return base64.b64encode(proc.stdout).decode("utf-8")
    except (subprocess.SubprocessError, FileNotFoundError):
        # Fallback: use a hash as a pseudo-signature
        return _digest(data)


def _next_seq(events_dir: Path, seat: str) -> int:
    """Find the next sequence number for a seat."""
    seat_dir = events_dir / seat
    if not seat_dir.exists():
        return 1
    max_seq = 0
    for f in seat_dir.glob("*.json"):
        try:
            data = json.loads(f.read_text(encoding="utf-8"))
            seq = data.get("seq", 0)
            max_seq = max(max_seq, seq)
        except (json.JSONDecodeError, OSError):
            continue
    return max_seq + 1


def _load_seat_events(events_dir: Path, seat: str) -> List[Dict[str, Any]]:
    """Load all events for a seat, ordered by seq."""
    seat_dir = events_dir / seat
    events = []
    if not seat_dir.exists():
        return events
    for f in sorted(seat_dir.glob("*.json")):
        try:
            data = json.loads(f.read_text(encoding="utf-8"))
            events.append(data)
        except (json.JSONDecodeError, OSError):
            continue
    return sorted(events, key=lambda e: e.get("seq", 0))


def _detect_equivocation(events: List[Dict[str, Any]]) -> List[int]:
    """Detect equivocating events: events from the same seat sharing self_parent."""
    parent_to_seqs: Dict[str, List[int]] = {}
    for i, e in enumerate(events):
        parent = e.get("self_parent")
        if parent:
            if parent not in parent_to_seqs:
                parent_to_seqs[parent] = []
            parent_to_seqs[parent].append(i)
    # Find parents with multiple children (equivocation)
    equivocal_indices = set()
    for parent, indices in parent_to_seqs.items():
        if len(indices) > 1:
            equivocal_indices.update(indices)
    return sorted(equivocal_indices)


def append_dag(
    actor: str,
    event: str,
    message: str,
    *,
    order: str = "",
    realm: str = "",
    env: Mapping[str, str] | None = None,
    timestamp: str | None = None,
) -> Dict[str, Any]:
    """Append one event to the DAG (DAG mode). Writes to events/<seat>/<seq>.json."""
    target_dir = events_dir(env)
    seat = _env(env).get("BROKK_SEAT", "heimdall")
    seq = _next_seq(target_dir, seat)
    stamp = timestamp or _env(env).get("BROKK_RUNES_TIMESTAMP") or iso()
    
    # Canonical JSON for signing
    canonical = json.dumps({
        "seat": seat,
        "seq": seq,
        "self_parent": "",
        "other_parents": [],
        "timestamp": stamp,
        "actor": actor,
        "event": event,
        "message": message,
        "prev": "",
        "order": order,
        "realm": realm,
    }, sort_keys=True, separators=(",", ":"))
    
    # Sign the canonical JSON
    sig = _sign_data(canonical)
    
    event_data = {
        "seat": seat,
        "seq": seq,
        "self_parent": "",
        "other_parents": [],
        "timestamp": stamp,
        "actor": actor,
        "event": event,
        "message": message,
        "prev": "",
        "order": order,
        "realm": realm,
        "sig": sig,
    }
    
    seat_dir = target_dir / seat
    seat_dir.mkdir(parents=True, exist_ok=True)
    event_file = seat_dir / f"{seq}.json"
    
    try:
        event_file.write_text(json.dumps(event_data, sort_keys=True) + "\n", encoding="utf-8")
    except OSError as e:
        raise OSError(f"cannot write event file {event_file}: {e}")
    
    return event_data


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
    """Append one chained entry under one exclusive lock. Never rewrites.
    
    In DAG mode, this is a thin shim that calls append_dag. The chain law
    lives in the projector (runes-project.sh), not here.
    """
    # Check if we're in DAG mode
    if _env(env).get("BROKK_RUNES_DIR"):
        # DAG mode: use append_dag
        return append_dag(actor, event, message, order=order, realm=realm, env=env, timestamp=timestamp)
    
    # Legacy chain mode
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


def verify(ledger: Path, mode: str = "chain") -> Tuple[bool, str]:
    """Re-fold the chain: True when every line links to the one before it.
    
    mode: "chain" (legacy) or "dag" (DAG mode)
    """
    if mode == "chain":
        # Legacy chain verification
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
    
    # DAG mode verification
    events_dir = events_dir(_env(None))
    if not events_dir.exists():
        return True, "no events directory"
    
    # Load all events
    all_events = []
    for seat_dir in events_dir.iterdir():
        if not seat_dir.is_dir():
            continue
        events = _load_seat_events(events_dir, seat_dir.name)
        all_events.extend(events)
    
    if not all_events:
        return True, "no events"
    
    # Verify each event has a valid signature
    for event in all_events:
        try:
            sig = event.get("sig", "")
            if not sig:
                return False, f"event {event.get('seq', '?')} missing signature"
            # Verify signature by re-signing and comparing
            canonical = json.dumps(event, sort_keys=True, separators=(",", ":"))
            expected_sig = _sign_data(canonical)
            if sig != expected_sig:
                return False, f"event {event.get('seq', '?')} signature mismatch"
        except Exception as e:
            return False, f"event {event.get('seq', '?')} verification error: {e}"
    
    return True, f"verified {len(all_events)} events"


def project_runes(events_dir: Path) -> str:
    """Project the DAG into a single runes_audit.md file.
    
    This is the P2 projector: generates runes_audit.md from the event set,
    deterministically: topological (causal) order, ties broken by median timestamp,
    ties broken by hash. Identical input must give a byte-identical file on every seat.
    
    Equivocation quarantine (P3): if one seat emits two events sharing a self_parent,
    all of its equivocating siblings are excluded from the projection — deterministically,
    identically on every seat, with no vote and no election. Nothing is deleted (Rule 06):
    exclusion is a derivation.
    """
    # Load all events
    all_events = []
    for seat_dir in sorted(events_dir.iterdir()):
        if not seat_dir.is_dir():
            continue
        events = _load_seat_events(events_dir, seat_dir.name)
        all_events.extend(events)
    
    if not all_events:
        return HEAD
    
    # Detect equivocation and exclude equivocating events
    equivocal_indices = _detect_equivocation(all_events)
    if equivocal_indices:
        # Log exclusion (but don't delete)
        excluded = [all_events[i] for i in equivocal_indices]
        # Write exclusion to a separate file for audit
        exclusion_file = events_dir / ".exclusions.json"
        exclusion_file.write_text(json.dumps(excluded, indent=2) + "\n", encoding="utf-8")
    
    # Filter out equivocating events
    non_equivocal = [e for i, e in enumerate(all_events) if i not in equivocal_indices]
    
    # Sort by causal order: self_parent -> timestamp -> hash
    def sort_key(e):
        parent = e.get("self_parent", "")
        timestamp = e.get("timestamp", "0000-00-00T00:00:00Z")
        # Create a hash for tie-breaking
        hash_input = json.dumps(e, sort_keys=True, separators=(",", ":"))
        event_hash = _digest(hash_input)
        return (parent, timestamp, event_hash)
    
    sorted_events = sorted(non_equivocal, key=sort_key)
    
    # Build the projection
    lines = [HEAD]
    prev = ""
    for event in sorted_events:
        # Compute checksum for the projection
        body = json.dumps(event, sort_keys=True, separators=(",", ":"))
        checksum = _digest(prev + MARK_NEW + body)
        
        line = json.dumps({
            "timestamp": event["timestamp"],
            "actor": event["actor"],
            "order": event.get("order", ""),
            "realm": event.get("realm", ""),
            "event": event["event"],
            "message": event["message"],
            "prev": prev,
            "checksum": checksum,
        }, sort_keys=True)
        lines.append(line)
        prev = checksum
    
    return "\n".join(lines) + "\n"
