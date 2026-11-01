#!/usr/bin/env python3
"""mimir-log.py — move memory between the engram (the index) and the JSONL log
(the append-only truth), so the well syncs by UNION and never by git-merging a
binary SQLite file.

  export   engram -> log     append every episode the log lacks (hash-deduped)
  reseed   log -> engram     observe every record the engram lacks (hash-deduped)
  union    other -> log      append another log's records we lack (append-only)
  verify   report both counts and the gap that must stay zero

Why this exists. The engram is DERIVED; `hodd/memory/well/episodes.jsonl` is the
durable, append-only, unionable record it is rebuilt from. Two seats can both
remember while one is offline, each appending to its own log; when they meet the
logs UNION (a text append), and each seat re-seeds its own engram from the union.
So a seat knows the whole memory even with the heart down, and no binary file is
ever merged. The bridge appends to the log on every observe; this tool is the
other half — the log <-> index reconciliation.

Stdlib for `export`/`verify`; `reseed` needs the engram engine (the bridge's
interpreter owns it).
"""

from __future__ import annotations

import hashlib
import json
import os
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path


def _ymir_home() -> Path:
    """The operator's home: env -> the recorded choice -> the ONE documented
    default, mirroring bin/vault/hoard-lib.sh and bin/bridge/mimir-bridge.py."""
    env = os.environ.get("YMIR_HOME")
    if env:
        return Path(env).expanduser()
    cfg = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))
    try:
        rec = (cfg / "ymir" / "home").read_text().strip().splitlines()[0].strip()
        if rec:
            return Path(rec).expanduser()
    except (OSError, IndexError):
        pass
    return Path.home() / "Documents" / "ymirhome"


_home = _ymir_home()
STORE = Path(os.environ.get("ENGRAM_DB", str(_home / "hodd/memory/kaia.engram"))).expanduser()
LOG = Path(os.environ.get("ENGRAM_LOG", str(STORE.parent / "well" / "episodes.jsonl"))).expanduser()


def digest(content: str) -> str:
    return hashlib.sha256(content.encode("utf-8")).hexdigest()


def _loads_list(value) -> list:
    if isinstance(value, list):
        return value
    if not value:
        return []
    try:
        out = json.loads(value)
        return list(out) if isinstance(out, list) else [str(out)]
    except Exception:
        return [p for p in str(value).split(",") if p]


def _iso(value) -> str:
    """One timestamp shape on the way into the log: ISO-8601 Z."""
    if value is None:
        return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    if isinstance(value, datetime):
        moment = value
    else:
        text = str(value).strip()
        if not text:
            return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        try:
            moment = datetime.fromisoformat(text.replace("Z", "+00:00"))
        except ValueError:
            return text
    if moment.tzinfo is None:
        moment = moment.replace(tzinfo=timezone.utc)
    return moment.isoformat()


def log_hashes() -> set:
    found = set()
    try:
        for line in LOG.read_text(encoding="utf-8", errors="replace").splitlines():
            line = line.strip()
            if not line.startswith("{"):
                continue
            try:
                h = json.loads(line).get("hash")
            except Exception:
                continue
            if h:
                found.add(h)
    except OSError:
        pass
    return found


def engram_rows():
    con = sqlite3.connect(f"file:{STORE}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    try:
        for r in con.execute(
            "select id, content, timestamp, actors, tags, salience, "
            "importance_score, agent_id, provenance, quarantined "
            "from episodes order by timestamp"
        ):
            yield r
    finally:
        con.close()


def cmd_export() -> int:
    """engram -> log: append every episode the log lacks. Idempotent by hash."""
    have = log_hashes()
    added = seen = 0
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with LOG.open("a", encoding="utf-8") as fh:
        for r in engram_rows():
            content = r["content"] or ""
            d = digest(content)
            if d in have:
                seen += 1
                continue
            rec = {
                "timestamp": _iso(r["timestamp"]),
                "source": r["agent_id"] or "well",
                "actors": _loads_list(r["actors"]),
                "tags": _loads_list(r["tags"]),
                "content": content,
                "salience": r["salience"],
                "importance": r["importance_score"],
                "agent_id": r["agent_id"],
                # The gate's own record travels WITH the episode (plan 136): where
                # it came from, whether the writer had read untrusted content, and
                # which shelf it belongs to. A re-seed that dropped these would
                # restore the words and lose the trust.
                "provenance": r["provenance"],
                "quarantined": bool(r["quarantined"]) if r["quarantined"] is not None else False,
                "hash": d,
            }
            fh.write(json.dumps(rec, ensure_ascii=False) + "\n")
            have.add(d)
            added += 1
    print(f'log-export[1]{{added,already,log,store}}:\n  {added},{seen},"{LOG}","{STORE}"')
    return 0


def cmd_reseed() -> int:
    """log -> engram: observe every record the engram lacks. Idempotent by hash."""
    try:
        from engram import Engram  # noqa: PLC0415
    except Exception:
        print("[mimir-log] reseed needs the engram engine — run under the bridge's python", file=sys.stderr)
        return 1
    present = set()
    for r in engram_rows():
        present.add(digest(r["content"] or ""))
    eng = Engram(path=str(STORE), agent_id="well")
    added = seen = 0
    try:
        lines = LOG.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        lines = []
    for line in lines:
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            e = json.loads(line)
        except Exception:
            continue
        content = e.get("content") or ""
        d = e.get("hash") or digest(content)
        if d in present:
            seen += 1
            continue
        when = None
        ts = e.get("timestamp")
        if ts:
            try:
                when = datetime.fromisoformat(str(ts).replace("Z", "+00:00"))
            except ValueError:
                when = None
        # Provenance and quarantine come back with the words they belong to. The
        # engine accepts only its own three words, so a log written by an older
        # bridge (which knew none of this) falls back to 'external' — the honest
        # default, and never a claim of trust the writer did not make.
        prov = str(e.get("provenance") or "external")
        if prov not in ("user", "tool", "external"):
            prov = "external"
        # The engine is not one version across the fleet: `observe()` on this seat accepts
        # (content, actors, tags, salience, emotional_valence, timestamp) and knows nothing of
        # provenance or quarantine. Ask the signature instead of assuming a release — a reseed
        # that raises TypeError writes the log and leaves the index empty, which is the worst
        # of both (2026-11-01).
        accepted = set()
        try:
            import inspect as _inspect
            accepted = set(_inspect.signature(eng.observe).parameters)
        except (TypeError, ValueError):
            accepted = set()
        kwargs = {
            "actors": e.get("actors") or [e.get("source", "well")],
            "tags": e.get("tags") or ["well"],
            "salience": float(e.get("salience") or 0.5),
            "timestamp": when,
            "provenance": prov,
            "quarantined": bool(e.get("quarantined")),
        }
        if accepted:
            kwargs = {k: v for k, v in kwargs.items() if k in accepted}
        eng.observe(content, **kwargs)
        present.add(d)
        added += 1
    print(f'log-reseed[1]{{observed,already,store,log}}:\n  {added},{seen},"{STORE}","{LOG}"')
    return 0


def cmd_union(other: str) -> int:
    """Append every record of another log that ours lacks. APPEND-ONLY: the
    union of two append-only logs is one log with both sets of lines, never a
    rewrite — which is why the well syncs by this and not by a binary merge."""
    if not other:
        print("usage: mimir-log.sh union <other-log>", file=sys.stderr)
        return 2
    have = log_hashes()
    added = seen = 0
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with LOG.open("a", encoding="utf-8") as out, open(other, encoding="utf-8", errors="replace") as src:
        for line in src:
            line = line.rstrip("\n")
            if not line.strip().startswith("{"):
                continue
            try:
                e = json.loads(line)
            except Exception:
                continue
            d = e.get("hash") or digest(e.get("content") or "")
            if d in have:
                seen += 1
                continue
            out.write(line + "\n")
            have.add(d)
            added += 1
    print(f'log-union[1]{{added,already,other,log}}:\n  {added},{seen},"{other}","{LOG}"')
    return 0


def cmd_verify() -> int:
    """The gap the sync exists to keep at zero: log records vs engram episodes."""
    have = log_hashes()
    eng = set()
    for r in engram_rows():
        eng.add(digest(r["content"] or ""))
    missing_from_log = eng - have
    missing_from_engram = have - eng
    print(
        "log-verify[1]{log,engram,missing_from_log,missing_from_engram}:\n"
        f'  {len(have)},{len(eng)},{len(missing_from_log)},{len(missing_from_engram)}'
    )
    return 0 if not missing_from_log and not missing_from_engram else 1


def main(argv: list) -> int:
    verb = argv[1] if len(argv) > 1 else ""
    if verb == "export":
        return cmd_export()
    if verb == "reseed":
        return cmd_reseed()
    if verb == "verify":
        return cmd_verify()
    if verb == "union":
        return cmd_union(argv[2] if len(argv) > 2 else "")
    print("usage: mimir-log.sh export|reseed|verify|union <other-log>", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
