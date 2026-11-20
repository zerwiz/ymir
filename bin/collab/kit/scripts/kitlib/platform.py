#!/usr/bin/env python3
"""platform — the one place the kit asks the operating system to stop a process.

The kit runs on Linux and macOS. A process is asked to stop with the POSIX kill(1) utility, then forced after a
grace period; on a system without it the kit says so and leaves the process running.
"""
from __future__ import annotations

import shutil
import subprocess
import time


def alive(pid: int) -> bool:
    return subprocess.run(["kill", "-0", str(pid)], capture_output=True).returncode == 0


def stop_process(pid: int, grace: float = 2.0) -> str:
    if not shutil.which("kill"):
        return f"pid {pid}: no kill(1) on this system — left running"
    if not alive(pid):
        return f"pid {pid} had already stopped"
    r = subprocess.run(["kill", "-TERM", str(pid)], text=True, capture_output=True)
    if r.returncode != 0:
        return f"pid {pid}: {r.stderr.strip() or 'not ours to stop'} — left running"
    deadline = time.time() + grace
    while time.time() < deadline:
        if not alive(pid):
            return f"stopped pid {pid}"
        time.sleep(0.1)
    subprocess.run(["kill", "-KILL", str(pid)], capture_output=True)
    return f"stopped pid {pid} (forced after {grace:g} s)"
