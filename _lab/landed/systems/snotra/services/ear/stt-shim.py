#!/usr/bin/env python3
"""stt-shim.py — the missing contract: OpenAI-compatible `/v1/audio/transcriptions` in front of our whisper.

    python3 stt-shim.py [--host 0.0.0.0] [--port 10301] [--whisper http://127.0.0.1:10300/inference]

WHY THIS EXISTS (2026-10-23). The meeting bot transcribes against `TRANSCRIPTION_SERVICE_URL` and the
client appends `/v1/audio/transcriptions` (the meeting stack's own config says so). Our whisper.cpp
server answers only `/inference`, so the bot could record and never transcribe — the "far side" was
mute. This shim is that one missing path and nothing else:

  POST /v1/audio/transcriptions   multipart (file, model, optional language) → {"text": "…"}
  GET  /health                    {"status": "ok"} — the stack probes it before every spawn

It forwards the audio to whisper.cpp's `/inference`, returns the JSON the OpenAI contract expects, and
keeps no copy of anything. Binds 0.0.0.0 by default so a container can reach it through the docker
host gateway; it holds no credential and reveals nothing but the transcript it was asked for.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.request
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

WHISPER = "http://127.0.0.1:10300/inference"


def multipart_file(body: bytes, content_type: str) -> tuple[bytes, str, dict]:
    """Pull the first file part and the text fields out of a multipart body. No dependency, no surprise."""
    m = re.search(r"boundary=\"?([^\";]+)\"?", content_type or "")
    if not m:
        return b"", "", {}
    boundary = b"--" + m.group(1).encode()
    filename, payload, fields = "", b"", {}
    for part in body.split(boundary):
        if b"\r\n\r\n" not in part:
            continue
        head, value = part.split(b"\r\n\r\n", 1)
        value = value.rstrip(b"\r\n-")
        name_m = re.search(rb'name="([^"]+)"', head)
        file_m = re.search(rb'filename="([^"]*)"', head)
        name = name_m.group(1).decode() if name_m else ""
        if file_m:
            filename = file_m.group(1).decode() or name
            payload = value
        elif name:
            fields[name] = value.decode("utf-8", "replace")
    return payload, filename, fields


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):  # quiet: the stack polls /health constantly
        pass

    def _json(self, code: int, payload: dict) -> None:
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.rstrip("/") in ("/health", "/v1/health", ""):
            return self._json(200, {"status": "ok", "backend": WHISPER})
        return self._json(404, {"error": {"message": "not found"}})

    def do_POST(self):
        if not self.path.startswith("/v1/audio/transcriptions"):
            return self._json(404, {"error": {"message": "not found"}})
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else b""
        audio, filename, fields = multipart_file(body, self.headers.get("Content-Type", ""))
        if not audio:
            return self._json(400, {"error": {"message": "no audio file in the request"}})
        # whisper.cpp wants 16 kHz mono PCM; the bot sends webm/opus chunks, so decode at the door.
        audio16 = audio
        tmp = tempfile.NamedTemporaryFile(suffix=".bin", delete=False)
        try:
            tmp.write(audio); tmp.close()
            out = tmp.name + ".wav"
            conv = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                                   "-i", tmp.name, "-ar", "16000", "-ac", "1", out],
                                  capture_output=True)
            if conv.returncode == 0 and os.path.exists(out) and os.path.getsize(out) > 44:
                audio16 = open(out, "rb").read()
            os.unlink(out) if os.path.exists(out) else None
        except Exception:
            pass
        finally:
            try:
                os.unlink(tmp.name)
            except OSError:
                pass
        audio = audio16
        boundary = uuid.uuid4().hex
        parts = []
        parts.append(f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; "
                     f"filename=\"{filename or 'audio.wav'}\"\r\nContent-Type: application/octet-stream\r\n\r\n".encode())
        parts.append(audio)
        for name, value in (("response_format", "json"), ("temperature", "0")):
            parts.append(f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"\r\n\r\n{value}".encode())
        parts.append(f"\r\n--{boundary}--\r\n".encode())
        payload = b"".join(parts)
        req = urllib.request.Request(WHISPER, data=payload, headers={
            "Content-Type": f"multipart/form-data; boundary={boundary}"})
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                data = json.load(r)
        except Exception as exc:
            return self._json(502, {"error": {"message": f"whisper backend: {type(exc).__name__}: {exc}"}})
        text = (data.get("text") or "").strip()
        return self._json(200, {"text": text})


def main() -> int:
    global WHISPER
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="0.0.0.0")
    ap.add_argument("--port", type=int, default=10301)
    ap.add_argument("--whisper", default=WHISPER)
    a = ap.parse_args()
    WHISPER = a.whisper
    srv = ThreadingHTTPServer((a.host, a.port), Handler)
    print(f"stt-shim: http://{a.host}:{a.port}/v1/audio/transcriptions → {WHISPER}", flush=True)
    srv.serve_forever()
    return 0


if __name__ == "__main__":
    sys.exit(main())
