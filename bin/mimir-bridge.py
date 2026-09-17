#!/usr/bin/env python3
"""mimir-bridge.py — the HTTP face of the well (Mimirsbrunn / engram, :4602).

The upstream engram engine ships a CLI and an MCP (stdio) server, but the rest
of Ymir — the gate API, `bin/mimir.sh`, `bin/mimir-ingest.sh`, the session
start — speaks a small HTTP contract on 127.0.0.1:4602. This bridge is that
face: a long-lived HTTP server wrapping the `engram` library over one
`.engram` store.

Endpoints:
  GET  /health                 -> {status, store, episodes, agents}
  GET  /recall?q&k&mode        -> {results:[{score, distance, episode}]}
  POST /observe {content,...}  -> {id}
  GET  /timeline?entity=       -> {facts:[...]}
  GET  /inspect                -> {episodes, agents, store}

No secrets here; the store is repo-local. Stdlib only.
"""

from __future__ import annotations

import json
import os
import sqlite3
import threading
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

ROOT = Path(__file__).resolve().parent.parent
# The well is ONE memory and it lives in the hoard — never in the tree and
# never in a migrated copy. The shell bridge passes ENGRAM_DB; this default
# (hoard | legacy-local) keeps a hand-started bridge honest either way.
_home = Path(os.environ.get("YMIR_HOME", str(Path.home() / "Documents/Ymir")))
STORE = Path(os.environ.get(
    "ENGRAM_DB",
    str(_home / "hodd/memory/kaia.engram")
)).expanduser()
HOST = os.environ.get("MIMIRSBRUNN_HOST", "127.0.0.1")
PORT = int(os.environ.get("MIMIRSBRUNN_PORT", os.environ.get("ENGRAM_PORT", "4602")))
DEFAULT_AGENT = os.environ.get("ENGRAM_AGENT_ID", "kaia")

from engram import Engram  # noqa: E402  (after env is read)

_pool: dict[str, Engram] = {}
_lock = threading.Lock()


def engine(agent: str | None) -> Engram:
    """One Engram instance per agent scope (writes are scoped at construction)."""
    key = agent or "__all__"
    with _lock:
        if key not in _pool:
            _pool[key] = Engram(path=str(STORE), agent_id=agent)
        return _pool[key]


def layers():
    """What the well actually holds, layer by layer - the record a UI reads."""
    out = {"facts": 0, "facts_active": 0, "facts_superseded": 0, "entities": 0,
           "edges": 0, "reflections": 0, "last_reflection": None, "vec_index": 0}
    try:
        con = sqlite3.connect(f"file:{STORE}?mode=ro", uri=True)
        for key, sql in (
            ("facts", "select count(*) from facts"),
            ("facts_active", "select count(*) from facts where superseded_at is null"),
            ("facts_superseded", "select count(*) from facts where superseded_at is not null"),
            ("entities", "select count(*) from entities"),
            ("edges", "select count(*) from edges"),
            ("reflections", "select count(*) from reflections"),
            ("vec_index", "select count(*) from vec_episodes_rowids"),
        ):
            try:
                out[key] = int(con.execute(sql).fetchone()[0])
            except Exception:
                pass
        try:
            out["last_reflection"] = con.execute(
                "select max(finished_at) from reflections").fetchone()[0]
        except Exception:
            pass
    except Exception as e:
        out["error"] = str(e)
    return out


def count_episodes() -> int:
    try:
        con = sqlite3.connect(f"file:{STORE}?mode=ro", uri=True)
        try:
            return int(con.execute("select count(*) from episodes").fetchone()[0])
        finally:
            con.close()
    except Exception:
        return 0


def ep_json(e) -> dict:
    return {
        "id": e.id,
        "content": e.content,
        "timestamp": e.timestamp.isoformat() if e.timestamp else None,
        "actors": list(e.actors or []),
        "agents": list(e.actors or []),
        "tags": list(e.tags or []),
        "salience": e.salience,
        "importance": e.importance_score,
        "agent_id": getattr(e, "agent_id", None),
    }


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_args):  # keep the bridge quiet
        pass

    def _json(self, code: int, payload: dict) -> None:
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        u = urlparse(self.path)
        q = parse_qs(u.query)
        try:
            if u.path == "/health":
                return self._json(200, {
                    "status": "up",
                    "store": str(STORE),
                    "episodes": count_episodes(),
                    "agents": engine(None).list_agents(),
                })
            if u.path == "/inspect":
                # THE LAYERS, not just the count. The smithy shows what it is told,
                # and it was told three fields while the well holds six: a panel that
                # reads only episodes cannot show that facts and entities exist.
                return self._json(200, {
                    "store": str(STORE),
                    "episodes": count_episodes(),
                    "agents": engine(None).list_agents(),
                    **layers(),
                })
            if u.path == "/recent":
                limit = int((q.get("limit") or ["60"])[0])
                out = []
                try:
                    con = sqlite3.connect(f"file:{STORE}?mode=ro", uri=True)
                    con.row_factory = sqlite3.Row
                    try:
                        for r in con.execute(
                            "select id, content, timestamp, tags, actors, agent_id "
                            "from episodes order by timestamp desc limit ?",
                            (limit,),
                        ):
                            out.append({
                                "id": r["id"],
                                "content": r["content"],
                                "timestamp": r["timestamp"],
                                "tags": json.loads(r["tags"] or "[]"),
                                "actors": json.loads(r["actors"] or "[]"),
                                "agent_id": r["agent_id"],
                            })
                    finally:
                        con.close()
                except Exception:
                    pass
                return self._json(200, {"episodes": out})
            if u.path == "/episode":
                eid = (q.get("id") or [""])[0]
                if not eid:
                    return self._json(400, {"error": "episode needs id"})
                rec = None
                try:
                    con = sqlite3.connect(f"file:{STORE}?mode=ro", uri=True)
                    con.row_factory = sqlite3.Row
                    try:
                        rec = con.execute(
                            "select id, content, timestamp, tags, actors, agent_id from episodes where id = ?",
                            (eid,),
                        ).fetchone()
                    finally:
                        con.close()
                except Exception:
                    rec = None
                if not rec:
                    return self._json(404, {"error": "no such episode"})
                return self._json(200, {"episode": {
                    "id": rec["id"], "content": rec["content"], "timestamp": rec["timestamp"],
                    "tags": json.loads(rec["tags"] or "[]"),
                    "actors": json.loads(rec["actors"] or "[]"),
                    "agent_id": rec["agent_id"],
                }})
            if u.path == "/recall":
                query = (q.get("q") or [""])[0]
                k = int((q.get("k") or ["5"])[0])
                mode = (q.get("mode") or ["hybrid"])[0]
                agent = (q.get("agent_id") or [None])[0]
                cross = (q.get("cross_agent") or ["1"])[0] not in ("0", "false", "")
                eng = engine(agent)
                hits = eng.recall(query, k=k, mode=mode, cross_agent=cross)
                return self._json(200, {
                    "results": [
                        {"score": r.score, "distance": r.distance, "importance": r.importance, "episode": ep_json(r.episode)}
                        for r in hits
                    ]
                })
            if u.path == "/timeline":
                entity = (q.get("entity") or [""])[0]
                facts = engine(None).timeline(entity)
                return self._json(200, {
                    "facts": [
                        {
                            "id": f.id, "subject": f.subject, "predicate": f.predicate, "object": f.object,
                            "valid_from": f.valid_from.isoformat() if f.valid_from else None,
                            "valid_to": f.valid_to.isoformat() if f.valid_to else None,
                            "confidence": f.confidence,
                        }
                        for f in facts
                    ]
                })
            return self._json(404, {"error": f"no route {u.path}"})
        except Exception as exc:  # noqa: BLE001
            return self._json(500, {"error": str(exc)})

    def do_POST(self) -> None:  # noqa: N802
        u = urlparse(self.path)
        length = int(self.headers.get("content-length") or 0)
        try:
            body = json.loads(self.rfile.read(length) or b"{}")
        except Exception:
            body = {}
        try:
            if u.path in ("/observe", "/remember"):
                content = str(body.get("content") or "").strip()
                if not content:
                    return self._json(400, {"error": "observe needs content"})
                agent = body.get("agent_id") or body.get("source") or DEFAULT_AGENT
                ts = body.get("timestamp")
                when = datetime.fromisoformat(ts) if ts else None
                eid = engine(agent).observe(
                    content,
                    actors=body.get("actors") or None,
                    tags=body.get("tags") or None,
                    salience=float(body.get("salience", 0.5)),
                    timestamp=when,
                )
                return self._json(200, {"id": eid, "agent_id": agent, "episodes": count_episodes()})
            return self._json(404, {"error": f"no route {u.path}"})
        except Exception as exc:  # noqa: BLE001
            return self._json(500, {"error": str(exc)})


def main() -> None:
    STORE.parent.mkdir(parents=True, exist_ok=True)
    # Touch the store so the schema exists before the first request.
    engine(None)
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"[mimir-bridge] Mimirsbrunn {HOST}:{PORT} · store {STORE}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
