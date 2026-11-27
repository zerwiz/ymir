#!/usr/bin/env python3
"""herdr as a backend — the first one, and the shape the second is measured against."""
import json
import os
import subprocess

from base import Backend, BLOCKED, DEAD, READY, WORKING


def herdr_path():
    return os.environ.get("HDR_BIN") or os.environ.get("HDR") or "herdr"


def _run(*args, timeout=40):
    try:
        p = subprocess.run([herdr_path()] + list(args), capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return (p.stdout or p.stderr or "").strip()


def _json(raw):
    try:
        return json.loads(raw)
    except Exception:  # noqa: BLE001
        return {}


def stamped(text):
    """The road back (plan 381): the shell stamper names the sender and pane; a stamped line is left as it is."""
    door = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "agents", "msg-origin.sh")
    try:
        r = subprocess.run(["bash", door, text], capture_output=True, text=True, timeout=30, stdin=subprocess.DEVNULL)
    except (OSError, subprocess.TimeoutExpired):
        return text
    return r.stdout.rstrip("\n") if r.returncode == 0 and r.stdout.startswith("[") else text


class Herdr(Backend):
    name = "herdr"

    def resolve(self, name):
        return name[6:] if name.startswith("herdr:") else name

    def list(self):
        rows = []
        for a in ((_json(_run("agent", "list")).get("result") or {}).get("agents") or []):
            pane = a.get("pane_id") or ""
            if not pane:
                continue
            state, reason, _ = self.get(pane)
            rows.append({"name": a.get("name") or a.get("terminal_title_stripped") or a.get("agent") or "?",
                         "harness": a.get("agent") or "?", "target": "herdr:%s" % pane,
                         "pane": pane, "state": state, "reason": reason})
        return rows

    def get(self, target):
        pane = self.resolve(target)
        row = _json(_run("agent", "get", pane))
        err = row.get("error") or {}
        if err.get("code") in ("agent_not_found", "pane_not_found"):
            return DEAD, "", "no agent in %s" % pane
        a = ((row.get("result") or {}).get("agent") or {})
        if not a:
            return BLOCKED, "herdr answered no agent", ""
        status = (a.get("agent_status") or "").strip().lower()
        ready_flag = a.get("interactive_ready")
        if status == "working":
            return WORKING, "", "agent=%s" % (a.get("agent") or "?")
        if status == "done":
            if ready_flag is False:
                return BLOCKED, "not at an input prompt", ""
            return READY, "", "agent=%s" % (a.get("agent") or "?")
        if status == "blocked":
            reason, _rec, _d = self.explain(pane)
            return BLOCKED, reason, ""
        if ready_flag is False:
            return BLOCKED, "not at an input prompt", ""
        return READY, "", "agent=%s" % (a.get("agent") or "?")

    def read(self, target, lines=40):
        return _run("agent", "read", self.resolve(target), "--lines", str(lines))

    def prompt(self, target, text):
        pane = self.resolve(target)
        text = stamped(text)
        out = _run("agent", "prompt", pane, text, timeout=90)
        if '"agent_prompted"' in out:
            return "agent prompt"
        out = _run("agent", "send", pane, text, timeout=90)
        if out and '"error"' not in out:
            _run("pane", "send-keys", pane, "Enter")
            return "agent send + Enter"
        return ""

    def wait(self, target, until=("working",), timeout=60):
        pane = self.resolve(target)
        deadline = __import__("time").time() + timeout
        while __import__("time").time() < deadline:
            state, _r, _d = self.get(pane)
            if state in until:
                return True
            __import__("time").sleep(3)
        return False

    def explain(self, target):
        pane = self.resolve(target)
        text, rule, evidence = _run("agent", "explain", pane), "", ""
        for line in text.splitlines():
            if line.startswith("rule: "):
                rule = line[6:].strip()
            elif line.startswith("evidence: "):
                evidence = line[10:].strip()
        hay = evidence.lower()
        for sig in ("quick safety check", "yes, i trust this folder", "trust this folder"):
            if sig in hay:
                return "trust prompt", "answer the dialog in the pane", "rule=%s" % rule
        if rule:
            return "prompt (%s)" % rule.replace("live_", "").replace("_form", ""), \
                   "clear the dialog in the pane", "rule=%s" % rule
        return "prompt", "clear the dialog in the pane", ""
