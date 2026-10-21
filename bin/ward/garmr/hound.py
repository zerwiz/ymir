"""hound.py — Garmr's senses: what executes, who touches the sensitive shelves,
what is listening, and what leaves the box. Read-only, metadata only.

    hound.py                 # follow the audit log and poll (the system service)
    hound.py --once          # one pass over what is already there, then exit
    hound.py --audit-file F  # read a fixture instead of the live log (tests)
    hound.py --listeners     # print the current listener/egress snapshot as findings

It writes newline-delimited JSON findings to `hound.findings` (the config), one per
observation, and NEVER content:

    {"ts","sense","kind","pid","uid","comm","exe","target","argv","addr","peer",…}

`target` is a path for exec/listener findings and a HASH for anything on a
sensitive shelf (redact.redact_path). argv is redacted by redact.redact_argv.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402
import redact  # noqa: E402

MSG = re.compile(r"msg=audit\((\d+\.\d+):(\d+)\)")
FIELD = re.compile(r"(\w+)=(\"[^\"]*\"|'[^']*'|\S+)")
HEX = re.compile(r"^[0-9A-Fa-f]+$")
KEYS = ("ymir-exec", "ymir-sensitive", "ymir-browserkill", "ymir-identity", "ymir-persist")


def _fields(line: str) -> dict:
    out = {}
    for key, value in FIELD.findall(line):
        if value[:1] in "\"'" and value[-1:] == value[:1]:
            value = value[1:-1]
        out[key] = value
    return out


def _decode_hex(text: str) -> str:
    if not text or not HEX.match(text) or len(text) % 2:
        return text
    try:
        return bytes.fromhex(text).decode("utf8", "replace")
    except ValueError:
        return text


def _proctitle_argv(value: str) -> list[str]:
    """audit writes the proctitle as ONE hex blob whose arguments are NUL-separated:
    decode first, then split — splitting the hex text finds nothing."""
    decoded = _decode_hex(value.strip())
    return [part for part in decoded.split("\x00") if part]


def parse_audit_line(line: str, current: dict) -> tuple[dict, list[dict]]:
    """Fold one audit line into the record group it belongs to.

    Returns (group, emitted) where group carries the fields accumulated for one
    audit id and emitted is a list of findings the group produced when it closed.
    """
    match = MSG.search(line)
    if not match:
        return current, []
    epoch, ident = match.group(1), match.group(2)
    emitted: list[dict] = []
    if current.get("_id") and current["_id"] != ident:
        emitted = _close(current)
        current = {}
    if not current:
        current = {"_id": ident, "_epoch": float(epoch), "_paths": [], "_argv": [], "_key": ""}
    fields = _fields(line)
    rtype = fields.get("type", "")
    if rtype.startswith("type="):
        rtype = rtype[5:]
    if rtype == "SYSCALL":
        for name in ("pid", "ppid", "uid", "comm", "exe", "key", "a0", "a1", "a2", "a3"):
            if name in fields:
                current[name] = fields[name]
        if fields.get("key"):
            current["_key"] = fields["key"]
    elif rtype == "EXECVE":
        argc = int(fields.get("argc", "0") or 0)
        argv = []
        for i in range(argc):
            argv.append(_decode_hex(fields.get(f"a{i}", "")))
        if argv:
            current["_argv"] = argv
    elif rtype == "PROCTITLE":
        titles = _proctitle_argv(fields.get("proctitle", ""))
        if titles:
            current["_argv"] = titles
    elif rtype == "PATH":
        name = fields.get("name", "")
        if name:
            current["_paths"].append(name)
    elif rtype == "CWD":
        current["_cwd"] = fields.get("cwd", "")
    return current, emitted


def _close(group: dict) -> list[dict]:
    key = group.get("_key", "")
    if key not in KEYS:
        return []
    pid = group.get("pid", "?")
    uid = group.get("uid", "?")
    comm = group.get("comm", "?")
    exe = group.get("exe", "")
    ts = time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime(group.get("_epoch", time.time())))
    findings = []

    if key == "ymir-exec":
        argv = group.get("_argv") or [exe or comm]
        try:
            seen = _seen_binaries()
        except OSError:
            seen = set()
        first_seen = (exe or (argv[0] if argv else "")) not in seen
        if first_seen:
            _remember_binary(exe or (argv[0] if argv else ""))
        findings.append({
            "ts": ts, "sense": "audit", "kind": "exec", "pid": pid, "uid": uid, "comm": comm,
            "exe": exe, "target": redact.redact_path(exe or (argv[0] if argv else "")),
            "argv": redact.redact_argv([a for a in argv if a]),
            "first_seen": first_seen,
        })
    elif key == "ymir-sensitive":
        for path in group.get("_paths") or [""]:
            findings.append({
                "ts": ts, "sense": "audit", "kind": "sensitive_open", "pid": pid, "uid": uid,
                "comm": comm, "exe": exe, "target": redact.redact_path(path),
                "op": group.get("a1", ""),
            })
    elif key in ("ymir-identity", "ymir-persist"):
        for path in group.get("_paths") or [""]:
            findings.append({
                "ts": ts, "sense": "audit", "kind": "file_change", "class": key.split("-", 1)[1],
                "pid": pid, "uid": uid, "comm": comm, "exe": exe,
                "target": redact.redact_path(path), "op": group.get("a1", ""),
            })
    elif key == "ymir-browserkill":
        findings.append({
            "ts": ts, "sense": "audit", "kind": "kill", "pid": pid, "uid": uid, "comm": comm,
            "signal": _hex(group.get("a1", "0")), "target_pid": _hex(group.get("a0", "0")),
        })
    return findings


def _hex(value: str) -> str:
    try:
        return str(int(value, 16))
    except (TypeError, ValueError):
        return str(value)


def _seen_path() -> str:
    return os.path.join(common.state_dir(), "exec_seen.txt")


def _seen_binaries() -> set[str]:
    try:
        with open(_seen_path()) as handle:
            return {line.strip() for line in handle if line.strip()}
    except OSError:
        return set()


def _remember_binary(path: str) -> None:
    if not path:
        return
    try:
        os.makedirs(common.state_dir(), exist_ok=True)
        with open(_seen_path(), "a") as handle:
            handle.write(path + "\n")
    except OSError:
        pass


def follow_audit(path: str, on_findings) -> None:
    """Tail the audit log and survive its rotation.

    auditd's log is logrotate'd. A process that opens it once keeps reading the OLD
    inode for ever and goes quietly blind — measured here: the hound sat on
    audit.log.2 while audit.log filled. So the inode is compared on every pass and
    the file is reopened when it changes; a fresh file is read from its start.
    """
    handle = None
    inode = None
    group: dict = {}
    while True:
        if not os.path.exists(path):
            time.sleep(5)
            continue
        try:
            stat = os.stat(path)
        except OSError:
            time.sleep(1)
            continue
        if handle is None or inode != stat.st_ino:
            if handle:
                handle.close()
                group = {}
            handle = open(path, "r", errors="replace")
            inode = stat.st_ino
            if inode and os.path.getsize(path) == 0:
                pass
            else:
                handle.seek(0)
        line = handle.readline()
        if not line:
            if group:
                on_findings(_close(group))
                group = {}
            time.sleep(1)
            continue
        group, emitted = parse_audit_line(line, group)
        if emitted:
            on_findings(emitted)


def read_audit_once(path: str) -> list[dict]:
    findings: list[dict] = []
    group: dict = {}
    if not os.path.exists(path):
        return findings
    with open(path, "r", errors="replace") as handle:
        for line in handle:
            group, emitted = parse_audit_line(line, group)
            if emitted:
                findings.extend(emitted)
    if group:
        findings.extend(_close(group))
    return findings


def snapshot_listeners() -> list[dict]:
    """Listening sockets and established peers, with the owning process where visible."""
    findings: list[dict] = []
    try:
        out = subprocess.run(["ss", "-Htulpn"], capture_output=True, text=True, timeout=10).stdout
    except Exception:
        return findings
    stamp = common.now_iso()
    for line in out.splitlines():
        parts = line.split()
        if len(parts) < 5:
            continue
        proto, _state, _recv, _send, local = parts[0], parts[1], parts[2], parts[3], parts[4]
        peer = parts[5] if len(parts) > 5 else ""
        proc = ""
        comm = "?"
        pid = "?"
        match = re.search(r'users:\(\("([^"]+)",pid=(\d+)', line)
        if match:
            comm, pid = match.group(1), match.group(2)
        if proto.startswith("udp"):
            continue
        if peer and peer not in ("0.0.0.0:*", "[::]:*", "*:*"):
            findings.append({"ts": stamp, "sense": "ss", "kind": "egress", "pid": pid,
                             "comm": comm, "peer": peer, "local": local, "proto": proto})
        else:
            findings.append({"ts": stamp, "sense": "ss", "kind": "listener", "pid": pid,
                             "comm": comm, "addr": local, "proto": proto})
    return findings


def main() -> int:
    parser = argparse.ArgumentParser(description="Garmr's senses")
    parser.add_argument("--once", action="store_true")
    parser.add_argument("--audit-file")
    parser.add_argument("--listeners", action="store_true")
    parser.add_argument("--stdout", action="store_true", help="print findings instead of writing")
    args = parser.parse_args()

    cfg = common.load_config()
    target = cfg["hound"]["findings"]
    if args.stdout:
        sink = lambda rows: [print(common.emit(r)) for r in rows]  # noqa: E731
    else:
        def sink(rows):
            common.rotate(target, int(cfg["hound"].get("max_bytes", 0) or 0))
            common.append_findings(target, rows)
            try:
                common.heartbeat(common.state_dir())
            except OSError:
                pass  # a heartbeat that cannot be written must not stop the senses

    if args.listeners:
        snapshot = snapshot_listeners()
        sink(snapshot)
        print(f"garmr: {len(snapshot)} socket observations", file=sys.stderr)
        return 0

    audit_path = args.audit_file or cfg["hound"]["audit_log"]
    if args.once or args.audit_file:
        sink(read_audit_once(audit_path))
        sink(snapshot_listeners())
        return 0

    poll = int(cfg["hound"].get("poll_seconds", 60))
    last_poll = 0.0
    seen: set[str] = set()
    while True:
        if time.time() - last_poll >= poll:
            rows = []
            for row in snapshot_listeners():
                fingerprint = common.emit({k: row.get(k) for k in ("kind", "comm", "addr", "peer", "pid")})
                if fingerprint in seen:
                    continue
                seen.add(fingerprint)
                rows.append(row)
            sink(rows)
            last_poll = time.time()
        follow_audit(audit_path, sink)


if __name__ == "__main__":
    sys.exit(main())
