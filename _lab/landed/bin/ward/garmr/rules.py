"""rules.py — the judgement, deterministic and first (plan 98 §4.2).

A rule is a sentence with an allow-list. A model is never asked what severity a
fact is: the fact arrives with its severity, because the rule that saw it decided.
The template is the answer; a reasoner may only write the paragraph beneath it.

Severities: INFO · MEDIUM · HIGH · CRITICAL.
INFO means "recorded, not worth waking anyone" — it is still written, because a
suppressed line is how a later incident is explained.
"""
from __future__ import annotations

ORDER = {"INFO": 0, "MEDIUM": 1, "HIGH": 2, "CRITICAL": 3}


def _in_any(path: str, prefixes: list[str]) -> bool:
    return any(path.startswith(prefix) for prefix in prefixes)


def _port_of(addr: str) -> int:
    try:
        return int(addr.rsplit(":", 1)[1])
    except Exception:
        return 0


def evaluate(finding: dict, cfg: dict) -> dict:
    """finding -> {severity, title, line, suppress}. Pure: no I/O, no model."""
    allow = cfg.get("allow", {})
    kind = finding.get("kind", "unknown")
    comm = (finding.get("comm") or "?").strip()
    pid = finding.get("pid") or "?"
    uid = finding.get("uid") or "?"
    ts = finding.get("ts") or "?"
    target = finding.get("target") or ""

    if kind == "sensitive_open":
        readers = {r.lower() for r in allow.get("sensitive_readers", [])}
        if comm.lower() in readers:
            return _out("INFO", "sensitive path read by an allow-listed reader",
                        f"INFO: {comm} (pid {pid}) read {target} at {ts}", suppress=True)
        return _out("CRITICAL", "sensitive path opened by a stranger",
                    f"CRITICAL: {comm} (pid {pid}, uid {uid}) opened protected {target} at {ts} — not on the allow-list",
                    suppress=False)

    if kind == "exec":
        path = finding.get("exe") or ""
        writable = allow.get("writable_dirs", [])
        expected = allow.get("program_dirs", [])
        if path and _in_any(path, writable):
            return _out("HIGH", "a program ran from a writable place",
                        f"HIGH: {comm} (pid {pid}, uid {uid}) executed {target} from a writable path at {ts}",
                        suppress=False)
        if path and _in_any(path, expected):
            return _out("INFO", "expected program executed",
                        f"INFO: {comm} (pid {pid}) executed {target} at {ts}", suppress=True)
        return _out("MEDIUM", "a program ran from an unusual place",
                    f"MEDIUM: {comm} (pid {pid}, uid {uid}) executed {target} at {ts}", suppress=False)

    if kind == "listener":
        port = _port_of(finding.get("addr", ""))
        known = {int(p) for p in allow.get("listen_ports", [])}
        if port in known:
            return _out("INFO", "known listener",
                        f"INFO: {comm} (pid {pid}) listens on {finding.get('addr')}", suppress=True)
        return _out("HIGH", "a new listener appeared",
                    f"HIGH: {comm} (pid {pid}) is listening on {finding.get('addr')} at {ts}", suppress=False)

    if kind == "egress":
        peer = (finding.get("peer") or "").split(":")[0]
        hosts = {h.lower() for h in allow.get("peer_hosts", [])}
        if peer in hosts or peer.startswith("100.") or peer.startswith("192.168.") or peer.startswith("10."):
            return _out("INFO", "expected peer", f"INFO: {comm} (pid {pid}) → {finding.get('peer')}", suppress=True)
        return _out("MEDIUM", "a connection to an unlisted host",
                    f"MEDIUM: {comm} (pid {pid}, uid {uid}) connected to {finding.get('peer')} at {ts}", suppress=False)

    if kind == "file_change":
        what = finding.get("class", "")
        if what == "identity":
            return _out("CRITICAL", "an identity or privilege file changed",
                        f"CRITICAL: {comm} (pid {pid}, uid {uid}) changed {target} at {ts} — passwd, shadow, sudoers or an authorised key",
                        suppress=False)
        return _out("HIGH", "a persistence surface changed",
                    f"HIGH: {comm} (pid {pid}, uid {uid}) changed {target} at {ts} — a unit, a cron row or an autostart entry",
                    suppress=False)

    if kind == "kill":
        return _out("INFO", "a signal was sent",
                    f"INFO: {comm} (pid {pid}) sent signal {finding.get('signal')} to pid {finding.get('target_pid')} at {ts}",
                    suppress=False)

    return _out("MEDIUM", "an unclassified observation",
                f"MEDIUM: {comm} (pid {pid}) — {kind} at {ts}", suppress=False)


def _out(severity: str, title: str, line: str, suppress: bool) -> dict:
    return {"severity": severity, "title": title, "line": line, "suppress": suppress}


def worst(*severities: str) -> str:
    return max(severities, key=lambda s: ORDER.get(s, 0), default="INFO")
