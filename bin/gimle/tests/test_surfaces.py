#!/usr/bin/env python3
"""test_surfaces.py — the surfaces come from the operator's home, and a missing one is said, never invented.

WHY (2026-11-20). The public tree carried the operator's domain literally in code, in an example env file and in
test fixtures. The one registry of his surfaces already existed (`<home>/hodd/identity/services.yaml`, one
`public_url` per service, written by the operator and read by the tunnel round); this door is the reader. The
proofs are: a declared service answers; a service that declares nothing is exit 3 and names it; no registry at all
is exit 2; and nothing in the answer is spelled by the code.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile

_HERE = os.path.dirname(os.path.abspath(__file__))                      # <repo>/bin/gimle/tests
DOOR = os.path.join(os.path.dirname(_HERE), "surfaces.py")             # <repo>/bin/gimle/surfaces.py
passed = failed = 0


def ok(name: str, _detail: str = "") -> None:
    global passed
    passed += 1
    print(f"  ok   {name}")


def bad(name: str, detail: str = "") -> None:
    global failed
    failed += 1
    print(f"  FAIL {name}")
    if detail:
        print(f"        {detail}")


def run(*args: str, env: dict | None = None) -> tuple[int, str, str]:
    e = dict(os.environ)
    e.pop("YMIR_HOME", None)
    e.update(env or {})
    p = subprocess.run([sys.executable, DOOR, *args], capture_output=True, text=True, env=e, timeout=60)
    return p.returncode, p.stdout.strip(), p.stderr.strip()


with tempfile.TemporaryDirectory() as t:
    reg = os.path.join(t, "services.yaml")
    with open(reg, "w", encoding="utf-8") as fh:
        fh.write(
            "services:\n"
            "  - id: board\n    public_url: https://board.example.org\n"
            "  - id: homepage\n    public_url: null\n"
            "  - id: desk\n    public_url: https://desk.example.org/\n"
        )
    env = {"YMIR_SERVICES_REGISTRY": reg}

    rc, out, _ = run("--get", "board", env=env)
    (ok if rc == 0 and out == "https://board.example.org" else bad)("a declared service answers with its url", f"rc={rc} out={out}")

    rc, out, _ = run("--get", "desk", env=env)
    (ok if rc == 0 and out == "https://desk.example.org" else bad)("a trailing slash is trimmed, so callers join safely", f"rc={rc} out={out}")

    rc, out, err = run("--get", "homepage", env=env)
    (ok if rc == 3 and "declares no public_url" in err else bad)("a service that declares nothing is exit 3 and is named", f"rc={rc} err={err}")

    rc, out, err = run("--get", "not-a-service", env=env)
    (ok if rc == 3 else bad)("an unknown service is exit 3, never a guess", f"rc={rc} err={err}")

    rc, out, _ = run("--list", env=env)
    (ok if rc == 0 and out.splitlines() == ["board\thttps://board.example.org", "desk\thttps://desk.example.org"] else bad)(
        "the list carries every declared surface and no empty one", f"rc={rc} out={out!r}")

    rc, out, _ = run("--json", env=env)
    try:
        parsed = json.loads(out or "{}")
    except Exception:
        parsed = {}
    (ok if rc == 0 and parsed.get("board") == "https://board.example.org" else bad)("the json map answers a program", f"rc={rc} out={out}")

    rc, _, err = run("--get", "board", env={"YMIR_SERVICES_REGISTRY": os.path.join(t, "missing.yaml")})
    (ok if rc == 2 and "no registry" in err else bad)("no registry at all is exit 2, not an empty answer", f"rc={rc} err={err}")

print(f"surfaces: {passed} passed, {failed} failed")
sys.exit(0 if failed == 0 else 1)
