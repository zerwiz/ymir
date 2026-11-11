#!/usr/bin/env python3
"""rodd-head.py — whose mind answers in Rödd's window, and where that key lives.

Rödd is the app. The head is the model Nanna thinks with, and it is chosen when her
host is raised — the realtime engine carries no per-session model switch (its
`session.update` logs `model` and rebuilds nothing), so a different head means a
different `speech-to-speech serve` command.

This is the one door for that answer. Both the host (`bin/voice/voice-door.sh`) and
the window's settings (`bin/voice/voice-toolbox.py`) read it, so a switch made in the
panel and a start made in a shell cannot disagree.

WHERE VALUES LIVE — the law, not a preference:

    repository   apps/rodd/config/rodd.env.example    the SHAPE, no secret
    home         $YMIR_HOME/hodd/secrets/rodd.env     the VALUES, mode 0600

Never the other way round. A key is either **named** (its value read from the house's
vault by name) or **typed** into Rödd's settings, which writes it to the home's secrets
file. It is never returned to the window, never logged, and never written into this
tree — `save()` refuses a destination inside the repository.

    rodd-head.py resolve       what would answer now (no secret is printed)
    rodd-head.py env           shell assignments for the door; the key only with --with-key
    rodd-head.py set --mode …  [--base-url …] [--model …] [--key-name …] [--api-key …]
    rodd-head.py status        one line for a person

Exit: 0 ok · 1 refused/unavailable · 2 usage.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
TEMPLATE = REPO / "apps" / "rodd" / "config" / "rodd.env.example"
HOME = Path(os.environ.get("YMIR_HOME") or (Path.home() / "Documents" / "ymirhome"))
SECRETS = HOME / "hodd" / "secrets" / "rodd.env"

SECRET_KEYS = ("RODD_HEAD_API_KEY",)


def _parse(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.is_file():
        return out
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        out[k.strip()] = v.strip()
    return out


def _pi_key(provider: str) -> str:
    """A key the seat already holds for a pi provider (`pi:opencode-go`) — still by
    reference: the value is read from the seat's own store, never copied into a file
    this door writes, and never printed."""
    try:
        data = json.loads((Path.home() / ".pi" / "agent" / "auth.json").read_text(encoding="utf-8"))
    except Exception:
        return ""
    entry = data.get(provider)
    if isinstance(entry, dict):
        return str(entry.get("key") or entry.get("apiKey") or "")
    return ""


def _vault_key(name: str) -> str:
    """The value of a key NAME — from the house's vault, or from the seat's pi store
    when the name is written `pi:<provider>`. By reference, never by guess."""
    if not name:
        return ""
    if name.startswith("pi:"):
        return _pi_key(name[3:])
    for door in (REPO / "bin" / "vault" / "hodd.sh",):
        if not door.is_file():
            continue
        try:
            out = subprocess.run(["bash", str(door), "emit", "secrets/platform.env"],
                                 capture_output=True, text=True, timeout=20)
        except Exception:
            continue
        if out.returncode != 0:
            continue
        for line in out.stdout.splitlines():
            line = line.strip()
            if line.startswith("export "):
                line = line[len("export "):]
            if line.startswith(name + "="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    return ""


def resolve() -> dict[str, str]:
    """mode · base_url · model · key · key_name · key_state · source (no secret printed)."""
    tmpl = _parse(TEMPLATE)
    home = _parse(SECRETS)

    def pick(key: str, default: str = "") -> str:
        return os.environ.get(key) or home.get(key) or tmpl.get(key) or default

    mode = (os.environ.get("RODD_HEAD_MODE") or home.get("RODD_HEAD_MODE")
            or tmpl.get("RODD_HEAD_MODE") or "local").strip().lower()
    if mode not in ("local", "online"):
        mode = "local"

    up = "RODD_HEAD_LOCAL_" if mode == "local" else "RODD_HEAD_ONLINE_"
    base_url = pick(up + "BASE_URL")
    model = pick(up + "MODEL")
    key_name = pick(up + "KEY_NAME")
    client = (pick(up + "CLIENT", "plain") or "plain").strip().lower()

    typed = os.environ.get("RODD_HEAD_API_KEY") if (os.environ.get("RODD_HEAD_MODE") or "").strip().lower() == mode else ""
    if not typed:
        typed = home.get("RODD_HEAD_API_KEY", "") if home.get("RODD_HEAD_MODE", "local") == mode else ""
    key = typed or _vault_key(key_name)

    if typed:
        key_state = f"typed · ends {typed[-4:]}" if len(typed) >= 8 else "typed"
    elif key:
        key_state = f"vault:{key_name}"
    else:
        key_state = "none"

    return {
        "mode": mode,
        "base_url": base_url,
        "model": model,
        "key": key,
        "key_name": key_name,
        "key_state": key_state,
        "client": client,
        "source": "env" if os.environ.get(up + "MODEL") else ("home" if home else "template"),
    }


def _inside_repo(path: Path) -> bool:
    try:
        path.resolve().relative_to(REPO.resolve())
        return True
    except ValueError:
        return False


def save(mode: str | None = None, base_url: str | None = None, model: str | None = None,
         key_name: str | None = None, api_key: str | None = None,
         client: str | None = None) -> dict[str, str]:
    """Write the home's secrets file. The repo is refused by name, not by accident."""
    if _inside_repo(SECRETS):
        raise SystemExit("refused: the key store resolved inside the repository — "
                         "set YMIR_HOME to the private home")
    current = _parse(SECRETS)
    if mode is not None:
        if mode not in ("local", "online"):
            raise SystemExit(f"refused: mode must be local or online, not {mode!r}")
        current["RODD_HEAD_MODE"] = mode
    target_mode = (mode or current.get("RODD_HEAD_MODE") or "local").lower()
    up = "RODD_HEAD_LOCAL_" if target_mode == "local" else "RODD_HEAD_ONLINE_"
    if base_url is not None:
        current[up + "BASE_URL"] = base_url.strip()
    if model is not None:
        current[up + "MODEL"] = model.strip()
    if key_name is not None:
        current[up + "KEY_NAME"] = key_name.strip()
    if client is not None:
        current[up + "CLIENT"] = client.strip() or "plain"
    if api_key:
        current["RODD_HEAD_API_KEY"] = api_key.strip()

    SECRETS.parent.mkdir(parents=True, exist_ok=True)
    body = ["# written by bin/voice/rodd-head.py — this file is private, 0600, never in the repo", ""]
    for k in sorted(current):
        body.append(f"{k}={current[k]}")
    SECRETS.write_text("\n".join(body) + "\n", encoding="utf-8")
    os.chmod(SECRETS, 0o600)
    return resolve()


def main() -> int:
    ap = argparse.ArgumentParser(description="whose mind answers in Rödd's window")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("resolve")
    p_env = sub.add_parser("env")
    p_env.add_argument("--with-key", action="store_true")
    sub.add_parser("status")
    p_set = sub.add_parser("set")
    p_set.add_argument("--mode")
    p_set.add_argument("--base-url")
    p_set.add_argument("--model")
    p_set.add_argument("--key-name")
    p_set.add_argument("--api-key")
    p_set.add_argument("--client")
    a = ap.parse_args()

    if a.cmd == "set":
        r = save(a.mode, a.base_url, a.model, a.key_name, a.api_key, a.client)
    else:
        r = resolve()

    if a.cmd == "resolve":
        for k in ("mode", "base_url", "model", "client", "key_name", "key_state", "source"):
            print(f"{k}={r[k]}")
        return 0 if r["model"] else 1

    if a.cmd == "env":
        # shell assignments for the door. The key travels only when asked for by name.
        print(f'RODD_HEAD_MODE={r["mode"]}')
        print(f'RODD_VOICE_HEAD_URL={r["base_url"]}')
        print(f'RODD_VOICE_HEAD_MODEL={r["model"]}')
        print(f'RODD_HEAD_ONLINE_CLIENT={r["client"]}')
        if a.with_key and r["key"]:
            print(f'RODD_VOICE_HEAD_API_KEY={r["key"]}')
        return 0 if r["model"] else 1

    if a.cmd == "status":
        print(f'{r["mode"]} · {r["model"] or "NO MODEL NAMED"} · {r["base_url"] or "no base url"} · '
              f'client {r["client"]} · key {r["key_state"]}')
        return 0 if r["model"] else 1

    # set
    print(f'saved · {r["mode"]} · {r["model"] or "NO MODEL NAMED"} · key {r["key_state"]}')
    return 0


if __name__ == "__main__":
    sys.exit(main())
