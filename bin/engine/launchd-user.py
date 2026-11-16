#!/usr/bin/env python3
"""launchd-user.py — `systemctl --user` on a Mac: Ymir's systemd user units, run by launchd.

WHY (measured 2026-11-15, plan 293). Ymir writes systemd user units (bin/engine/units.py and the
installers it adopts) and drives them with `systemctl --user` from some sixty call sites. macOS has
no systemd, so on a Mac the units were written and nothing ever ran them: the installer's services,
fleet and gateway steps failed, and no hall, well or scheduled job rose.

This program is the macOS installation layer for that one door (RULES/05). It reads the SAME unit
files from the systemd user directory and answers the `systemctl --user` verbs Ymir uses by
rendering each unit as a launchd agent and driving it with `launchctl`. The core stays unchanged;
on a Mac `bin/engine/launchd-ensure.sh` seats this file as `systemctl` on the PATH.

  launchd-user.py --user <verb> [flags] [unit…]

Verbs: daemon-reload · enable [--now] · disable [--now] · start · stop · restart · try-restart ·
reload-or-restart · is-active · is-enabled · is-failed · status · show-environment · reset-failed ·
cat · list-units · list-unit-files · show (-p ActiveState/SubState/MainPID) · import-environment.

The mapping, per unit:
  X.service                      -> agent org.ymir.X (RunAtLoad; Restart= -> KeepAlive)
  X.timer (OnUnitActiveSec=)     -> agent org.ymir.X with StartInterval, running X.service's command
  a .target                      -> its <target>.wants/ directory, exactly as systemd keeps it
  enabled                        -> the agent's plist is in ~/Library/LaunchAgents (starts at login)
  started, not enabled           -> the plist is loaded from ~/Library/Application Support/ymir/launchd

Logs go to ~/Library/Logs/ymir/<unit>.log. Exit codes follow systemctl: 0 yes/ok, 1 no or failure,
3 inactive for `is-active`-like queries, 4 no such unit.
"""
from __future__ import annotations

import os
import plistlib
import re
import shlex
import subprocess
import sys
import time
from pathlib import Path

HOME = Path.home()
PREFIX = os.environ.get("YMIR_LAUNCHD_PREFIX", "org.ymir.")
UID = os.getuid()
DOMAIN = f"gui/{UID}"


def unit_dir() -> Path:
    return Path(os.environ.get("YMIR_UNIT_DIR") or (Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config") / "systemd" / "user"))


def agents_dir() -> Path:
    return Path(os.environ.get("YMIR_LAUNCH_AGENTS") or HOME / "Library" / "LaunchAgents")


def staged_dir() -> Path:
    return Path(os.environ.get("YMIR_LAUNCHD_STAGE") or HOME / "Library" / "Application Support" / "ymir" / "launchd")


def log_dir() -> Path:
    return Path(os.environ.get("YMIR_LAUNCHD_LOGS") or HOME / "Library" / "Logs" / "ymir")


# ── reading a unit ───────────────────────────────────────────────────────────
def norm(name: str) -> str:
    """A unit name with its suffix; a bare name is a service, as systemctl reads it."""
    return name if re.search(r"\.(service|timer|target|socket|path)$", name) else name + ".service"


def stem(name: str) -> str:
    return re.sub(r"\.(service|timer|target|socket|path)$", "", name)


def parse(path: Path) -> dict[str, dict[str, list[str]]]:
    """{section: {key: [values…]}}; continuation lines joined, comments dropped, drop-ins merged."""
    out: dict[str, dict[str, list[str]]] = {}
    files = [path] + sorted(path.parent.glob(path.name + ".d/*.conf"))
    for f in files:
        sec = ""
        buf = ""
        for raw in f.read_text(encoding="utf-8").splitlines():
            line = buf + raw.strip()
            if line.endswith("\\"):
                buf = line[:-1] + " "
                continue
            buf = ""
            if not line or line.startswith(("#", ";")):
                continue
            m = re.match(r"\[(.+)\]$", line)
            if m:
                sec = m.group(1)
                out.setdefault(sec, {})
                continue
            if "=" in line:
                k, v = line.split("=", 1)
                k = k.strip()
                if v.strip() == "" and k in out.get(sec, {}):
                    out[sec][k] = []  # an empty assignment resets the list, as systemd does
                    continue
                out.setdefault(sec, {}).setdefault(k, []).append(v.strip())
    return out


def one(u: dict, sec: str, key: str, default: str = "") -> str:
    vals = u.get(sec, {}).get(key) or []
    return vals[-1] if vals else default


def spec(s: str) -> str:
    """systemd's specifiers that Ymir's units use."""
    return (s.replace("%h", str(HOME)).replace("%u", os.environ.get("USER", "")).replace("%U", str(UID))
             .replace("%t", os.environ.get("TMPDIR", "/tmp").rstrip("/")).replace("%%", "%"))


def seconds(v: str) -> int:
    """'5min' / '30s' / '1h 30min' / '90' -> seconds."""
    total = 0.0
    units = {"": 1, "s": 1, "sec": 1, "second": 1, "seconds": 1, "m": 60, "min": 60, "minute": 60, "minutes": 60,
             "h": 3600, "hr": 3600, "hour": 3600, "hours": 3600, "d": 86400, "day": 86400, "days": 86400,
             "ms": 0.001, "msec": 0.001}
    for num, unit in re.findall(r"(\d+(?:\.\d+)?)\s*([a-z]*)", v.strip().lower()):
        total += float(num) * units.get(unit, 1)
    return max(1, int(total))


def env_pairs(values: list[str]) -> dict[str, str]:
    env: dict[str, str] = {}
    for v in values:
        for item in shlex.split(spec(v)):
            if "=" in item:
                k, val = item.split("=", 1)
                env[k] = val
    return env


def extra_path() -> list[str]:
    """launchd agents start with a bare PATH; carry the operator's user-local tool dirs (node, bun, bash 5)."""
    seen = []
    want = os.environ.get("YMIR_LAUNCHD_PATH") or os.environ.get("PATH", "")
    defaults = [str(HOME / ".local/bin"), str(HOME / ".local/opt/node/bin"), str(HOME / ".bun/bin"),
                "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
    for d in want.split(":") + defaults:
        if d and d not in seen and os.path.isdir(d):
            seen.append(d)
    return seen


# ── rendering a launchd agent ────────────────────────────────────────────────
def transient_dir() -> Path:
    """Where `systemd-run` units live: outside the unit dir, so an install never mistakes one for its own."""
    return staged_dir() / "transient"


def unit_path(name: str) -> Path | None:
    for d in (unit_dir(), transient_dir()):
        p = d / norm(name)
        if p.exists():
            return p
    return None


def agent_label(name: str) -> str:
    return PREFIX + stem(name)


def render(name: str) -> dict | None:
    """The launchd plist dict for a .service or .timer, or None when there is nothing to run."""
    name = norm(name)
    if name.endswith(".target"):
        return None
    svc_path = unit_path(stem(name) + ".service")
    if not svc_path:
        return None
    svc = parse(svc_path)
    execs = [spec(x).lstrip("-@!+:") for x in svc.get("Service", {}).get("ExecStart", []) if x]
    if not execs:
        return None
    env = env_pairs(svc.get("Service", {}).get("Environment", []))
    path = env.get("PATH", "")
    env["PATH"] = ":".join([p for p in path.split(":") if p] + [p for p in extra_path() if p not in path.split(":")])
    env.setdefault("HOME", str(HOME))
    script = ["set -e"] if len(execs) > 1 else []
    for ef in svc.get("Service", {}).get("EnvironmentFile", []):
        ef = spec(ef)
        opt = ef.startswith("-")
        ef = ef.lstrip("-")
        q = shlex.quote(ef)
        script.append(f"if [ -f {q} ]; then set -a; . {q}; set +a; fi" if opt else f"set -a; . {q}; set +a")
    for x in svc.get("Service", {}).get("ExecStartPre", []):
        x = spec(x)
        script.append(x.lstrip("-@!+:") + (" || true" if x.startswith("-") else ""))
    script += execs[:-1]
    script.append("exec " + execs[-1])
    logs = log_dir() / f"{stem(name)}.log"
    pl: dict = {
        "Label": agent_label(name),
        "ProgramArguments": ["/bin/bash", "-c", "\n".join(script)],
        "EnvironmentVariables": env,
        "StandardOutPath": str(logs),
        "StandardErrorPath": str(logs),
        # Standard, never Background: macOS throttles a Background agent to a crawl under load (measured
        # 2026-11-15 — every service sat in state R at 0% CPU and no port opened)
        "ProcessType": "Standard",
    }
    wd = one(svc, "Service", "WorkingDirectory")
    if wd:
        wd = spec(wd).lstrip("-")
        pl["WorkingDirectory"] = wd
    kind = one(svc, "Service", "Type", "simple")
    timer_path = unit_path(stem(name) + ".timer")
    if name.endswith(".timer") or (timer_path and kind == "oneshot" and name.endswith(".service") and is_enabled(stem(name) + ".timer")):
        t = parse(timer_path) if timer_path else {}
        every = one(t, "Timer", "OnUnitActiveSec") or one(t, "Timer", "OnUnitInactiveSec")
        cal = one(t, "Timer", "OnCalendar")
        if every:
            pl["StartInterval"] = seconds(every)
        elif cal:
            pl["StartInterval"] = 3600 if cal == "hourly" else 86400
        pl["RunAtLoad"] = bool(one(t, "Timer", "OnBootSec") and seconds(one(t, "Timer", "OnBootSec")) < 120)
        return pl
    pl["RunAtLoad"] = True
    restart = one(svc, "Service", "Restart", "no")
    if kind != "oneshot":
        if restart == "always":
            pl["KeepAlive"] = True
        elif restart in ("on-failure", "on-abnormal", "on-abort", "on-watchdog"):
            pl["KeepAlive"] = {"SuccessfulExit": False}
        rs = one(svc, "Service", "RestartSec")
        if rs:
            pl["ThrottleInterval"] = max(1, seconds(rs))
    return pl


def plist_bytes(pl: dict) -> bytes:
    return plistlib.dumps(pl, sort_keys=True)


def agent_file(name: str) -> Path:
    return agents_dir() / f"{agent_label(name)}.plist"


def staged_file(name: str) -> Path:
    return staged_dir() / f"{agent_label(name)}.plist"


def write_if_changed(target: Path, data: bytes) -> bool:
    if target.exists() and target.read_bytes() == data:
        return False
    target.parent.mkdir(parents=True, exist_ok=True)
    tmp = target.with_name(target.name + ".tmp")
    tmp.write_bytes(data)
    os.replace(tmp, target)
    return True


# ── launchctl ────────────────────────────────────────────────────────────────
def lc(*args: str) -> subprocess.CompletedProcess:
    if os.environ.get("YMIR_LAUNCHD_DRY"):
        print("launchctl " + " ".join(args), file=sys.stderr)
        return subprocess.CompletedProcess(args, 0, "", "")
    return subprocess.run(["launchctl", *args], capture_output=True, text=True, timeout=60)


def loaded(label: str) -> dict | None:
    r = lc("print", f"{DOMAIN}/{label}")
    if r.returncode != 0:
        return None
    info = {"state": "", "pid": "", "last": ""}
    for line in r.stdout.splitlines():
        line = line.strip()
        for key, field in (("state = ", "state"), ("pid = ", "pid"), ("last exit code = ", "last")):
            if line.startswith(key) and not info[field]:
                info[field] = line[len(key):].strip()
    return info


def boot_in(name: str) -> bool:
    label = agent_label(name)
    src = agent_file(name) if agent_file(name).exists() else staged_file(name)
    if not src.exists():
        return False
    log_dir().mkdir(parents=True, exist_ok=True)
    if loaded(label):
        lc("bootout", f"{DOMAIN}/{label}")
    # bootout returns before launchd has let the job go; a bootstrap in that window fails with
    # "5: Input/output error" (measured 2026-11-15) — wait for the label to leave, then try twice
    for _ in range(50):
        if not loaded(label):
            break
        time.sleep(0.2)
    r = lc("bootstrap", DOMAIN, str(src))
    if r.returncode != 0 and "already" not in (r.stderr or ""):
        time.sleep(1)
        r = lc("bootstrap", DOMAIN, str(src))
    if r.returncode != 0 and "already" not in (r.stderr or ""):
        print(f"launchd: could not load {label}: {(r.stderr or r.stdout).strip()}", file=sys.stderr)
        return False
    return True


def boot_out(name: str) -> None:
    label = agent_label(name)
    if loaded(label):
        lc("bootout", f"{DOMAIN}/{label}")


# ── targets ──────────────────────────────────────────────────────────────────
def wants_of(target: str) -> list[str]:
    d = unit_dir() / f"{norm(target)}.wants"
    return sorted(p.name for p in d.iterdir()) if d.is_dir() else []


def install_targets(name: str) -> list[str]:
    p = unit_path(name)
    if not p:
        return []
    u = parse(p)
    return [w for v in u.get("Install", {}).get("WantedBy", []) for w in v.split()]


# ── state answers ────────────────────────────────────────────────────────────
def is_enabled(name: str) -> bool:
    name = norm(name)
    if name.endswith(".target"):
        return any((unit_dir() / f"{t}.wants" / name).exists() for t in install_targets(name) or ["default.target"])
    if name.endswith(".timer"):
        return any((unit_dir() / f"{t}.wants" / name).is_symlink() for t in install_targets(name) or ["timers.target"])
    return agent_file(name).exists()


def active_state(name: str) -> str:
    name = norm(name)
    if not unit_path(name):
        return "inactive"
    if name.endswith(".target"):
        wants = [w for w in wants_of(name) if not w.endswith(".target")]
        if not wants:
            return "active" if is_enabled(name) else "inactive"
        states = [active_state(w) for w in wants]
        return "active" if all(s == "active" for s in states) else ("failed" if "failed" in states else "inactive")
    info = loaded(agent_label(name))
    if not info:
        return "inactive"
    if info["state"] == "running" or info["pid"]:
        return "active"
    if name.endswith(".timer"):
        return "active"  # a loaded interval agent waits between runs
    svc = parse(unit_path(name))
    last = info["last"]
    if one(svc, "Service", "Type") == "oneshot":
        if last in ("", "0", "(never exited)") and one(svc, "Service", "RemainAfterExit") in ("yes", "true", "1"):
            return "active"
        return "inactive" if last in ("", "0", "(never exited)") else "failed"
    return "failed" if last not in ("", "0", "(never exited)") else "activating"


# ── verbs ────────────────────────────────────────────────────────────────────
def do_enable(names: list[str], now: bool) -> int:
    rc = 0
    for raw in names:
        name = norm(raw)
        p = unit_path(name)
        if not p:
            print(f"Failed to enable unit: Unit file {name} does not exist.", file=sys.stderr)
            rc = 1
            continue
        for t in install_targets(name):
            link = unit_dir() / f"{t}.wants" / name
            link.parent.mkdir(parents=True, exist_ok=True)
            if not link.is_symlink():
                link.symlink_to(p)
        if not name.endswith(".target"):
            pl = render(name)
            if pl:
                write_if_changed(agent_file(name), plist_bytes(pl))
        if now and not start_one(name):
            rc = 1
    return rc


def do_disable(names: list[str], now: bool) -> int:
    for raw in names:
        name = norm(raw)
        for t in install_targets(name) or []:
            link = unit_dir() / f"{t}.wants" / name
            if link.is_symlink():
                link.unlink()
        if now:
            stop_one(name)
        if not name.endswith(".target"):
            f = agent_file(name)
            if f.exists():
                f.unlink()
    return 0


def start_one(name: str) -> bool:
    name = norm(name)
    if not unit_path(name):
        print(f"Failed to start {name}: Unit {name} not found.", file=sys.stderr)
        return False
    if name.endswith(".target"):
        ok = True
        for w in wants_of(name):
            ok = start_one(w) and ok
        return ok
    pl = render(name)
    if not pl:
        return False
    if agent_file(name).exists():
        write_if_changed(agent_file(name), plist_bytes(pl))
    else:
        write_if_changed(staged_file(name), plist_bytes(pl))
    return boot_in(name)


def stop_one(name: str) -> None:
    name = norm(name)
    if name.endswith(".target"):
        for w in wants_of(name):
            stop_one(w)
        return
    boot_out(name)
    p = unit_path(name)
    if p and p.parent == transient_dir():  # a transient unit is forgotten once stopped, as with --collect
        p.unlink(missing_ok=True)
        staged_file(name).unlink(missing_ok=True)
        return
    if p and not name.endswith(".timer"):
        for x in parse(p).get("Service", {}).get("ExecStop", []):
            subprocess.run(["/bin/bash", "-c", spec(x).lstrip("-@!+:")], capture_output=True, timeout=60)


def do_reload() -> int:
    """Re-render every agent Ymir has written, so an edited unit reaches launchd as systemd's reload does."""
    for d in (agents_dir(), staged_dir()):
        for f in sorted(d.glob(PREFIX + "*.plist")) if d.is_dir() else []:
            name = f.name[len(PREFIX):-len(".plist")]
            unit = name + (".timer" if unit_path(name + ".timer") and is_enabled(name + ".timer") else ".service")
            if not unit_path(unit):
                continue
            pl = render(unit)
            if pl and write_if_changed(f, plist_bytes(pl)) and loaded(agent_label(unit)):
                boot_in(unit)
    return 0


def do_status(names: list[str]) -> int:
    rc = 0
    for raw in names:
        name = norm(raw)
        p = unit_path(name)
        if not p:
            print(f"Unit {name} could not be found.")
            rc = 4
            continue
        st = active_state(name)
        en = "enabled" if is_enabled(name) else "disabled"
        info = loaded(agent_label(name)) or {}
        desc = one(parse(p), "Unit", "Description")
        print(f"● {name} - {desc}\n     Loaded: loaded ({p}; {en}; launchd {agent_label(name)})\n"
              f"     Active: {st}" + (f"\n   Main PID: {info['pid']}" if info.get("pid") else "")
              + f"\n       Logs: {log_dir() / (stem(name) + '.log')}")
        rc = rc or (0 if st == "active" else 3)
    return rc


def do_list(files: bool, args: list[str]) -> int:
    pat = [a for a in args if not a.startswith("-")]
    for p in sorted(unit_dir().glob("*")):
        if p.is_dir() or not re.search(r"\.(service|timer|target)$", p.name):
            continue
        if pat and not any(re.fullmatch(x.replace("*", ".*"), p.name) for x in pat):
            continue
        if files:
            print(f"{p.name} {'enabled' if is_enabled(p.name) else 'disabled'}")
        else:
            st = active_state(p.name)
            if st != "inactive" or "--all" in args:
                print(f"{p.name} loaded {st} {'running' if st == 'active' else 'dead'}")
    return 0


def do_show(names: list[str], props: list[str], value_only: bool = False) -> int:
    for raw in names:
        name = norm(raw)
        st = active_state(name)
        info = loaded(agent_label(name)) or {}
        vals = {"ActiveState": st, "SubState": "running" if info.get("pid") else ("exited" if st == "active" else "dead"),
                "MainPID": info.get("pid") or "0", "UnitFileState": "enabled" if is_enabled(name) else "disabled",
                "LoadState": "loaded" if unit_path(name) else "not-found", "Id": name}
        for k in props or list(vals):
            print(vals.get(k, "") if value_only else f"{k}={vals.get(k, '')}")
    return 0


def main(argv: list[str]) -> int:
    if "--user" not in argv:
        print("launchd-user: only the user manager exists on this Mac — run with --user", file=sys.stderr)
        return 1
    flags = {a for a in argv if a.startswith("-")}
    props: list[str] = []
    rest: list[str] = []
    it = iter(argv)
    for a in it:
        if a in ("-p", "--property"):
            props += next(it, "").split(",")
        elif a.startswith("--property="):
            props += a.split("=", 1)[1].split(",")
        elif not a.startswith("-"):
            rest.append(a)
    if not rest:
        return do_list(False, argv)
    verb, names = rest[0], rest[1:]
    quiet = "--quiet" in flags or "-q" in flags
    now = "--now" in flags
    if verb == "daemon-reload" or verb == "daemon-reexec":
        return do_reload()
    if verb in ("show-environment",):
        for k, v in sorted(os.environ.items()):
            print(f"{k}={v}")
        return 0
    if verb in ("import-environment", "set-environment", "unset-environment", "reset-failed", "mask", "unmask", "preset"):
        return 0
    if verb == "enable":
        return do_enable(names, now)
    if verb == "disable":
        return do_disable(names, now)
    if verb == "start":
        return 0 if all([start_one(n) for n in names]) else 1
    if verb == "stop":
        for n in names:
            stop_one(n)
        return 0
    if verb in ("restart", "reload-or-restart", "reload"):
        ok = True
        for n in names:
            stop_one(n)
            ok = start_one(n) and ok
        return 0 if ok else 1
    if verb in ("try-restart", "condrestart", "try-reload-or-restart"):
        for n in names:
            if active_state(n) == "active":
                stop_one(n)
                start_one(n)
        return 0
    if verb == "is-active":
        states = [active_state(n) for n in names]
        if not quiet:
            print("\n".join(states))
        return 0 if states and all(s == "active" for s in states) else 3
    if verb == "is-failed":
        states = [active_state(n) for n in names]
        if not quiet:
            print("\n".join(states))
        return 0 if any(s == "failed" for s in states) else 1
    if verb == "is-enabled":
        states = ["enabled" if is_enabled(n) else ("disabled" if unit_path(n) else "not-found") for n in names]
        if not quiet:
            print("\n".join(states))
        return 0 if states and all(s == "enabled" for s in states) else 1
    if verb == "status":
        return do_status(names)
    if verb == "cat":
        for n in names:
            p = unit_path(n)
            if not p:
                return 1
            print(f"# {p}\n{p.read_text(encoding='utf-8')}")
        return 0
    if verb in ("list-units", "list-timers"):
        return do_list(False, names + list(flags))
    if verb == "list-unit-files":
        return do_list(True, names + list(flags))
    if verb == "show":
        return do_show(names, props, "--value" in flags)
    print(f"launchd-user: the verb '{verb}' has no launchd road yet", file=sys.stderr)
    return 1


# ── systemd-run: a transient unit, rendered straight to a launchd agent ──────────────────
def do_run(argv: list[str]) -> int:
    """`systemd-run --user --unit=X [--collect] [--setenv=K=V]… [--property=StandardOutput=append:F]… CMD…`."""
    if "--user" not in argv:
        print("systemd-run: only the user manager exists on this Mac — run with --user", file=sys.stderr)
        return 1
    unit, env, out, err, cmd = "", {}, "", "", []
    it = iter(argv)
    for a in it:
        if cmd:
            cmd.append(a)
        elif a == "--":
            cmd = list(it)
            break
        elif a.startswith("--unit="):
            unit = a.split("=", 1)[1]
        elif a in ("--unit", "-u"):
            unit = next(it, "")
        elif a.startswith("--setenv=") or a in ("--setenv", "-E"):
            kv = a.split("=", 1)[1] if a.startswith("--setenv=") else next(it, "")
            if "=" in kv:
                k, v = kv.split("=", 1)
                env[k] = v
        elif a.startswith("--property=") or a in ("--property", "-p"):
            prop = a.split("=", 1)[1] if a.startswith("--property=") else next(it, "")
            k, _, v = prop.partition("=")
            path = v.split(":", 1)[1] if v.startswith(("append:", "file:")) else ""
            if k == "StandardOutput" and path:
                out = path
            elif k == "StandardError" and path:
                err = path
        elif a.startswith("-"):
            continue  # --collect, --quiet, --no-block, --same-dir: no launchd meaning, harmless
        else:
            cmd = [a]
    if not cmd:
        print("systemd-run: no command given", file=sys.stderr)
        return 1
    name = norm(unit or f"run-{os.getpid()}")
    path = env.get("PATH", "")
    env["PATH"] = ":".join([p for p in path.split(":") if p] + [p for p in extra_path() if p not in path.split(":")])
    env.setdefault("HOME", str(HOME))
    logs = str(log_dir() / f"{stem(name)}.log")
    pl = {"Label": agent_label(name), "ProgramArguments": cmd, "EnvironmentVariables": env,
          "StandardOutPath": out or logs, "StandardErrorPath": err or out or logs,
          "WorkingDirectory": os.getcwd(), "ProcessType": "Standard", "RunAtLoad": True}
    transient_dir().mkdir(parents=True, exist_ok=True)
    (transient_dir() / name).write_text("[Unit]\nDescription=transient (systemd-run)\n[Service]\nType=simple\nExecStart="
                                       + " ".join(shlex.quote(c) for c in cmd).replace("%", "%%") + "\n", encoding="utf-8")
    write_if_changed(staged_file(name), plist_bytes(pl))
    if not boot_in(name):
        return 1
    print(f"Running as unit: {name}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(do_run(sys.argv[1:]) if Path(sys.argv[0]).name == "systemd-run" else main(sys.argv[1:]))
