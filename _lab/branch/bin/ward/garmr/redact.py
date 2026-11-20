"""redact.py — the guardian's own ward (plan 98 §6, §'the redaction rule').

The hound is asked to reason about a breach, so it must see the SHAPE of what
happened: the process, the command, the peer, the time. That is exactly the
material that carries credentials. So nothing leaves this module unredacted.

Rules (each has a test in .agents/tests/garmr.test.sh):
  * a value following a secret-ish flag is replaced            --token=…  --password …  -H "Authorization: …"
  * a secret-ish KEY=VALUE assignment is replaced              GITHUB_TOKEN=…  api_key=…
  * a token in a URL is replaced                               ?access_token=…  &sig=…
  * well-known token shapes are replaced                       sk-…  ghp_…  xoxb-…  AKIA…
  * a long opaque run (>=32 chars, base64ish) is replaced      a pasted key with no label
  * a path that names a sensitive shelf is HASHED, never sent  hodd/data/snotra/…  hodd/evidence/…
  * everything is capped in length                             a payload is a timeline, not a copy

A failure here is a CRITICAL of the guardian itself, which is why the tests are
part of the gate rather than an afterthought.
"""
from __future__ import annotations

import hashlib
import os
import re

SECRET_FLAG = re.compile(
    r"(?i)(token|secret|password|passwd|bearer|authorization|api[-_]?key|access[-_]?key|"
    r"private[-_]?key|client[-_]?secret|sig|signature|credential|cookie|session)"
)
ASSIGNMENT = re.compile(
    r"(?i)\b([a-z0-9_\-]*(?:token|secret|password|passwd|api[-_]?key|access[-_]?key|"
    r"private[-_]?key|client[-_]?secret|credential)[a-z0-9_\-]*)\s*[:=]\s*([^\s,;'\"]+)"
)
URL_PARAM = re.compile(r"(?i)([?&](?:access_token|token|key|api_key|sig|signature|password)=)([^&\s]+)")
TOKEN_SHAPES = re.compile(
    r"\b(sk-[A-Za-z0-9_\-]{8,}|ghp_[A-Za-z0-9]{16,}|gho_[A-Za-z0-9]{16,}|xox[baprs]-[A-Za-z0-9\-]{8,}|"
    r"AKIA[0-9A-Z]{12,}|eyJ[A-Za-z0-9_\-]{16,}\.[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}|"
    r"[A-Za-z0-9+/=_\-]{32,})\b"
)
BEARER_HEADER = re.compile(r"(?i)(bearer\s+)([^\s\"']+)")

SENSITIVE_MARKERS = (
    "hodd/data/snotra",
    "hodd/evidence",
    "hodd/life/meetings",
    "hodd/memory/snotra",
    "hodd/secrets",
    "hnitbjorg",
    "/vault/",
    "kaia.engram",
    "platform.env",
)

MAX_TEXT = 400


def is_sensitive(path: str, markers: tuple[str, ...] = SENSITIVE_MARKERS) -> bool:
    lowered = (path or "").lower()
    home = os.path.expanduser("~").lower()
    if home and home in lowered:
        lowered = lowered.replace(home, "~")
    return any(marker in lowered for marker in markers)


def hash_path(path: str) -> str:
    return hashlib.sha256((path or "").encode("utf8")).hexdigest()[:12]


def redact_text(text: str, cap: int = MAX_TEXT) -> str:
    if not text:
        return ""
    out = BEARER_HEADER.sub(lambda m: m.group(1) + "<redacted:%d>" % len(m.group(2)), text)
    out = URL_PARAM.sub(lambda m: m.group(1) + "<redacted:%d>" % len(m.group(2)), out)
    out = ASSIGNMENT.sub(lambda m: f"{m.group(1)}=<redacted:{len(m.group(2))}>", out)
    out = TOKEN_SHAPES.sub(lambda m: "<redacted:%d>" % len(m.group(1)), out)
    if len(out) > cap:
        out = out[:cap] + f"…(+{len(out) - cap})"
    return out


def redact_argv(argv: list[str] | None) -> list[str]:
    """Redact an argv, keeping the shape: a flag survives, its secret does not."""
    if not argv:
        return []
    out: list[str] = []
    expect_secret = False
    for token in argv:
        if expect_secret:
            out.append("<redacted:%d>" % len(token))
            expect_secret = False
            continue
        if token.startswith("-") and SECRET_FLAG.search(token.split("=", 1)[0]):
            if "=" in token:
                flag, _, value = token.partition("=")
                out.append(f"{flag}=<redacted:{len(value)}>")
            else:
                out.append(token)
                expect_secret = True
            continue
        cleaned = redact_text(token, cap=200)
        # a path inside an argv is a path too: hash it if it names a sensitive shelf
        if is_sensitive(cleaned):
            cleaned = f"<sensitive:{hash_path(cleaned)}>"
        out.append(cleaned)
    return out


def redact_path(path: str) -> str:
    """A path that names a sensitive shelf travels as a hash; anything else as text."""
    if not path:
        return ""
    return f"<sensitive:{hash_path(path)}>" if is_sensitive(path) else redact_text(path, cap=200)
