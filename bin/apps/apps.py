#!/usr/bin/env python3
"""apps.py — one door over every app: list · install · update · check · rollback · remove.

The Allfather, 2026-11-18: "we need installation and update logic for all apps" · "i dont
wanna them come into the apps folder anymore if installed they need their own places."

An app that has its own repo with the app contract (`contract: 1` in config/app-repos.yaml)
is installed into ITS OWN home, never into Ymir's `apps/` and never into the pin:

  $YMIR_APPS_HOME/<home>/repo/              the clone — fetched, never built in
  $YMIR_APPS_HOME/<home>/releases/<sha>/    one built, checked copy per update
  $YMIR_APPS_HOME/<home>/current, previous  the two links a flip moves

The release mechanics live HERE, once: fetch → export the sha into releases/<sha> → the
app's own `install.sh` builds in place → `install.sh --check` on the new release → flip
`current` only on green → keep the last three releases. An app's own `update.sh`, when
it has one, replaces the build step only. State and config live in the XDG dirs and are
never inside a release, so no update, rollback or remove can touch them.

While the desk is in a call (`bin/desk/in-call.sh holder` prints anything) an update
BUILDS but does not flip and restarts nothing; the flip waits, named, for the next run.

An app still in Ymir's tree (`contract: 0`) is on the legacy road: this door reports it
and installs nothing — its own slice brings its installer.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import io
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
KEEP = 3


def apps_home() -> Path:
    env = os.environ.get("YMIR_APPS_HOME")
    if env:
        return Path(env).expanduser()
    data = os.environ.get("XDG_DATA_HOME") or str(Path.home() / ".local" / "share")
    return Path(data) / "ymir-apps"


def forbidden_roots() -> list[Path]:
    """Where an install may never write: Ymir's apps/ and the pin's."""
    pin = Path(os.environ.get("YMIR_RUNTIME_DIR") or Path.home() / "ymir-runtime")
    return [ROOT / "apps", pin / "apps", pin.resolve() / "apps" if pin.exists() else pin / "apps"]


def guard_home(home: Path) -> None:
    real = home.resolve() if home.exists() else home.absolute()
    for bad in forbidden_roots():
        try:
            bad_real = bad.resolve() if bad.exists() else bad.absolute()
        except OSError:
            continue
        if real == bad_real or bad_real in real.parents:
            raise Refusal(f"the apps home {home} sits inside {bad} — an installed app never lands in apps/ "
                          "(the Allfather, 2026-11-18)", "set YMIR_APPS_HOME outside the Ymir tree and the pin")


class Refusal(Exception):
    def __init__(self, reason: str, help: str = ""):
        super().__init__(reason)
        self.reason, self.help = reason, help


# ── the registry ─────────────────────────────────────────────────────────────

def registry() -> list[dict]:
    """config/app-repos.yaml, read without a YAML library: one block per `- id:`,
    `key: value` lines, and the `git: { … }` inline dict."""
    reg = Path(os.environ.get("YMIR_APP_REGISTRY") or ROOT / "config" / "app-repos.yaml")
    apps, cur = [], None
    for line in reg.read_text().splitlines():
        if line.startswith("- id:"):
            cur = {"id": line.split(":", 1)[1].strip()}
            apps.append(cur)
        elif cur is not None and re.match(r"^  [a-z_]+:", line):
            key, val = line.strip().split(":", 1)
            val = re.sub(r"\s+#.*$", "", val).strip()
            if key == "git":
                cur["git"] = dict(re.findall(r"([a-z_]+):\s*([^,}\s]+)", val))
            else:
                cur[key] = val
    for a in apps:
        a.setdefault("home", a["id"])
        a["contract"] = int(a.get("contract") or 0)
    return apps


def find(name: str) -> dict:
    for a in registry():
        if name in (a["id"], a["home"]):
            return a
    raise Refusal(f"no app {name!r} in the registry", "bin/apps/apps.sh list")


def repo_url(app: dict) -> str:
    g = app.get("git") or {}
    if os.environ.get(f"YMIR_APP_{app['id'].upper().replace('-', '_')}_REPO"):
        return os.environ[f"YMIR_APP_{app['id'].upper().replace('-', '_')}_REPO"]
    return f"https://{g.get('host', 'github.com')}/{g.get('owner')}/{g.get('repo')}.git"


# ── small helpers ────────────────────────────────────────────────────────────

def sh(cmd: list[str], cwd: Path | None = None, env: dict | None = None, timeout: int = 1800) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True, timeout=timeout)


def in_call() -> bool:
    door = Path(os.environ.get("YMIR_DESK_DOOR") or ROOT / "bin" / "desk" / "in-call.sh")
    if not door.is_file():
        return False
    out = sh(["bash", str(door), "holder"], timeout=30)
    return bool(out.stdout.strip())


def app_env(app: dict, release: Path) -> dict:
    env = os.environ.copy()
    state = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local" / "state") / app["home"]
    config = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / app["home"]
    env.update({"YMIR_APP_NAME": app["home"], "YMIR_APP_RELEASE": str(release),
                "YMIR_APP_STATE_DIR": str(state), "YMIR_APP_CONFIG_DIR": str(config),
                "YMIR_APPS_HOME": str(apps_home())})
    if (ROOT / "bin").is_dir():
        env.setdefault("YMIR_RUNTIME_DIR", str(ROOT))
    return env


def flip(link: Path, target: Path) -> None:
    """Atomic: a new link beside the old, renamed over it."""
    tmp = link.with_name(link.name + ".new")
    if tmp.is_symlink() or tmp.exists():
        tmp.unlink()
    tmp.symlink_to(target)
    os.replace(tmp, link)


def current_sha(home: Path) -> str:
    cur = home / "current"
    return os.readlink(cur).rsplit("/", 1)[-1] if cur.is_symlink() else ""


def prune(home: Path) -> list[str]:
    keep = {current_sha(home)}
    prev = home / "previous"
    if prev.is_symlink():
        keep.add(os.readlink(prev).rsplit("/", 1)[-1])
    rel = home / "releases"
    if not rel.is_dir():
        return []
    olds = sorted((p for p in rel.iterdir() if p.is_dir() and p.name not in keep),
                  key=lambda p: p.stat().st_mtime, reverse=True)
    gone = []
    for p in olds[max(0, KEEP - len(keep)):]:
        shutil.rmtree(p)
        gone.append(p.name)
    return gone


# ── the verbs ────────────────────────────────────────────────────────────────

_ROADS: dict[str, str] = {}


def roads() -> dict[str, str]:
    if not _ROADS:
        out = sh(["bash", str(ROOT / "bin" / "apps" / "app-path.sh"), "--list"], timeout=60)
        for line in out.stdout.splitlines():
            m = re.match(r'\s+"([^"]+)","([^"]+)"', line)
            if m:
                _ROADS[m.group(1)] = m.group(2)
    return _ROADS


def row(app: dict) -> dict:
    home = apps_home() / app["home"]
    r = {"app": app["id"], "kind": app.get("kind", "-"), "contract": app["contract"],
         "current": current_sha(home) or "-", "previous": "-", "road": "-"}
    if (home / "previous").is_symlink():
        r["previous"] = os.readlink(home / "previous").rsplit("/", 1)[-1]
    r["road"] = roads().get(app["id"], "-")
    if app.get("status") == "archived":
        r["road"] = "archived"
    return r


def cmd_list(_args) -> tuple[int, list]:
    return 0, [row(a) for a in registry()]


def _legacy(app: dict) -> dict:
    return {"app": app["id"], "state": "legacy",
            "detail": f"still in Ymir's tree (apps/{app.get('repo', '').removeprefix('apps/')}); its slice brings "
                      "its own installer — nothing installed, and nothing ever written under apps/"}


def install(app: dict, check: bool = False) -> dict:
    if app.get("status") == "archived":
        return {"app": app["id"], "state": "archived", "detail": "a record, never installed"}
    if app["contract"] < 1:
        return _legacy(app)
    home = apps_home() / app["home"]
    guard_home(apps_home())
    if (home / "current").is_symlink():
        return {"app": app["id"], "state": "installed", "detail": f"current {current_sha(home)} — use update"}
    if check:
        return {"app": app["id"], "state": "absent", "detail": f"a full run clones {repo_url(app)} into {home}"}
    home.mkdir(parents=True, exist_ok=True)
    if not (home / "repo" / ".git").is_dir():
        out = sh(["git", "clone", "-q", repo_url(app), str(home / "repo")])
        if out.returncode != 0:
            raise Refusal(f"clone of {repo_url(app)} failed", out.stderr.strip()[-400:])
    return update(app)


def _export(repo: Path, sha: str, dest: Path) -> None:
    data = subprocess.run(["git", "-C", str(repo), "archive", "--format=tar", sha],
                          capture_output=True, check=True).stdout
    dest.mkdir(parents=True)
    with tarfile.open(fileobj=io.BytesIO(data)) as tar:
        tar.extractall(dest, filter="data")


def update(app: dict, check: bool = False) -> dict:
    if app.get("status") == "archived":
        return {"app": app["id"], "state": "archived", "detail": "never updated"}
    if app["contract"] < 1:
        return _legacy(app)
    home = apps_home() / app["home"]
    guard_home(apps_home())
    repo = home / "repo"
    if not (repo / ".git").is_dir():
        return install(app, check=check)
    branch = (app.get("git") or {}).get("default_branch", "main")
    out = sh(["git", "-C", str(repo), "fetch", "-q", "origin", branch])
    if out.returncode != 0:
        raise Refusal(f"fetch of {app['id']} failed", out.stderr.strip()[-400:])
    sha = sh(["git", "-C", str(repo), "rev-parse", "--short=12", f"origin/{branch}"]).stdout.strip()
    if sha == current_sha(home):
        return {"app": app["id"], "state": "current", "detail": sha}
    if check:
        return {"app": app["id"], "state": "behind", "detail": f"{current_sha(home) or 'none'} -> {sha}"}
    release = home / "releases" / sha
    if not release.is_dir():
        _export(repo, sha, release)
    env = app_env(app, release)
    builder = release / ("update.sh" if (release / "update.sh").is_file() else "install.sh")
    if not builder.is_file():
        shutil.rmtree(release)
        raise Refusal(f"{app['id']}@{sha} carries no install.sh — not an app contract", "the app's repo owes one")
    built = sh(["bash", str(builder)], cwd=release, env=env)
    if built.returncode != 0:
        return {"app": app["id"], "state": "red", "detail": f"build of {sha} failed — current stays "
                f"{current_sha(home) or 'none'}: {(built.stderr or built.stdout).strip()[-300:]}"}
    checked = sh(["bash", str(release / "install.sh"), "--check"], cwd=release, env=env)
    if checked.returncode != 0:
        return {"app": app["id"], "state": "red", "detail": f"{sha} built but its --check is red — not flipped: "
                f"{(checked.stderr or checked.stdout).strip()[-300:]}"}
    if in_call():
        (home / "pending-flip").write_text(sha + "\n")
        return {"app": app["id"], "state": "built, waiting", "detail": f"{sha} is ready; the desk is in a call, so the "
                "flip waits for the next update (desk law)"}
    if (home / "current").is_symlink():
        flip(home / "previous", Path(os.readlink(home / "current")))
    flip(home / "current", Path("releases") / sha)
    (home / "pending-flip").unlink(missing_ok=True)
    activated = activate(app, home)
    restarted = restart(app, home)
    gone = prune(home)
    return {"app": app["id"], "state": "updated", "detail": f"current {sha}" + (f" · {activated}" if activated else "")
            + (f" · restarted {restarted}" if restarted else "")
            + (f" · pruned {len(gone)}" if gone else "")}


def activate(app: dict, home: Path) -> str:
    """The app's own `activate.sh`, run from `current` after a flip (and a rollback): it re-seats
    what must name the live release — its doors on PATH, its MCP entry, its unit. Optional."""
    cur = home / "current"
    if not (cur / "activate.sh").is_file():
        return ""
    out = sh(["bash", str(cur / "activate.sh")], cwd=cur, env=app_env(app, cur), timeout=600)
    return "activated" if out.returncode == 0 else f"activate.sh failed: {(out.stderr or out.stdout).strip()[-160:]}"


def units_of(release: Path) -> list[str]:
    y = release / "app.yaml"
    if not y.is_file():
        return []
    m = re.search(r"^units:\s*\[([^\]]*)\]", y.read_text(), re.M)
    return [u.strip().strip("\"'") for u in m.group(1).split(",") if u.strip()] if m else []


def restart(app: dict, home: Path) -> str:
    units = units_of(home / "current")
    if not units or in_call():
        return ""
    sh(["systemctl", "--user", "try-restart", *units], timeout=120)
    return ",".join(units)


def rollback(app: dict) -> dict:
    home = apps_home() / app["home"]
    prev = home / "previous"
    if not prev.is_symlink():
        raise Refusal(f"{app['id']} has no previous release to roll back to")
    if in_call():
        raise Refusal("the desk is in a call — no flip and no restart until it ends (desk law)")
    was = os.readlink(home / "current")
    flip(home / "current", Path(os.readlink(prev)))
    flip(prev, Path(was))
    activate(app, home)
    return {"app": app["id"], "state": "rolled back", "detail": f"current {current_sha(home)} · previous {was.rsplit('/', 1)[-1]}"
            + (f" · restarted {restart(app, home)}" if units_of(home / 'current') else "")}


def remove(app: dict, yes: bool) -> dict:
    home = apps_home() / app["home"]
    if not home.is_dir():
        return {"app": app["id"], "state": "absent", "detail": str(home)}
    if not yes:
        raise Refusal(f"remove deletes {home} (releases and clone; never state or config)", "repeat with --yes")
    cur = home / "current"
    if (cur / "uninstall.sh").is_file():
        sh(["bash", str(cur / "uninstall.sh")], cwd=cur, env=app_env(app, cur.resolve()))
    guard_home(apps_home())
    shutil.rmtree(home)
    return {"app": app["id"], "state": "removed", "detail": f"{home} — state and config kept"}


def check(app: dict) -> dict:
    if app.get("status") == "archived" or app["contract"] < 1:
        r = row(app)
        return {"app": app["id"], "state": r["road"], "detail": "in Ymir's tree" if r["road"] == "legacy" else r["road"]}
    home = apps_home() / app["home"]
    cur = home / "current"
    if not cur.is_symlink():
        return {"app": app["id"], "state": "absent", "detail": "bin/apps/apps.sh install " + app["id"]}
    out = sh(["bash", str(cur / "install.sh"), "--check"], cwd=cur, env=app_env(app, cur.resolve()), timeout=300)
    pend = (home / "pending-flip").read_text().strip() if (home / "pending-flip").exists() else ""
    return {"app": app["id"], "state": "green" if out.returncode == 0 else "red",
            "detail": f"current {current_sha(home)}" + (f" · {pend} built, waiting to flip" if pend else "")
            + ("" if out.returncode == 0 else f" · {(out.stderr or out.stdout).strip()[-200:]}")}


# ── the door ─────────────────────────────────────────────────────────────────

USAGE = """usage: apps.sh <verb> [<app>|--all] [--check] [--yes] [--json]
  list                      every app: kind, contract, road, current, previous
  install <app>|--all       clone into its own home and build its first release
  update  <app>|--all       fetch, build a release, check it, flip on green (desk law)
  check   [<app>|--all]     each installed app's own --check
  rollback <app>            current <-> previous
  remove  <app> --yes       releases and clone; never state or config
  home                      where the apps home is"""


def main(argv: list[str]) -> int:
    as_json = "--json" in argv
    flags = {a for a in argv if a.startswith("--")}
    args = [a for a in argv if not a.startswith("--")]
    if not args or args[0] in ("-h", "help"):
        print(USAGE)
        return 0 if args else 2
    verb, rest = args[0], args[1:]
    try:
        targets = registry() if ("--all" in flags or (verb == "check" and not rest)) else [find(n) for n in rest]
        if verb == "list":
            code, rows = cmd_list(rest)
        elif verb == "home":
            code, rows = 0, [{"apps_home": str(apps_home())}]
        elif verb in ("install", "update", "check", "rollback", "remove"):
            if not targets:
                raise Refusal(f"{verb} which app?", "name one, or --all")
            fn = {"install": lambda a: install(a, "--check" in flags), "update": lambda a: update(a, "--check" in flags),
                  "check": check, "rollback": rollback, "remove": lambda a: remove(a, "--yes" in flags)}[verb]
            rows = []
            for a in targets:
                try:
                    rows.append(fn(a))
                except Refusal as r:
                    rows.append({"app": a["id"], "state": "refused", "detail": r.reason + (f" — {r.help}" if r.help else "")})
            code = 1 if any(r["state"] in ("red", "refused") for r in rows) else 0
        else:
            raise Refusal(f"unknown verb {verb!r}", USAGE)
    except Refusal as r:
        rows, code = [{"refused": r.reason, "help": r.help}], 1
    if as_json:
        print(json.dumps(rows, indent=2))
    else:
        keys = list(dict.fromkeys(k for r in rows for k in r))
        print(f"apps[{len(rows)}]{{{','.join(keys)}}}:")
        for r in rows:
            print("  " + ",".join(json.dumps(str(r.get(k, "")), ensure_ascii=False) for k in keys))
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
