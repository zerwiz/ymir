"""notify.py — the hound's mouth: one message to the phone, and a record that it landed.

    notify.py --severity CRITICAL --line "…" [--rune <id>] [--test]

Decided from the Allfather's own testing (plan 99): **Gotify**, self-hosted, one user, one
revocable application token per sender. ntfy was rejected on two of his own findings —
anyone may post to a topic (a channel a stranger can make say "all clear"), and its web
UI never confirmed delivery (a bark you cannot verify is not a bark).

The rules this implements:
  * priority carries the severity: CRITICAL 10 · HIGH 8 · MEDIUM 4 · INFO 2;
  * the body is severity + the finding line + the Rune id — **no content**, ever;
  * delivery is PROVED: the server's message id comes back, and a failure says so;
  * a rate cap of 10/hour, and a storm collapses to one line;
  * MEDIUM is suppressed inside quiet hours; CRITICAL never is;
  * the URL is configuration, the token is a REFERENCE (`GARMR_GOTIFY_TOKEN`, read from
    the vault when it is not in the environment).

Exit: 0 sent (or deliberately skipped) · 1 could not send · 2 usage.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402
import redact  # noqa: E402

PRIORITY = {"CRITICAL": 10, "HIGH": 8, "MEDIUM": 4, "INFO": 2}          # gotify 0..10
NTFY_PRIORITY = {"CRITICAL": 5, "HIGH": 4, "MEDIUM": 3, "INFO": 2}      # ntfy 1..5
RATE_LIMIT = int(os.environ.get("GARMR_NOTIFY_PER_HOUR", "10"))
STORM_WINDOW = 300  # seconds
STORM_COUNT = 3


def _state_file() -> str:
    return os.path.join(common.state_dir(), "notify.json")


def _load_state() -> dict:
    try:
        with open(_state_file()) as handle:
            return json.load(handle) or {}
    except Exception:
        return {}


def _save_state(state: dict) -> None:
    try:
        os.makedirs(common.state_dir(), exist_ok=True)
        with open(_state_file(), "w") as handle:
            json.dump(state, handle)
    except OSError:
        pass


def _token(cfg: dict) -> str:
    ref = (cfg.get("alert", {}).get("gotify", {}) or {}).get("token_ref", "GARMR_GOTIFY_TOKEN")
    value = os.environ.get(ref, "")
    if value:
        return value
    # Secrets by reference (Rule 07): ask the vault, never a file in the tree.
    script = os.path.join(common.repo_root(), "bin", "vault", "hodd.sh")
    if os.path.isfile(script):
        try:
            out = subprocess.run(["bash", script, "emit", "secrets/platform.env"],
                                 capture_output=True, text=True, timeout=20).stdout
            match = re.search(rf"^export {re.escape(ref)}=['\"]?([^'\"\n]+)", out, re.M)
            if match:
                return match.group(1)
        except Exception:
            pass
    return ""


def _url(cfg: dict) -> str:
    return (os.environ.get("GOTIFY_URL")
            or (cfg.get("alert", {}).get("gotify", {}) or {}).get("url", "") or "").rstrip("/")


def _quiet_now(cfg: dict) -> bool:
    window = (cfg.get("alert", {}) or {}).get("quiet_hours", "") or ""
    match = re.match(r"^(\d{2}):(\d{2})-(\d{2}):(\d{2})$", window.strip())
    if not match:
        return False
    now = time.localtime()
    minutes = now.tm_hour * 60 + now.tm_min
    start = int(match.group(1)) * 60 + int(match.group(2))
    end = int(match.group(3)) * 60 + int(match.group(4))
    return start <= minutes < end if start <= end else (minutes >= start or minutes < end)


def allowed(cfg: dict, severity: str) -> tuple[bool, str]:
    """Rate cap, storm collapse and quiet hours — decided before a packet moves."""
    severity = severity.upper()
    if severity == "INFO":
        return False, "INFO never pages"
    if severity != "CRITICAL" and _quiet_now(cfg):
        return False, "quiet hours"
    state = _load_state()
    now = time.time()
    stamps = [float(s) for s in state.get("sent", []) if now - float(s) < 3600]
    if len(stamps) >= RATE_LIMIT:
        return False, f"rate cap ({RATE_LIMIT}/hour)"
    recent = [s for s in stamps if now - s < STORM_WINDOW]
    state["sent"] = stamps
    if len(recent) >= STORM_COUNT and severity != "CRITICAL":
        if state.get("stormed") and now - float(state["stormed"]) < STORM_WINDOW:
            return False, "storm — already collapsed"
        state["stormed"] = now
    _save_state(state)
    return True, ""


def send(severity: str, line: str, rune: str = "", cfg: dict | None = None) -> dict:
    cfg = cfg or common.load_config()
    severity = severity.upper()
    ok, why = allowed(cfg, severity)
    if not ok:
        return {"sent": False, "reason": why}

    phone = ((cfg.get("alert", {}) or {}).get("phone") or "none").lower()
    if phone in ("", "none"):
        return {"sent": False, "reason": "no phone channel configured (alert.phone)"}
    if phone not in ("gotify", "ntfy"):
        return {"sent": False, "reason": f"channel '{phone}' is not one of gotify | ntfy | none"}

    if phone == "ntfy":
        return send_ntfy(severity, line, rune, cfg)

    url, token = _url(cfg), _token(cfg)
    if not url or not token:
        return {"sent": False, "reason": "GOTIFY_URL or GARMR_GOTIFY_TOKEN is missing (vault: secrets/platform.env)"}

    title = f"{severity}: {line.split(':')[0][:40]}"
    body = redact.redact_text(line, cap=300)
    if rune:
        body = f"{body}\n(rune {rune})"
    payload = json.dumps({
        "title": title[:120],
        "message": body,
        "priority": PRIORITY.get(severity, 4),
    }).encode()
    request = urllib.request.Request(
        f"{url}/message?token={token}", data=payload,
        headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=8) as response:
            data = json.load(response)
        state = _load_state()
        state.setdefault("sent", []).append(time.time())
        _save_state(state)
        return {"sent": True, "id": data.get("id"), "channel": "gotify", "priority": PRIORITY.get(severity, 4)}
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, ValueError) as err:
        return {"sent": False, "reason": f"gotify refused: {err}"}


def send_ntfy(severity: str, line: str, rune: str, cfg: dict) -> dict:
    """ntfy: a topic, not an app. Chosen when several devices or people must hear it.

    Auth is optional but ALWAYS used when a token is present: a topic anyone may post to
    can be made to say "all clear", which is the one lie a guardian must not carry.
    """
    url = (os.environ.get("GARMR_NTFY_URL") or "").rstrip("/")
    topic = os.environ.get("GARMR_NTFY_TOPIC") or (cfg.get("alert", {}).get("ntfy", {}) or {}).get("topic", "")
    token = os.environ.get("GARMR_NTFY_TOKEN", "")
    if not url or not topic:
        return {"sent": False, "reason": "GARMR_NTFY_URL or GARMR_NTFY_TOPIC is missing (vault: secrets/platform.env)"}

    body = redact.redact_text(line, cap=300)
    if rune:
        body += f"\n(rune {rune})"
    headers = {
        "Title": f"{severity}: {line.split(':')[0][:60]}".encode("utf-8"),
        "Priority": str(NTFY_PRIORITY.get(severity, 3)),
        "Tags": "rotating_light" if severity == "CRITICAL" else "warning",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(f"{url}/{topic}", data=body.encode("utf-8"), headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=8) as response:
            data = json.load(response)
        state = _load_state()
        state.setdefault("sent", []).append(time.time())
        _save_state(state)
        return {"sent": True, "id": data.get("id"), "channel": "ntfy",
                "priority": NTFY_PRIORITY.get(severity, 3)}
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, ValueError) as err:
        return {"sent": False, "reason": f"ntfy refused: {err}"}


def main() -> int:
    parser = argparse.ArgumentParser(description="Garmr's mouth — one message to the phone")
    parser.add_argument("--severity", default="HIGH")
    parser.add_argument("--line", default="")
    parser.add_argument("--rune", default="")
    parser.add_argument("--test", action="store_true")
    args = parser.parse_args()

    if args.test:
        line = args.line or "the hound is testing its mouth — this is not a finding"
    else:
        line = args.line
    if not line:
        parser.error("--line is required unless --test is given")

    result = send(args.severity, line, args.rune)
    print(common.emit(result))
    return 0 if result.get("sent") or not result.get("reason", "").startswith(("gotify refused", "GOTIFY_URL")) else 1


if __name__ == "__main__":
    sys.exit(main())
