"""`--on <host>`: the same verb, answered by another machine, over ssh.

The road is plain ssh. Where the user has a tailnet, ssh simply takes it; the
hosts are the user's own (`~/.ssh/config`), never a list in this repo. No port is
opened outward: the remote viewer is reached through a tunnel ssh raises.

The far side must have the smithy installed (`smidja` on its PATH, or
SMIDJA_REMOTE_BIN naming it). `smidja doctor --on <host>` says whether it does.
"""

from __future__ import annotations

import json
import os
import shlex
import socket
import subprocess


def _ssh_base(host: str) -> list[str]:
    return ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", host]


def call(host: str, argv: list[str], timeout: int = 900) -> tuple[int, dict | str]:
    """Run `smidja <argv> --json` on the host. Returns (exit, parsed JSON or raw text)."""
    remote_bin = os.environ.get("SMIDJA_REMOTE_BIN", "smidja")
    inner = " ".join(shlex.quote(a) for a in [remote_bin, *argv, "--json"])
    # A login shell, so the far side's PATH (mise, ~/.local/bin) is the one its user has.
    probe = (f"command -v {shlex.quote(remote_bin)} >/dev/null 2>&1 || "
             f"PATH=\"$HOME/.local/bin:$PATH\"; {inner}")
    cmd = _ssh_base(host) + ["bash", "-lc", shlex.quote(probe)]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return 124, {"refused": f"{host} did not answer within {timeout}s"}
    text = out.stdout.strip()
    if out.returncode == 255:
        return 255, {"refused": f"ssh to {host} failed", "help": out.stderr.strip()[-400:]}
    if out.returncode == 127 or "command not found" in out.stderr:
        return 127, {"refused": f"the smithy is not installed on {host} (no `{remote_bin}` there)",
                     "help": "install it on that machine, or set SMIDJA_REMOTE_BIN to its path"}
    try:
        data = json.loads(text) if text else {}
    except ValueError:
        data = text
    if isinstance(data, dict):
        data.setdefault("road", f"ssh {host}")
    return out.returncode, data


def _free_port() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def tunnel(host: str, remote_port: int = 8437, local_port: int | None = None) -> dict:
    """Raise `ssh -N -L` in the background so the far viewer opens here, on loopback."""
    local_port = local_port or _free_port()
    cmd = _ssh_base(host) + ["-N", "-o", "ExitOnForwardFailure=yes",
                              "-L", f"127.0.0.1:{local_port}:127.0.0.1:{remote_port}"]
    proc = subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                            stderr=subprocess.PIPE, start_new_session=True)
    try:
        proc.wait(timeout=3)
        return {"refused": f"the tunnel to {host} did not hold",
                "help": (proc.stderr.read().decode() if proc.stderr else "")[-400:]}
    except subprocess.TimeoutExpired:
        pass
    return {"host": host, "url": f"http://127.0.0.1:{local_port}/", "pid": proc.pid,
            "close": f"kill {proc.pid}", "road": f"ssh {host}"}
