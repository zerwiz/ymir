"""paths.py — ONE resolver for the assistant's two shelves (Rule 07/22).

Knowledge and policy are the operator's OWN records — approved facts, who may hear what, which groups
may speak to him, which chats are refused. They belong on the IDENTITY shelf, tracked and synced.
Runtime — the conversation store, the digest, the read audit, heartbeats — belongs on the STATE shelf,
which is ignored by git and never leaves the machine.
"""
from __future__ import annotations

import os
import subprocess


def home() -> str:
    env = os.environ.get("YMIR_HOME")
    if env:
        return os.path.expanduser(env)
    lib = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "bin", "vault", "hoard-lib.sh")
    lib = os.path.abspath(lib)
    out = subprocess.run(["bash", "-c",
                          f'. "{lib}" >/dev/null 2>&1; r=""; ymir_home_root r 2>/dev/null; printf "%s" "$r"'],
                         capture_output=True, text=True, timeout=10).stdout.strip()
    if out and os.path.isdir(out):
        return out
    raise SystemExit("assistant: the hoard is unresolved — set YMIR_HOME")


def identity_dir() -> str:
    """Approved facts, grants, groups, bans — the operator's records."""
    return os.path.join(home(), "hodd", "identity", "assistant")


def state_dir() -> str:
    """The database, the digest, the audit, heartbeats — runtime, and never committed."""
    return os.path.join(home(), "hodd", "state", "assistant")


def approved_dir() -> str:
    return os.path.join(identity_dir(), "approved")


def grants_path() -> str:
    return os.path.join(identity_dir(), "grants.yaml")


def groups_path() -> str:
    return os.path.join(identity_dir(), "groups.yaml")


def banned_path() -> str:
    return os.path.join(identity_dir(), "banned.yaml")


def pending_dir() -> str:
    return os.path.join(identity_dir(), "pending")
