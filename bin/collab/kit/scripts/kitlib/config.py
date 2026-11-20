"""config — one file, project.yaml, read by every kit tool; defaults for everything it leaves out.

Also the machine facts every tool needs: the disk, the processes working in a folder, whether this machine
is a product host, and the ledger each action is written to.
"""
from __future__ import annotations

import copy
import json
import os
import shutil
import socket
import subprocess
import time
from pathlib import Path

from . import miniyaml

VERSION = "2.0.0"

DEFAULTS = {
    "project": None,  # the repository's folder name when unset
    "register": "plain",  # plain | house — how the kit's words and names read; the facts are the same
    "names": {
        "worktrees": None,  # default .worktrees; another register writes its own names here
        "branch_prefix": None,  # default work
    },
    "languages": {
        "project": "en",  # code, commits, pull requests and documents
        "client": [],  # tongues a client reads, allowed only in client_paths
        "client_paths": [],
        "files": "report",  # report | refuse — what a client tongue outside client_paths does at a commit
    },
    "stack": {"kind": "none", "link": [], "never_share": [], "parts": []},
    "hooks": {"chain": []},  # the repository's own tracked hook folders, run after the kit's hooks
    "checks": {},  # commit: [...], push: [...] — when absent, scripts/checks.sh probes the stack
    "worktrees": {
        "max": 8,
        "stale_hours": 24,  # a worktree idle this long with no process in it has no worker
        "expiry_days": 7,  # a worktree past its expiry is closed by gc when its work is safe
        "max_leftovers": 2,  # doctor and new refuse when more removable leftovers wait than this
        "close_merged_on_new": True,  # new first closes worktrees whose work is merged and safe
    },
    "disk": {"min_free_pct": 15, "min_free_gb": 40},
    "budget": {"max_gb_per_repo": 30},
    "containers": {
        "engine": "podman",
        "product_hosts": [],  # host names that run the product; nothing on them is removed by a worker
        "keep_tags": 2,  # the current and the previous release
        "labels": ["project", "purpose", "release"],
    },
    "leftovers": {
        "worktrees": {"apply": True},
        "branches": {"apply": True},
        "remote_refs": {"apply": True},
        "caches": {"apply": True, "idle_hours": 24},
        "scratch": {"apply": True, "dir": "", "older_than_hours": 24},
        "test_databases": {"apply": False, "pattern": "", "list": "", "drop": ""},
        "images": {"apply": True},
        "volumes": {"apply": True},
        "stopped_containers": {"apply": True, "older_than_hours": 24},
    },
}

PLAIN_NAMES = {"worktrees": ".worktrees", "branch_prefix": "work"}
REGISTERS = ("plain", "house")


def _merge(base, over):
    out = copy.deepcopy(base)
    for k, v in (over or {}).items():
        if isinstance(v, dict) and isinstance(out.get(k), dict):
            out[k] = _merge(out[k], v)
        else:
            out[k] = v
    return out


def git(*args, cwd=None, check=False, quiet=True):
    r = subprocess.run(["git", *args], cwd=cwd, text=True, capture_output=True)
    if check and r.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)}: {r.stderr.strip()}")
    return r


def toplevel(path: str | None = None) -> Path:
    r = git("rev-parse", "--show-toplevel", cwd=path or os.getcwd())
    if r.returncode != 0:
        raise SystemExit(f"not inside a git repository: {path or os.getcwd()}")
    return Path(r.stdout.strip())


def main_tree(path: str | None = None) -> Path:
    """The main working tree — where worktrees are made — whichever worktree the command runs in."""
    r = git("rev-parse", "--path-format=absolute", "--git-common-dir", cwd=path or os.getcwd())
    if r.returncode != 0:
        raise SystemExit(f"not inside a git repository: {path or os.getcwd()}")
    common = Path(r.stdout.strip())
    return common.parent if common.name == ".git" else common


def common_dir(path) -> Path:
    return Path(git("rev-parse", "--path-format=absolute", "--git-common-dir", cwd=str(path), check=True).stdout.strip())


class Config(dict):
    path: Path | None = None
    root: Path

    def get_path(self, dotted: str, default=None):
        cur = self
        for part in dotted.split("."):
            if not isinstance(cur, dict) or part not in cur:
                return default
            cur = cur[part]
        return cur


def load(root: Path | str | None = None) -> Config:
    root = Path(root) if root else toplevel()
    data = {}
    path = None
    for candidate in (root / "project.yaml", main_tree(str(root)) / "project.yaml"):
        if candidate.is_file():
            data = miniyaml.load(str(candidate)) or {}
            path = candidate
            break
    cfg = Config(_merge(DEFAULTS, data))
    cfg.path = path
    cfg.root = root
    reg = cfg.get("register") or "plain"
    if reg not in REGISTERS:
        raise SystemExit(f"project.yaml: register must be one of {', '.join(REGISTERS)}, not {reg!r}")
    for k, v in PLAIN_NAMES.items():
        if not cfg["names"].get(k):
            cfg["names"][k] = v
    if not cfg.get("project"):
        cfg["project"] = main_tree(str(root)).name
    env_min_pct, env_min_gb = os.environ.get("KIT_DISK_MIN_PCT"), os.environ.get("KIT_DISK_MIN_GB")
    if env_min_pct:
        cfg["disk"]["min_free_pct"] = float(env_min_pct)
    if env_min_gb:
        cfg["disk"]["min_free_gb"] = float(env_min_gb)
    return cfg


# ---- the machine ------------------------------------------------------------------------------------------

def disk(path) -> dict:
    """Free space where `path` lives. KIT_FAKE_DISK="<free_gb>/<total_gb>" stands in for a test."""
    fake = os.environ.get("KIT_FAKE_DISK")
    if fake:
        free, total = (float(x) for x in fake.split("/"))
    else:
        u = shutil.disk_usage(str(path))
        free, total = u.free / 1e9, u.total / 1e9
    return {"free_gb": round(free, 1), "total_gb": round(total, 1), "free_pct": round(100 * free / total, 1) if total else 0.0}


def disk_gate(cfg: Config, path) -> tuple[bool, str]:
    d = disk(path)
    lo_pct, lo_gb = float(cfg["disk"]["min_free_pct"]), float(cfg["disk"]["min_free_gb"])
    ok = d["free_pct"] >= lo_pct and d["free_gb"] >= lo_gb
    msg = (f"{d['free_gb']:g} GB free of {d['total_gb']:g} GB ({d['free_pct']:g} %); "
           f"the floor is {lo_pct:g} % and {lo_gb:g} GB")
    return ok, msg


def busy_paths() -> dict[str, int]:
    """Every folder a live process is working in → one pid. Linux reads /proc; elsewhere lsof if present."""
    me = os.getpid()
    out: dict[str, int] = {}
    fake = os.environ.get("KIT_FAKE_BUSY")  # a test names folders as if a process worked in them
    if fake:
        for p in fake.split(":"):
            if p:
                out[os.path.realpath(p)] = 1
        return out
    proc = Path("/proc")
    if proc.is_dir():
        for p in proc.iterdir():
            if not p.name.isdigit() or int(p.name) in (me, os.getppid()):
                continue
            try:
                out.setdefault(os.readlink(p / "cwd"), int(p.name))
            except OSError:
                continue
        return out
    if shutil.which("lsof"):
        r = subprocess.run(["lsof", "-d", "cwd", "-Fpn"], text=True, capture_output=True)
        pid = None
        for line in r.stdout.splitlines():
            if line.startswith("p"):
                pid = int(line[1:])
            elif line.startswith("n") and pid and pid != me:
                out.setdefault(line[1:], pid)
    return out


def busy_in(folder, busy: dict[str, int]) -> int | None:
    f = os.path.realpath(str(folder))
    for path, pid in busy.items():
        if path == f or path.startswith(f + os.sep):
            return pid
    return None


def machine_file() -> Path:
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    return Path(os.environ.get("KIT_MACHINE_FILE") or Path(base) / "collab-kit" / "machine.yaml")


def machine() -> dict:
    p = machine_file()
    return (miniyaml.load(str(p)) or {}) if p.is_file() else {}


def is_product_host(cfg: Config | None = None) -> tuple[bool, str]:
    env = os.environ.get("KIT_PRODUCT_HOST")
    if env is not None and env != "":
        return env not in ("0", "false", "no"), "KIT_PRODUCT_HOST"
    m = machine()
    if m.get("product_host"):
        return True, str(machine_file())
    host = socket.gethostname().split(".")[0]
    if cfg and host in (cfg["containers"].get("product_hosts") or []):
        return True, f"project.yaml containers.product_hosts names {host}"
    return False, ""


# ---- the ledger: every action the kit takes, appended, in the repository's own git folder ---------------

def ledger_path(root) -> Path:
    return common_dir(root) / "kit-ledger.jsonl"


def ledger(root, action: str, **fields):
    rec = {"at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "action": action, **fields}
    try:
        with open(ledger_path(root), "a", encoding="utf-8") as fh:
            fh.write(json.dumps(rec, sort_keys=True) + "\n")
    except OSError:
        pass


def emit(rows: list[dict], as_json: bool, columns: list[str]):
    """Structured output: TSV for a person and a pipe, or JSON lines with --json."""
    if as_json:
        for r in rows:
            print(json.dumps(r, sort_keys=True))
        return
    for r in rows:
        print("\t".join(str(r.get(c, "")) for c in columns))
