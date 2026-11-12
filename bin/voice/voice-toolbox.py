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


_MODELS_CACHE: dict = {"at": 0.0, "data": None}


def _models() -> dict:
    """Every provider and model this user can already reach, from the house's ONE model door (Bilskirnir's
    detector: pi's and OpenCode's providers, the home's added ones, and local servers on their usual ports),
    filtered by the operator's allow-list. Keys are never returned: only the NAME of where a key lives
    (plan 275, 2026-11-12 — "the app search for local models and list them in drop down")."""
    import time
    if _MODELS_CACHE["data"] is not None and time.time() - _MODELS_CACHE["at"] < 60:
        return _MODELS_CACHE["data"]
    det = REPO / "apps" / "bilskirnir" / "server" / "src" / "models" / "detect.ts"
    out = {"providers": []}
    try:
        r = subprocess.run(["node", str(det), "--json"], capture_output=True, text=True, timeout=60)
        d = json.loads(r.stdout or "{}")
    except Exception as exc:
        return {"providers": [], "error": f"the model door did not answer: {exc}"}
    for prov in d.get("providers", []):
        allowed = [m["id"] for m in prov.get("models", []) if m.get("allowed")]
        if not allowed or prov.get("status") not in ("ok", "from-config"):
            continue
        where = str(prov.get("key") or "")
        key_name = f"pi:{prov['id']}" if ".pi/agent/auth.json" in where else ""
        out["providers"].append({
            "id": prov["id"], "name": prov.get("name") or prov["id"], "local": bool(prov.get("local")),
            "base_url": prov.get("baseUrl", ""), "key_name": key_name, "has_key": bool(prov.get("hasKey")),
            "models": allowed,
        })
    # this machine's own servers first, then the rest
    out["providers"].sort(key=lambda x: (not x["local"], x["name"].lower()))
    _MODELS_CACHE.update(at=time.time(), data=out)
    return out


def _provider_door(args: list[str], stdin: str = "") -> dict:
    """The house's ONE provider door (Bilskirnir's choose.ts), run through its own tsx. A key goes in on
    standard input, never as an argument, and the answer names where it was kept, never the key."""
    app = REPO / "apps" / "bilskirnir"
    tsx = app / "node_modules" / ".bin" / "tsx"
    if not tsx.exists():
        return {"ok": False, "detail": "the provider door is not installed here (apps/bilskirnir has no dependencies yet)"}
    try:
        r = subprocess.run([str(tsx), str(app / "server" / "src" / "models" / "choose.ts"), *args],
                           input=stdin, capture_output=True, text=True, timeout=60, cwd=str(app))
        return json.loads((r.stdout or "").strip().splitlines()[-1])
    except Exception as exc:
        return {"ok": False, "detail": f"the provider door did not answer: {str(exc)[:160]}"}


_PRESETS_CACHE: dict = {"at": 0.0, "data": None}


def _presets() -> dict:
    import time
    if _PRESETS_CACHE["data"] is not None and time.time() - _PRESETS_CACHE["at"] < 3600:
        return _PRESETS_CACHE["data"]
    d = _provider_door(["--presets"])
    if "presets" in d:
        _PRESETS_CACHE.update(at=time.time(), data=d)
    return d


def _try_mind(base_url: str, model: str, key: str) -> tuple[bool, str]:
    """One word to the chosen mind before it is saved: a mind that does not answer is never written."""
    import urllib.request
    body = json.dumps({"model": model, "messages": [{"role": "user", "content": "Say ok"}], "max_tokens": 2}).encode()
    req = urllib.request.Request(base_url.rstrip("/") + "/chat/completions", data=body,
                                 headers={"Content-Type": "application/json", **({"Authorization": f"Bearer {key}"} if key else {})})
    try:
        with urllib.request.urlopen(req, timeout=90) as resp:
            ok = resp.status == 200 and b"choices" in resp.read()
            return ok, "answered" if ok else f"HTTP {resp.status}"
    except Exception as exc:
        return False, str(exc)[:160]


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
        if self.path.startswith("/head/models"):
            return self._json(200, _models())
        if self.path.startswith("/head/presets"):
            return self._json(200, _presets())
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
        return self._json(404, {"error": "unknown path", "paths": ["/tools", "/tool", "/head", "/head/models", "/head/presets", "/head/provider", "/settings", "/memory", "/health", "/desk", "/loss"]})

    def do_POST(self) -> None:  # noqa: N802
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) or b"{}"
        try:
            payload = json.loads(raw)
        except Exception:
            payload = {}

        if self.path.startswith("/session"):
            # one press of the orb is one session; the window hands it over when it ends (plan 275)
            try:
                return self._json(200, voice_tools.save_session(payload))
            except Exception as exc:
                return self._json(200, {"ok": False, "detail": str(exc)[:200]})

        if self.path.startswith("/head/provider"):
            # add a provider with a key pasted once: kept in the private home, tested by the door's own detection
            args = ["--add"]
            if payload.get("preset"):
                args += ["--preset", str(payload["preset"])]
            if payload.get("name"):
                args += ["--name", str(payload["name"])]
            if payload.get("base_url"):
                args += ["--base-url", str(payload["base_url"])]
            key = str(payload.get("api_key") or "").strip()
            if key:
                args.append("--key-stdin")
            out = _provider_door(args, stdin=key)
            _MODELS_CACHE.update(at=0.0, data=None)          # the new provider shows at once
            if out.get("ok"):
                prov_id = (out.get("provider") or {}).get("id", "")
                found = next((x for x in _models().get("providers", []) if x["id"] == prov_id), None)
                out["models"] = len(found["models"]) if found else 0
                out["detail"] = (f"{(out.get('provider') or {}).get('name', prov_id)} added — key kept in {out.get('keyStoredIn') or 'the place it already was'}; "
                                 + (f"{out['models']} models you may choose" if found else "it did not answer with models yet (check the key, or the allow-list)"))
            return self._json(200, out)

        if self.path.startswith("/head"):
            # the mode, the endpoint, the model, the NAME of a key — or a key typed here,
            # which is written into the private home and never returned again
            # the simple road: a provider and a model chosen from the lists the model door found
            if payload.get("provider"):
                prov = next((x for x in _models().get("providers", []) if x["id"] == payload["provider"]), None)
                model_id = str(payload.get("model") or "").strip()
                if not prov or model_id not in prov["models"]:
                    return self._json(200, {"ok": False, "detail": "that provider and model are not on this machine's list"})
                mod = _rodd_head()
                key = mod._vault_key(prov["key_name"]) if prov["key_name"] else ""
                # a local mind is asked one word first; an online gateway may need headers only the engine's proxy adds
                if prov["local"]:
                    ok, why = _try_mind(prov["base_url"], model_id, key)
                    if not ok:
                        return self._json(200, {"ok": False, "detail": f"{model_id} did not answer ({why}) — nothing was saved"})
                try:
                    mod.save(mode="local" if prov["local"] else "online", base_url=prov["base_url"], model=model_id,
                             key_name=prov["key_name"], client="opencode" if prov["id"].startswith("opencode") else "plain")
                except SystemExit as exc:
                    return self._json(200, {"ok": False, "detail": str(exc)})
                head = mod.resolve(); head.pop("key", None)
                raised = _raise_host() if payload.get("apply", True) else {"ok": True, "detail": "saved, not raised"}
                return self._json(200, {"ok": raised["ok"], "head": head, "detail": raised["detail"]})
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
