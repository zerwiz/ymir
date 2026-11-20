"""kokoro_url.py — the Python face of bin/voice/kokoro-lib.sh (plan 326.0, Rule 07).

Where the Kokoro engine listens is ONE value, KOKORO_SERVICE_URL, resolved by kokoro-lib.sh (environment →
$YMIR_HOME/config/voice.env → the engine's own default). This module asks that resolver rather than keeping a
second default, so a Python client and the unit can never disagree. An explicit KOKORO_URL still overrides,
as it always did; it may name the base or the full speech endpoint.

    import kokoro_url
    kokoro_url.base()    # http://127.0.0.1:<port>
    kokoro_url.speech()  # .../v1/audio/speech
    kokoro_url.port()    # <port>
"""
from __future__ import annotations

import os
import subprocess
from pathlib import Path
from urllib.parse import urlparse

_LIB = Path(__file__).resolve().with_name("kokoro-lib.sh")
_SPEECH = "/v1/audio/speech"


def _ask(verb: str) -> str:
    out = subprocess.run(["bash", str(_LIB), verb], capture_output=True, text=True, timeout=10)
    if out.returncode != 0 or not out.stdout.strip():
        raise RuntimeError(f"kokoro-lib.sh {verb} failed: {out.stderr.strip()[:200]}")
    return out.stdout.strip()


def base() -> str:
    explicit = os.environ.get("KOKORO_URL", "").strip()
    if explicit:
        explicit = explicit.rstrip("/")
        return explicit[: -len(_SPEECH)] if explicit.endswith(_SPEECH) else explicit
    return _ask("base")


def speech() -> str:
    return base() + _SPEECH


def port() -> int:
    parsed = urlparse(base())
    if not parsed.port:
        raise RuntimeError(f"the Kokoro URL names no port: {base()}")
    return parsed.port
