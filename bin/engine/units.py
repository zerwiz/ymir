#!/usr/bin/env python3
"""units.py — the ONE writer of every Ymir systemd user unit and desktop launcher (plan 269).

Run through `bin/engine/units.sh`. The register is `config/units.yaml`; the root every unit and
launcher is written against is the PINNED runtime (RULES/02 §7), resolved once:

    $YMIR_RUNTIME_DIR  →  <home>/config/runtime.env YMIR_RUNTIME_DIR  →  ~/ymir-runtime

Nothing here is a second resolver: it reads the same file `src/ymir_runtime/paths.py` and
`bin/pi/arm-pin-lib.sh` read, and adds the one documented default (Rule 07).

    units.sh list  [--names|--restart]   what the register owes, and every app under apps/
    units.sh check                       exit 1 when a Ymir unit/launcher is off the pin or unregistered
    units.sh drift                       exit 1 when an installed unit still runs a value its source retired
    units.sh write [name…] [--set K=V] [--render]
                                         render/retarget everything, write only what changed;
                                         --render re-seats an adopted unit from the register
"""
from __future__ import annotations

import argparse
import datetime as _dt
import glob
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # the register is YAML; without a parser nothing can be judged
    print("error: python3-yaml is required to read config/units.yaml", file=sys.stderr)
    sys.exit(2)

CODE_ROOT = Path(__file__).resolve().parents[2]
HOME = Path(os.environ.get("HOME", "~")).expanduser()
PATH_WORDS = ("bin", "apps", "scripts", "systems", "tools", "src")
SCAN_KEYS = ("ExecStart", "ExecStartPre", "ExecStartPost", "ExecStop", "ExecReload",
             "WorkingDirectory", "Environment", "EnvironmentFile", "Exec", "Path", "TryExec")


# ── the one resolver ─────────────────────────────────────────────────────────
def ymir_home() -> Path:
    if os.environ.get("YMIR_HOME"):
        return Path(os.environ["YMIR_HOME"]).expanduser()
    cfg = Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config") / "ymir" / "home"
    try:
        rec = cfg.read_text(encoding="utf-8").splitlines()[0].strip()
        if rec:
            return Path(rec).expanduser()
    except (OSError, IndexError):
        pass
    return HOME / "Documents" / "ymirhome"


def _expand(value: str) -> str:
    value = value.strip().strip("\"'")
    value = value.replace("${HOME}", str(HOME)).replace("$HOME", str(HOME))
    if value.startswith("~/"):
        value = str(HOME / value[2:])
    return value


def pin_dir() -> Path:
    explicit = os.environ.get("YMIR_RUNTIME_DIR")
    if explicit:
        return Path(_expand(explicit))
    conf = ymir_home() / "config" / "runtime.env"
    try:
        for line in conf.read_text(encoding="utf-8").splitlines():
            m = re.match(r"\s*(?:export\s+)?YMIR_RUNTIME_DIR=(.*)$", line)
            if m:
                return Path(_expand(m.group(1)))
    except OSError:
        pass
    return HOME / "ymir-runtime"


def unit_dir() -> Path:
    return Path(os.environ.get("YMIR_UNIT_DIR") or (Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config") / "systemd" / "user"))


def launcher_dirs() -> list[Path]:
    data = Path(os.environ.get("XDG_DATA_HOME") or HOME.joinpath(".lo" "cal", "share"))
    cfg = Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config")
    return [Path(os.environ.get("YMIR_APPLICATIONS_DIR") or data / "applications"),
            Path(os.environ.get("YMIR_AUTOSTART_DIR") or cfg / "autostart")]


def state_dir() -> Path:
    return Path(os.environ.get("YMIR_STATE_DIR") or ymir_home() / "state")


def roles_here() -> set[str]:
    """The roles this seat holds, or the empty set when unresolved (an unresolved seat owes all)."""
    raw = os.environ.get("YMIR_UNITS_ROLES") or os.environ.get("YMIR_ROLE")
    if raw is None and not os.environ.get("YMIR_UNITS_NO_ROLE_PROBE"):
        door = CODE_ROOT / "bin" / "skuld" / "role.sh"
        if door.exists():
            try:
                raw = subprocess.run(["bash", str(door), "resolve"], capture_output=True, text=True, timeout=20).stdout
            except (OSError, subprocess.SubprocessError):
                raw = ""
    return {r for r in re.split(r"[\s,]+", raw or "") if r}


def owed(entry: dict, roles: set[str]) -> bool:
    want = entry.get("roles", "all")
    return want == "all" or not roles or bool(roles & set(want))


# ── the register ─────────────────────────────────────────────────────────────
def _roots() -> list[Path]:
    """Where the register and the app templates are read from: the code that is running, and the pin.

    The union, because the pin is what the machine RUNS (main) and the running code may be a branch
    that adds an app: a launcher the pin ships must never look unregistered to a branch that predates it.
    """
    roots = [CODE_ROOT]
    pin = pin_dir()
    try:
        if (pin / "config" / "units.yaml").exists() and os.path.realpath(pin) != os.path.realpath(CODE_ROOT):
            roots.append(pin)
    except OSError:
        pass
    return roots


def load_register() -> dict:
    reg: dict = {"units": [], "launchers": {}}
    seen: set[str] = set()
    for root in _roots():
        try:
            with open(root / "config" / "units.yaml", encoding="utf-8") as fh:
                part = yaml.safe_load(fh) or {}
        except OSError:
            continue
        for u in part.get("units") or []:
            if u["name"] not in seen:
                seen.add(u["name"])
                reg["units"].append(u)
        for k, v in (part.get("launchers") or {}).items():
            reg["launchers"].setdefault(k, v)
    return reg


def _glob(patterns: list[str]) -> list[Path]:
    out: list[Path] = []
    names: set[str] = set()
    for root in _roots():
        for pat in patterns:
            for p in sorted(Path(x) for x in glob.glob(str(root / pat))):
                if p.name not in names:
                    names.add(p.name)
                    out.append(p)
    return out


def templates(reg: dict) -> tuple[list[Path], list[Path]]:
    lc = reg["launchers"]
    return _glob(lc.get("templates", [])), _glob(lc.get("unit_templates", []))


# ── what is a Ymir tree ──────────────────────────────────────────────────────
def is_ymir_root(d: str) -> bool:
    return os.path.isdir(os.path.join(d, "RULES")) and os.path.exists(os.path.join(d, "bin", "engine", "ymir-install.sh"))


def ymir_root_of(path: str) -> str:
    """The Ymir checkout a path lives in, or empty. A removed worktree is still a tree."""
    m = re.match(r"^(.*?/\.yggdrasil/[^/]+)(?:/|$)", path)
    if m:
        return m.group(1)
    cur = os.path.normpath(path) if path.startswith("/") else ""
    while cur and cur != "/":
        if is_ymir_root(cur):
            return cur
        parent = os.path.dirname(cur)
        if parent == cur:
            break
        cur = parent
    return ""


TOKEN = re.compile(r"(?:%h|\$HOME|\$\{HOME\}|/)[^\s\"'=:;,]*")


def _under(path: str, root: Path) -> bool:
    try:
        r = os.path.realpath(root)
        p = os.path.realpath(path)
    except OSError:
        return False
    return p == r or p.startswith(r + os.sep)


def _expand_unit(written: str) -> str:
    return written.replace("%h", str(HOME)).replace("${HOME}", str(HOME)).replace("$HOME", str(HOME))


def stray_roots(text: str, pin: Path, keep: tuple[str, ...] = ()) -> list[str]:
    """Written forms (absolute, %h or $HOME) of every Ymir tree this text names that is not the pin."""
    found: list[str] = []
    for line in text.splitlines():
        key, _, rest = line.partition("=")
        if key.strip() not in SCAN_KEYS:
            continue
        if key.strip() == "Environment" and any(rest.lstrip().startswith(k + "=") for k in keep):
            continue
        for m in TOKEN.finditer(line):
            written = m.group(0)
            expanded = _expand_unit(written)
            if _under(expanded, pin):
                continue
            root = ymir_root_of(expanded)
            if not root or _under(root, pin):
                continue
            suffix = expanded[len(root):]
            wroot = written[: len(written) - len(suffix)] if suffix and written.endswith(suffix) else written
            if wroot not in found:
                found.append(wroot)
    return sorted(found, key=len, reverse=True)


def names_ymir(text: str) -> bool:
    """True when the text names ANY Ymir tree (the pin included)."""
    for line in text.splitlines():
        if line.split("=", 1)[0].strip() not in SCAN_KEYS:
            continue
        for m in TOKEN.finditer(line):
            if ymir_root_of(_expand_unit(m.group(0))):
                return True
    return False


# ── rendering ────────────────────────────────────────────────────────────────
def substitute(value: str, pin: Path, vars_: dict[str, str]) -> str:
    value = value.replace("@ROOT@", str(pin))

    def sub(m: re.Match) -> str:
        name = m.group(1)
        if name not in vars_:
            raise KeyError(name)
        return str(vars_[name]).replace("@ROOT@", str(pin))
    return re.sub(r"\$\{([A-Z][A-Z0-9_]*)\}", sub, value)


def pathify(command: str, pin: Path) -> str:
    out = []
    for word in command.split(" "):
        out.append(f"{pin}/{word}" if re.match(rf"^({'|'.join(PATH_WORDS)})/", word) else word)
    return " ".join(out)


def render_entry(entry: dict, pin: Path, overrides: dict[str, str]) -> dict[str, str]:
    """{filename: text} for one `render` entry."""
    name = entry["name"]
    vars_ = {**{k: str(v) for k, v in (entry.get("vars") or {}).items()}, **overrides}
    s = lambda v: substitute(str(v), pin, vars_)  # noqa: E731
    kind = entry.get("kind", "service")
    lines = ["[Unit]", f"Description={s(entry['description'])}"]
    if entry.get("doc"):
        lines.append(f"Documentation=file://{pin}/{entry['doc']}")
    lines += [s(x) for x in entry.get("unit_extra", [])]
    lines += ["", "[Service]", "Type=oneshot" if kind == "timer" else "Type=simple"]
    wd = entry.get("workdir")
    if wd:
        wd = s(wd)
        lines.append(f"WorkingDirectory={pin if wd == '.' else (wd if wd.startswith('/') else pin / wd)}")
    for k, v in (entry.get("env") or {}).items():
        lines.append(f"Environment={k}={s(v)}")
    lines.append(f"ExecStart={pathify(s(entry['exec']), pin)}")
    if entry.get("restart"):
        lines.append(f"Restart={entry['restart']}")
    lines += [s(x) for x in entry.get("extra", [])]
    if entry.get("wanted_by"):
        lines += ["", "[Install]", f"WantedBy={entry['wanted_by']}"]
    files = {f"{name}.service": "\n".join(lines) + "\n"}
    t = entry.get("timer")
    if t:
        tl = ["[Unit]", f"Description={s(t['description'])}", "", "[Timer]",
              f"OnBootSec={s(t['boot'])}", f"OnUnitActiveSec={s(t['every'])}"]
        if t.get("accuracy"):
            tl.append(f"AccuracySec={t['accuracy']}")
        tl += [f"Unit={name}.service", "", "[Install]", "WantedBy=timers.target"]
        files[f"{name}.timer"] = "\n".join(tl) + "\n"
    return files


def render_template(path: Path, pin: Path) -> str:
    return path.read_text(encoding="utf-8").replace("__YMIR_ROOT__", str(pin)).replace("__YMIR_RUNTIME__", str(pin))


# ── writing ──────────────────────────────────────────────────────────────────
class Run:
    def __init__(self, dry: bool, restart: bool) -> None:
        self.dry, self.restart = dry, restart
        self.rows: list[tuple[str, str, str, str]] = []
        self.changed: list[str] = []
        self.problems = 0

    def row(self, name: str, kind: str, state: str, detail: str, bad: bool = False) -> None:
        self.rows.append((name, kind, state, detail))
        self.problems += 1 if bad else 0

    def log_replaced(self, target: Path, old: str, new: str) -> None:
        gone = [ln for ln in old.splitlines() if ln and ln not in new.splitlines()]
        if not gone or self.dry:
            return
        try:
            log = state_dir() / "units-replaced.log"
            log.parent.mkdir(parents=True, exist_ok=True)
            stamp = _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
            with open(log, "a", encoding="utf-8") as fh:
                for ln in gone:
                    fh.write(f"{stamp}\t{target}\t{ln}\n")
        except OSError:
            pass

    def put(self, target: Path, text: str, name: str, kind: str) -> None:
        old = target.read_text(encoding="utf-8") if target.exists() else None
        if old == text:
            self.row(name, kind, "current", "on the pin")
            return
        if self.dry:
            self.row(name, kind, "would-write" if old is None else "would-move", str(target))
            return
        target.parent.mkdir(parents=True, exist_ok=True)
        if old is not None:
            self.log_replaced(target, old, text)
        tmp = target.with_name(target.name + ".tmp-units")
        tmp.write_text(text, encoding="utf-8")
        os.replace(tmp, target)
        self.changed.append(target.name)
        self.row(name, kind, "written" if old is None else "moved", str(target))


def have_systemd() -> bool:
    return not os.environ.get("YMIR_UNITS_NO_SYSTEMCTL") and shutil.which("systemctl") is not None


def systemctl(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["systemctl", "--user", *args], capture_output=True, text=True, timeout=60)


def finish(run: Run) -> None:
    if run.dry or not run.changed or not have_systemd():
        return
    systemctl("daemon-reload")
    if run.restart:
        for fn in run.changed:
            if fn.endswith((".service", ".timer")) and systemctl("is-active", fn).stdout.strip() == "active":
                systemctl("try-restart", fn)


def parse_sets(items: list[str]) -> dict[str, str]:
    out = {}
    for it in items or []:
        k, _, v = it.partition("=")
        out[k.strip()] = v
    return out


def retarget(text: str, roots: list[str], pin: Path) -> str:
    pin_s = str(pin)
    for r in roots:  # longest first, so a worktree path is not eaten by its parent tree
        # A root matches only as a whole path component: never inside a longer name
        # (`~/ymir` inside `~/ymir-runtime`), and never where the pin already stands.
        rx = re.compile(r"(?<![\w.\-/%$])" + re.escape(r) + r"(?![\w.\-])")
        out, last = [], 0
        for m in rx.finditer(text):
            if text.startswith(pin_s, m.start()) and not re.match(r"[\w.\-]", text[m.start() + len(pin_s):m.start() + len(pin_s) + 1] or " "):
                continue  # already on the pin (the pin may live under the tree it replaces)
            out.append(text[last:m.start()])
            out.append(pin_s)
            last = m.end()
        out.append(text[last:])
        text = "".join(out)
    return text


# ── verbs ────────────────────────────────────────────────────────────────────
def installed_units(udir: Path) -> list[Path]:
    """Every unit file and every drop-in of one: a drop-in can name a tree as surely as the unit."""
    found = sorted(udir.glob("*.service")) + sorted(udir.glob("*.timer"))
    return found + sorted(udir.glob("*.service.d/*.conf")) + sorted(udir.glob("*.timer.d/*.conf"))


def owner_of(f: Path) -> str:
    """The unit file name a path belongs to (a drop-in belongs to the unit its directory names)."""
    return f.parent.name[:-2] if f.parent.name.endswith(".d") else f.name


def registered_names(reg: dict, unit_tpl: list[Path]) -> set[str]:
    names = {u["name"] for u in reg["units"]}
    names |= {p.name[:-3] for p in unit_tpl}  # ymir-rodd.service.in → ymir-rodd.service
    return names


def entry_for(reg: dict, filename: str) -> dict | None:
    base = re.sub(r"\.(service|timer)$", "", filename)
    for u in reg["units"]:
        if u["name"] == base:
            return u
    return None


def cmd_write(args: argparse.Namespace) -> int:
    reg, pin = load_register(), pin_dir()
    roles = roles_here()
    run = Run(args.dry_run, not args.no_restart)
    overrides = parse_sets(args.set)
    want = set(args.names)
    udir = unit_dir()
    tpl_launch, tpl_unit = templates(reg)
    for e in reg["units"]:
        if want and e["name"] not in want:
            continue
        if not want and not owed(e, roles):  # a unit asked for BY NAME is owed; the role gates the sweep
            run.row(e["name"], e["kind"], "skipped", "not this seat's role")
            continue
        # a unit another installer already wrote (the fleet renders gna-desk from its own template) keeps its
        # shape: the writer moves its paths and never reformats it, so two writers cannot flip-flop
        present = any((udir / f"{e['name']}.{x}").exists() for x in ("service", "timer"))
        # --render (plan 278): re-seat from the register even where another installer wrote the file, so a
        # unit that kept a retired argument through the adopt road is rendered from its source again
        if e["mode"] == "render" and e.get("if_present") == "adopt" and present and not overrides and not args.render:
            e = {**e, "mode": "adopt"}
        if e["mode"] == "render":
            if not (pin / ".git").exists() and not args.dry_run and not os.environ.get("YMIR_UNITS_ALLOW_NO_PIN"):
                run.row(e["name"], e["kind"], "FAIL", f"no pinned runtime at {pin} — bin/engine/runtime-seat.sh seats it", bad=True)
                continue
            try:
                files = render_entry(e, pin, overrides)
            except KeyError as miss:
                run.row(e["name"], e["kind"], "FAIL", f"variable {miss} has no value", bad=True)
                continue
            for fn, text in files.items():
                run.put(udir / fn, text, e["name"], e["kind"])
        else:  # adopt: retarget whatever file the other installer wrote
            for suffix in ("service", "timer"):
                parts = [udir / f"{e['name']}.{suffix}"] + sorted(udir.glob(f"{e['name']}.{suffix}.d/*.conf"))
                for f in parts:
                    if not f.exists():
                        continue
                    shown = e["name"] + ("" if f.parent == udir else f" ({f.name})")
                    old = f.read_text(encoding="utf-8")
                    roots = stray_roots(old, pin, tuple(e.get("keep", [])))
                    if roots:
                        run.put(f, retarget(old, roots, pin), shown, e["kind"])
                    else:
                        run.row(shown, e["kind"], "current", "on the pin")
            if not any((udir / f"{e['name']}.{x}").exists() for x in ("service", "timer")):
                run.row(e["name"], e["kind"], "absent", "not installed on this seat")
    if not want:
        # the app's own unit templates, then every launcher, rendered against the pin
        if owed({"roles": reg["launchers"].get("roles", "all")}, roles):
            for p in tpl_unit:
                run.put(udir / p.name[:-3], render_template(p, pin), p.name[:-3], "service")
            if sys.platform.startswith("linux") or os.environ.get("YMIR_UNITS_FORCE_LAUNCHERS"):
                for p in tpl_launch:
                    text = render_template(p, pin)
                    door = _template_door(p, pin)
                    if door and not (pin / door).exists() and not args.dry_run and not os.environ.get("YMIR_UNITS_NO_DOOR_CHECK"):
                        run.row(p.name[:-3], "launcher", "skipped", f"{door} is not in the pin yet")
                        continue
                    run.put(launcher_dirs()[0] / p.name[:-3], text, p.name[:-3], "launcher")
        # strays NOT in the register are still moved: a unit on a working tree is the fault
        names = registered_names(reg, tpl_unit)
        for f in installed_units(udir):
            owner = owner_of(f)
            if owner in names or entry_for(reg, owner):
                continue
            old = f.read_text(encoding="utf-8")
            roots = stray_roots(old, pin)
            if roots:
                run.put(f, retarget(old, roots, pin), f.stem, "unregistered")
                run.row(f.stem, "unregistered", "UNREGISTERED", "moved onto the pin; add it to config/units.yaml")
        for d in launcher_dirs():
            for f in sorted(d.glob("*.desktop")) if d.is_dir() else []:
                old = f.read_text(encoding="utf-8")
                if f.name in {p.name[:-3] for p in tpl_launch}:
                    continue
                roots = stray_roots(old, pin)
                if roots:
                    run.put(f, retarget(old, roots, pin), f.name, "launcher")
    finish(run)
    emit(run.rows)
    return 1 if run.problems else 0


def _var_flags(exec_tpl: str) -> dict[str, str]:
    """{VAR: the flag word just before ${VAR}} in a register exec line (`--port ${GNA_DESK_PORT}` → --port)."""
    words = exec_tpl.split()
    out: dict[str, str] = {}
    for i, w in enumerate(words):
        m = re.fullmatch(r"\$\{([A-Z][A-Z0-9_]*)\}", w)
        if m and i > 0 and words[i - 1].startswith("-"):
            out[m.group(1)] = words[i - 1]
    return out


def drift_of(entry: dict, text: str) -> list[str]:
    """Why an installed unit no longer matches its source (plan 278), or nothing.

    Only what the register DECLARES is judged: a value listed under `retired:` for a variable is one the
    source used once and has since moved off. A unit still running it was never re-seated (the adopt road
    keeps every argument). A seat's own `--set` choice is never drift, because it is not a retired value.
    """
    retired = entry.get("retired") or {}
    if not retired:
        return []
    flags = _var_flags(str(entry.get("exec", "")))
    defaults = {k: str(v) for k, v in (entry.get("vars") or {}).items()}
    why: list[str] = []
    for line in text.splitlines():
        key, _, rest = line.partition("=")
        key = key.strip()
        for var, olds in retired.items():
            olds = [str(o) for o in (olds or [])]
            got = None
            if key.startswith("ExecStart") and var in flags:
                words = rest.split()
                for i, w in enumerate(words[:-1]):
                    if w == flags[var]:
                        got = words[i + 1]
            elif key == "Environment" and rest.startswith(var + "="):
                got = rest[len(var) + 1:].strip().strip("\"'")
            if got is not None and got in olds:
                why.append(f"{var}={got} is a retired default; the source says {defaults.get(var, '?')}")
    return sorted(set(why))


def cmd_drift(args: argparse.Namespace) -> int:
    """exit 1 when an installed Ymir unit runs a value its source has retired (plan 278, problem 17)."""
    reg = load_register()
    roles = roles_here()
    run = Run(True, False)
    udir = unit_dir()
    for e in reg["units"]:
        if not owed(e, roles):
            continue
        for suffix in ("service", "timer"):
            f = udir / f"{e['name']}.{suffix}"
            if not f.exists():
                continue
            try:
                text = f.read_text(encoding="utf-8")
            except OSError:
                continue
            for why in drift_of(e, text):
                run.row(e["name"], e["kind"], "DRIFT", f"{why} — bin/engine/units.sh write {e['name']} --render", bad=True)
    emit(run.rows or [("none", "-", "ok", "every installed unit runs what its source says")])
    return 1 if run.problems else 0


def _template_door(p: Path, pin: Path) -> str:
    m = re.search(r"^Exec=(?:bash |sh -c \"[^\"]*exec )?__YMIR_(?:ROOT|RUNTIME)__/([^\s\"]+)", p.read_text(encoding="utf-8"), re.M)
    return m.group(1) if m else ""


def cmd_check(args: argparse.Namespace) -> int:
    reg, pin = load_register(), pin_dir()
    roles = roles_here()
    run = Run(True, False)
    udir = unit_dir()
    tpl_launch, tpl_unit = templates(reg)
    names = registered_names(reg, tpl_unit)
    launch_names = {p.name[:-3] for p in tpl_launch}
    for f in installed_units(udir):
        try:
            text = f.read_text(encoding="utf-8")
        except OSError:
            continue
        owner = owner_of(f)
        label = owner[:-8] if owner.endswith(".service") else owner
        label = label + (f" ({f.parent.name}/{f.name})" if f.parent != udir else "")
        e = entry_for(reg, owner)
        keep = tuple(e.get("keep", [])) if e else ()
        roots = stray_roots(text, pin, keep)
        registered = e is not None or owner in names
        if roots:
            run.row(label, "unit", "OFF-PIN", f"runs {roots[0]}, not the pin {pin}", bad=True)
        elif names_ymir(text):
            if registered:
                run.row(label, "unit", "ok", "on the pin, in the register")
            else:
                run.row(label, "unit", "UNREGISTERED", "names a Ymir tree but is not in config/units.yaml", bad=True)
    for e in reg["units"]:
        if owed(e, roles) and e["mode"] == "render":
            if not (udir / f"{e['name']}.service").exists():
                run.row(e["name"], e["kind"], "absent", "not installed here (units.sh write seats it)")
    for d in launcher_dirs():
        for f in sorted(d.glob("*.desktop")) if d.is_dir() else []:
            try:
                text = f.read_text(encoding="utf-8")
            except OSError:
                continue
            roots = stray_roots(text, pin)
            if roots:
                run.row(f.name, "launcher", "OFF-PIN", f"points at {roots[0]}, not the pin {pin}", bad=True)
            elif names_ymir(text):
                if f.name in launch_names:
                    run.row(f.name, "launcher", "ok", "on the pin, in the register")
                else:
                    run.row(f.name, "launcher", "UNREGISTERED", "names a Ymir tree but no app ships its template", bad=True)
    if not (pin / ".git").exists():
        run.row("pin", "runtime", "ABSENT", f"no checkout at {pin} (bin/engine/runtime-seat.sh seats it)", bad=True)
    emit(run.rows or [("none", "-", "ok", "no Ymir unit or launcher on this seat")])
    return 1 if run.problems else 0


def cmd_list(args: argparse.Namespace) -> int:
    reg = load_register()
    roles = roles_here()
    tpl_launch, tpl_unit = templates(reg)
    if args.names or args.restart:
        out = []
        for e in reg["units"]:
            if not owed(e, roles):
                continue
            if args.restart and e.get("restart") is False:
                continue
            out.append(e["name"] + (".timer" if e.get("kind") == "timer" else ".service"))
        print("\n".join(out))
        return 0
    emit([(e["name"], e["kind"], e["mode"], ",".join(e["roles"]) if isinstance(e["roles"], list) else e["roles"])
          for e in reg["units"]], header="register{unit,kind,mode,roles}")
    rows = []
    apps = sorted({p.name for r in _roots() if (r / "apps").is_dir() for p in (r / "apps").iterdir() if p.is_dir()})
    for app in apps:
        faces = [t.name[:-3] for t in tpl_launch if t.parent.parent.name == app]
        svcs = [t.name[:-3] for t in tpl_unit if t.parent.parent.name == app]
        svcs += [e["name"] for e in reg["units"] if re.search(rf"\bapps/{re.escape(app)}/", e.get("exec", ""))]
        rows.append((app, ",".join(faces) or "-", ",".join(svcs) or "-",
                     "" if faces or svcs else "no seat face — installs nothing on a seat"))
    emit(rows, header="apps{app,launchers,units,note}")
    return 0


def emit(rows, header: str = "") -> None:
    head = header or "units{unit,kind,state,detail}"
    print(head.replace("{", f"[{len(rows)}]{{", 1) + ":")
    for r in rows:
        print("  " + ",".join('"' + str(c).replace('"', "'") + '"' for c in r))


def main() -> int:
    ap = argparse.ArgumentParser(prog="units.sh")
    sub = ap.add_subparsers(dest="verb", required=True)
    w = sub.add_parser("write")
    w.add_argument("names", nargs="*")
    w.add_argument("--set", action="append", default=[])
    w.add_argument("--dry-run", action="store_true")
    w.add_argument("--no-restart", action="store_true")
    w.add_argument("--render", action="store_true")
    sub.add_parser("check")
    sub.add_parser("drift")
    ls = sub.add_parser("list")
    ls.add_argument("--names", action="store_true")
    ls.add_argument("--restart", action="store_true")
    args = ap.parse_args()
    return {"write": cmd_write, "check": cmd_check, "drift": cmd_drift, "list": cmd_list}[args.verb](args)


if __name__ == "__main__":
    sys.exit(main())
