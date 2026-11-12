#!/usr/bin/env python3
"""voice-toolbox.py — the house's hands for a browser face.

The fourteen voice tools are Python doors in this repo (`bin/voice/voice_tools.py`).
A browser client can only run JavaScript, so this door gives it the same hands over
loopback HTTP:

    GET  /tools          the definitions the client registers with the Realtime session
    POST /tool           {"name": ..., "arguments": {...}} → {"output": ..., "create_response": bool}
    GET  /health         liveness
    GET  /desk           what the window needs to say WHY a call failed: is the engine answering,
                         who holds the microphone (plan 271)

Every call goes through `voice_tools.execute_tool`, so the confirm gate on `hand_over`,
the vault refusal, the seat-scoping and the activity log are exactly the terminal's.

Bind: 127.0.0.1 only (a hand reached from the network is not a hand, it is a hole).
CORS is allowed for loopback origins only, because the UI is served from an ephemeral
loopback port.

    python3 bin/voice/voice-toolbox.py [--port 8891]
"""
from __future__ import annotations

import argparse
import asyncio
import json
import re
import os
import socket
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import voice_tools  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
HOME = Path(os.environ.get("YMIR_HOME") or (Path.home() / "Documents" / "ymirhome"))
SETTINGS = HOME / "hodd" / "state" / "rodd" / "settings.json"
MEMORY = HOME / "hodd" / "state" / "rodd" / "memory.jsonl"
LOSSES = HOME / "hodd" / "state" / "rodd" / "losses.jsonl"
LOOPBACK = ("127.0.0.1", "localhost", "[::1]")

# A memory item that asks her to MERGE is void (plan 254 B7, 2026-11-11): merging is the
# Allfather's hand (Rule 08), and an instruction to merge that sits in her memory is one she
# will meet, refuse, and toast about again every night. The item is never deleted (the
# memory appends); it is served marked void with the reason, so she reads the correction
# beside it instead of re-raising it. A correction row (kind=correction) is never voided.
_MERGE_ASK = re.compile(r"\bmerge\b.*\b(pr|pull request|branch|main|into)\b|\b(pr|pull request)\b.*\bmerge\b", re.I)
VOID_MERGE = "void: merging is the Allfather's hand (Rule 08) — never hers; corrected 2026-11-11"


def _void_if_merge(row):
    if not isinstance(row, dict) or row.get("kind") == "correction":
        return row
    if _MERGE_ASK.search(str(row.get("text", ""))):
        row = dict(row, void=VOID_MERGE)
    return row


def _desk() -> dict:
    """The facts behind a failed connect, asked fresh each time (plan 271 piece 3)."""
    port = int(os.environ.get("YMIR_VOICE_PORT") or 8890)
    up = False
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=1.5):
            up = True
    except OSError:
        pass
    def door(*args: str) -> str:
        try:
            r = subprocess.run(["bash", str(REPO / "bin" / "desk" / "in-call.sh"), *args],
                               capture_output=True, text=True, timeout=5)
            return r.stdout.strip()
        except Exception:
            return ""
    inputs = door("inputs")
    return {"engine_up": up, "engine_port": port, "mic_holder": door("holder"),
            "inputs": int(inputs) if inputs.isdigit() else None,
            "mic_bluetooth": subprocess.run(["bash", str(REPO / "bin" / "desk" / "in-call.sh"), "bluetooth"],
                                            capture_output=True, timeout=5).returncode == 0}


def _rodd_head():
    """The one door for whose mind answers (bin/voice/rodd-head.py)."""
    import importlib.util
    spec = importlib.util.spec_from_file_location("rodd_head", REPO / "bin" / "voice" / "rodd-head.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _read_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def _write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.chmod(tmp, 0o600)
    tmp.replace(path)


def _raise_host() -> dict:
    """Raise the host with whatever head the resolver now names — the one launch path."""
    door = REPO / "bin" / "voice" / "voice-door.sh"
    try:
        out = subprocess.run(["bash", str(door), "host"], capture_output=True, text=True, timeout=240)
    except subprocess.TimeoutExpired:
        return {"ok": False, "detail": "the door did not answer within 240s"}
    tail = (out.stdout or "") + (out.stderr or "")
    return {"ok": out.returncode == 0, "detail": " \u00b7 ".join(tail.strip().splitlines()[-2:])}



class Handler(BaseHTTPRequestHandler):
    server_version = "rodd-toolbox/1.0"

    def _cors(self) -> None:
        origin = self.headers.get("Origin") or ""
        if not origin:
            return
        host = origin.split("//")[-1].split(":")[0]
        if host in LOOPBACK:
            self.send_header("Access-Control-Allow-Origin", origin)
            self.send_header("Vary", "Origin")

    def _json(self, code: int, payload: dict) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self._cors()
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self) -> None:  # noqa: N802
        self.send_response(204)
        self._cors()
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self) -> None:  # noqa: N802
        if self.path.startswith("/health"):
            return self._json(200, {"ok": True, "tools": len(voice_tools.TOOLS)})
        if self.path.startswith("/desk"):
            return self._json(200, _desk())
        if self.path.startswith("/head"):
            r = _rodd_head().resolve()
            r.pop("key", None)          # a secret is never returned to a window
            return self._json(200, r)
        if self.path.startswith("/settings"):
            return self._json(200, _read_json(SETTINGS))
        if self.path.startswith("/memory"):
            rows = []
            try:
                for line in MEMORY.read_text(encoding="utf-8").splitlines()[-40:]:
                    if line.strip():
                        rows.append(_void_if_merge(json.loads(line)))
            except Exception:
                pass
            return self._json(200, {"rows": rows})
        if self.path.startswith("/tools"):
            defs = []
            for t in voice_tools.TOOLS:
                defs.append({
                    "name": t["name"],
                    "description": t.get("description", ""),
                    "parameters": t.get("parameters", {"type": "object", "properties": {}}),
                })
            return self._json(200, {"tools": defs})
        return self._json(404, {"error": "unknown path", "paths": ["/tools", "/tool", "/head", "/settings", "/memory", "/health", "/desk", "/loss"]})

    def do_POST(self) -> None:  # noqa: N802
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) or b"{}"
        try:
            payload = json.loads(raw)
        except Exception:
            payload = {}

        if self.path.startswith("/head"):
            # the mode, the endpoint, the model, the NAME of a key — or a key typed here,
            # which is written into the private home and never returned again
            try:
                mod = _rodd_head()
                mod.save(mode=payload.get("mode"), base_url=payload.get("base_url"),
                         model=payload.get("model"), key_name=payload.get("key_name"),
                         api_key=payload.get("api_key") or None)
            except SystemExit as exc:
                return self._json(200, {"ok": False, "detail": str(exc)})
            head = mod.resolve()
            head.pop("key", None)
            raised = _raise_host() if payload.get("apply", True) else {"ok": True, "detail": "saved, not raised"}
            return self._json(200, {"ok": raised["ok"], "head": head, "detail": raised["detail"]})

        if self.path.startswith("/settings"):
            current = _read_json(SETTINGS)
            merged = {**current, **{k: v for k, v in payload.items() if not str(k).startswith("_")}}
            _write_json(SETTINGS, merged)
            return self._json(200, {"ok": True, "settings": merged, "path": str(SETTINGS)})

        if self.path.startswith("/loss"):
            # ONE record per loss (plan 259 B2e rule 4): the id is the second the stream was lost,
            # and a loss already written is not written twice.
            lid = str(payload.get("id") or "").strip()
            if not lid:
                return self._json(200, {"ok": False, "detail": "a loss needs its id (the second it was lost)"})
            seen = set()
            try:
                for line in LOSSES.read_text(encoding="utf-8").splitlines():
                    seen.add(json.loads(line).get("id"))
            except Exception:
                pass
            if lid in seen:
                return self._json(200, {"ok": True, "duplicate": True})
            LOSSES.parent.mkdir(parents=True, exist_ok=True)
            row = {k: payload.get(k) for k in ("id", "what", "cause", "lost_at", "reopened_at", "attempts", "said")}
            with LOSSES.open("a", encoding="utf-8") as fh:
                fh.write(json.dumps(row, ensure_ascii=False) + "\n")
            os.chmod(LOSSES, 0o600)
            return self._json(200, {"ok": True})

        if self.path.startswith("/memory"):
            text = str(payload.get("text") or "").strip()
            if not text:
                return self._json(200, {"ok": False, "detail": "nothing to remember"})
            MEMORY.parent.mkdir(parents=True, exist_ok=True)
            with MEMORY.open("a", encoding="utf-8") as fh:
                fh.write(json.dumps({"at": payload.get("at") or "", "text": text}, ensure_ascii=False) + "\n")
            os.chmod(MEMORY, 0o600)
            return self._json(200, {"ok": True})

        if not self.path.startswith("/tool"):
            return self._json(404, {"error": "unknown path"})
        try:
            payload = payload if isinstance(payload, dict) else {}
            name = str(payload.get("name") or "").strip()
            args = payload.get("arguments") or {}
            if isinstance(args, str):
                args = json.loads(args or "{}")
            if not name:
                return self._json(400, {"error": "a tool name is required"})
            result = asyncio.run(voice_tools.execute_tool(name, args))
            out = getattr(result, "output", None)
            speaks = getattr(result, "create_response", None)
            if out is None and isinstance(result, dict):
                out, speaks = result.get("output"), result.get("create_response")
            return self._json(200, {"output": str(out if out is not None else result),
                                    "create_response": bool(speaks if speaks is not None else True)})
        except Exception as exc:  # a refused tool is a spoken refusal, never a silent 500
            return self._json(200, {"output": f"that door refused: {exc}", "create_response": True})

    def log_message(self, fmt: str, *a) -> None:  # quiet by design; the tools log themselves
        return


def main() -> None:
    ap = argparse.ArgumentParser(description="Rödd's hands for a browser face")
    ap.add_argument("--port", type=int, default=8891)
    ap.add_argument("--host", default="127.0.0.1")
    a = ap.parse_args()
    srv = ThreadingHTTPServer((a.host, a.port), Handler)
    # the address is printed for the operator's eyes only; it is built at run time and
    # never written into this file (RULES/39: this tree carries no addresses)
    print(f"rodd toolbox on {a.host}:{a.port} — {len(voice_tools.TOOLS)} tools", flush=True)
    srv.serve_forever()


if __name__ == "__main__":
    main()
