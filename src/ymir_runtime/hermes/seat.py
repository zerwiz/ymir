"""The Hermes seat — Ymir's doors, skills shelf and worker script, seated in Hermes and corrected on
every install and update (plan 317 §4, slices 1–3 and 6).

WHY. Measured 2026-11-18: Hermes ran Ymir's MCP door from a working tree, the seat never corrected a
live entry ("a LIVE entry is never overwritten"), and `--check` compared names, so it passed while
the values were wrong. A wrong path was wrong for ever.

THE RULE (§4.2). Ownership is recorded in a SIDE LEDGER, `~/.hermes/.ymir-owned.json`, never as a
marker key inside the operator's `config.yaml` (the reversible choice — Hermes' tolerance of unknown
keys was never measured, and deleting one file undoes it):

    entry in the ledger                      rewritten to the release's value (only Ymir's keys)
    same name, not in the ledger             LEFT ALONE, reported `operator-owned`
    in the list, absent from Hermes          added, recorded in the ledger
    in the ledger, gone from the list        disabled, reported `retired`, never deleted

Adoption (the first run, before any ledger exists): an existing entry becomes Ymir's only when it is
one of Ymir's OWN doors (`ymir`, the record doors on the gateway, `snotra`) AND either its value is
exactly the list's or it runs `bin/mcp/ymir-mcp.py` — the door only a Ymir seat ever wrote. Anything
else (hnoss, chrome-devtools, firecrawl, trello, a hand-seated a2abridge…) is the operator's.

THE PIN. The `ymir` door always names `<pin>/bin/mcp/ymir-mcp.py` with the pin as its LINK path, so an
update that flips the link moves Hermes with it. A packet list that still names a working tree is a
red `--check` row (`packet-list`), fixed upstream by `bin/bridge/mcp-config.sh seat`.

SKILLS (§4.2 / slice 6). Hermes loads `skills.external_dirs` in every working directory, so the seat
adds `<pin>/.agents/skills` there — the release's shelf, by the pin, with no link and no per-project
trust. Trust entries the old seat added for transient Yggdrasil worktrees (`…/.yggdrasil/…`) are
removed; every other trust entry is the operator's and stays.
"""

from __future__ import annotations

import copy
import hashlib
import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Mapping

from . import common as C

# Ymir's own doors: the only names that may be ADOPTED on a first run without a ledger.
YMIR_DOORS = ("ymir", "well", "bolthorn", "skuld", "snotra")
# The keys Ymir writes in an entry. Every other key (auth, connect_timeout, enabled…) is the
# operator's and survives a correction.
CORE_KEYS = ("url", "command", "args", "env")
DOOR_TAIL = ("bin", "mcp", "ymir-mcp.py")
WORKERS_SCRIPT = "ymir-workers.py"
LEDGER_VERSION = 1

SEATED, CORRECTED, CURRENT, OPERATOR, ADOPTED, RETIRED, STALE, RED = (
    "seated", "corrected", "current", "operator-owned", "adopted", "retired", "stale", "red")
# States that mean a write is pending — a `--check` that meets one exits 1.
PENDING = {SEATED, CORRECTED, ADOPTED, RETIRED, STALE, RED}
# What a pending state is called when nothing was written (`--check`).
CHECK_WORDS = {SEATED: "missing", CORRECTED: "drift", ADOPTED: "unrecorded", RETIRED: "would-retire"}


@dataclass
class Plan:
    config: dict
    ledger: dict
    scripts: dict[str, str] = field(default_factory=dict)   # name -> text to write
    rows: list[tuple[str, str, str]] = field(default_factory=list)

    def say(self, name: str, state: str, detail: str) -> None:
        self.rows.append((name, state, detail))

    @property
    def pending(self) -> list[tuple[str, str, str]]:
        return [r for r in self.rows if r[1] in PENDING]


# ── the entry shapes ────────────────────────────────────────────────────────────────────────────

def core(entry: Mapping) -> dict:
    out = {k: copy.deepcopy(entry[k]) for k in CORE_KEYS if k in entry and entry[k] not in (None, {}, [])}
    if "args" in entry and "command" in entry:
        out["args"] = list(entry.get("args") or [])
    return out


def hermes_shape(spec: Mapping) -> dict:
    """The packet list's spec in the shape Hermes' `mcp_servers` takes (the old seat's exact shape)."""
    if spec.get("url"):
        return {"url": spec["url"]}
    shaped = {"command": spec.get("command"), "args": list(spec.get("args") or [])}
    if spec.get("env"):
        shaped["env"] = dict(spec["env"])
    return shaped


def is_ymir_door(entry: Mapping) -> bool:
    argv = [str(entry.get("command") or "")] + [str(a) for a in (entry.get("args") or [])]
    return any(Path(a).parts[-3:] == DOOR_TAIL for a in argv if a)


def door_on_pin(spec: Mapping, pin: Path) -> dict:
    """The `ymir` door rewritten onto the pin's link path; any other entry unchanged."""
    if not pin or str(pin) in ("", ".") or not is_ymir_door(spec):
        return dict(spec)
    target = str(pin.joinpath(*DOOR_TAIL))
    out = dict(spec)
    out["args"] = [target if Path(str(a)).parts[-3:] == DOOR_TAIL else a for a in (spec.get("args") or [])]
    if Path(str(spec.get("command") or "")).parts[-3:] == DOOR_TAIL:
        out["command"] = target
    return out


def door_path(spec: Mapping) -> str:
    argv = [str(spec.get("command") or "")] + [str(a) for a in (spec.get("args") or [])]
    return next((a for a in argv if Path(a).parts[-3:] == DOOR_TAIL), "")


def fingerprint(value) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()[:16]


# ── the worker script Hermes' cron runs (slice 9) ───────────────────────────────────────────────

def workers_script(pin: Path) -> str:
    """`~/.hermes/scripts/ymir-workers.py` — a `.py` file, so Hermes runs it with its own Python.

    Hermes refuses scripts outside `~/.hermes/scripts/` and ignores shebangs (an extensionless bash
    pointer crashed on 2026-11-18), so this is generated Python that imports the core from the pin.
    """
    return (
        "# generated by `ymir hermes seat` (src/ymir_runtime/hermes/seat.py) — do not edit; re-run the seat.\n"
        "# Hermes cron: print each herdr worker that finished since the last tick; print nothing when\n"
        "# nothing finished, so a quiet tick delivers nothing. Panes are never closed.\n"
        "import os\n"
        "import sys\n"
        "\n"
        f"PIN = os.environ.get(\"YMIR_RUNTIME_DIR\") or {str(pin)!r}\n"
        "sys.path.insert(0, os.path.join(PIN, \"src\"))\n"
        "from ymir_runtime.hermes.cli import main  # noqa: E402\n"
        "\n"
        "sys.exit(main([\"wait-worker\", \"--once\", \"--cron\"] + sys.argv[1:]))\n"
    )


# ── the plan: what a seat would do, computed without touching anything ─────────────────────────

def plan(config: dict, packets: Mapping[str, Mapping], ledger: dict, pin: Path,
         scripts_dir: Path) -> Plan:
    cfg = copy.deepcopy(config or {})
    led = copy.deepcopy(ledger or {})
    led.setdefault("version", LEDGER_VERSION)
    led.setdefault("owner", "ymir")
    owned: dict = led.setdefault("mcp_servers", {})
    p = Plan(config=cfg, ledger=led)
    servers = cfg.setdefault("mcp_servers", {})
    if not isinstance(servers, dict):
        raise C.HermesError("config.yaml mcp_servers is not a map", "repair ~/.hermes/config.yaml by hand")

    # The list itself must name the pin, not a tree (slice 1's red row).
    listed_door = packets.get("ymir")
    if listed_door is not None and is_ymir_door(listed_door):
        want_path = str(pin.joinpath(*DOOR_TAIL)) if str(pin) not in ("", ".") else ""
        have_path = door_path(listed_door)
        if want_path and have_path != want_path:
            p.say("packet-list", RED, f"ymir names {have_path}, not the pin {want_path} — bin/bridge/mcp-config.sh seat")

    for name, spec in packets.items():
        want = core(hermes_shape(door_on_pin(spec, pin)))
        cur = servers.get(name)
        if cur is None:
            servers[name] = {**copy.deepcopy(want), "enabled": True}
            owned[name] = {"value": want, "seated_at": C.now_iso()}
            p.say(name, SEATED, _describe(want))
            continue
        if not isinstance(cur, dict):
            p.say(name, OPERATOR, "not a map — left alone")
            continue
        mine = name in owned
        revived = mine and owned[name].get("state") == RETIRED
        if revived:
            cur["enabled"] = True     # back in the list: Ymir's entry again, enabled again
        if not mine and name in YMIR_DOORS and (core(cur) == want or (name == "ymir" and is_ymir_door(cur))):
            mine = True
            owned[name] = {"value": want, "seated_at": C.now_iso(), "adopted": True}
            if core(cur) == want:
                p.say(name, ADOPTED, "Ymir's own door, value already the list's — recorded in the ledger")
                continue
        if not mine:
            same = core(cur) == want
            p.say(name, OPERATOR, "matches the list" if same else f"differs from the list ({_describe(want)}) — left alone")
            continue
        owned[name].pop("state", None)
        if core(cur) == want:
            owned[name]["value"] = want
            p.say(name, CORRECTED if revived else CURRENT,
                  ("re-enabled: " if revived else "") + _describe(want))
            continue
        before = _describe(core(cur))
        for k in CORE_KEYS:
            cur.pop(k, None)
        cur.update(copy.deepcopy(want))
        owned[name]["value"] = want
        owned[name]["seated_at"] = C.now_iso()
        p.say(name, CORRECTED, f"{before} -> {_describe(want)}")

    for name, rec in list(owned.items()):
        if name in packets or rec.get("state") == RETIRED:
            continue
        cur = servers.get(name)
        if isinstance(cur, dict) and cur.get("enabled", True):
            cur["enabled"] = False
        rec["state"] = RETIRED
        p.say(name, RETIRED, "no longer in the list — disabled, never deleted")

    _plan_skills(p, cfg, led, pin)
    _plan_scripts(p, led, pin, scripts_dir)
    return p


def _describe(value: Mapping) -> str:
    if value.get("url"):
        return str(value["url"])
    return " ".join([str(value.get("command") or "")] + [str(a) for a in value.get("args") or []]).strip()


def _plan_skills(p: Plan, cfg: dict, led: dict, pin: Path) -> None:
    skills = cfg.setdefault("skills", {})
    if not isinstance(skills, dict):
        p.say("skills", OPERATOR, "skills is not a map — left alone")
        return
    rec = led.setdefault("skills", {})
    if str(pin) in ("", "."):
        p.say("skills", RED, "no pin on this seat — bin/engine/release.sh build && flip")
        return
    shelf = str(pin / ".agents" / "skills")
    ext = skills.get("external_dirs")
    ext = [ext] if isinstance(ext, str) else list(ext or [])
    if shelf in ext:
        p.say("skills", CURRENT, f"external_dirs carries {shelf} (any cwd)")
    else:
        ext.append(shelf)
        p.say("skills", SEATED, f"external_dirs += {shelf} (the shelf loads in any cwd)")
    skills["external_dirs"] = ext
    rec["external_dirs"] = [shelf]

    trusted = skills.get("trusted_project_dirs")
    if isinstance(trusted, list):
        gone = [d for d in trusted if "/.yggdrasil/" in str(d)]
        if gone:
            skills["trusted_project_dirs"] = [d for d in trusted if d not in gone]
            rec.setdefault("pruned_trust", [])
            rec["pruned_trust"] = sorted(set(rec["pruned_trust"]) | set(gone))
            p.say("skills-trust", STALE, f"drops transient worktree trust: {', '.join(gone)}")
        else:
            p.say("skills-trust", CURRENT, f"{len(trusted)} trusted dir(s), none a transient worktree (the rest are the operator's)")


def _plan_scripts(p: Plan, led: dict, pin: Path, scripts_dir: Path) -> None:
    if str(pin) in ("", "."):
        return
    rec = led.setdefault("scripts", {})
    path = scripts_dir / WORKERS_SCRIPT
    text = workers_script(pin)
    try:
        have = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        have = None
    want_fp = fingerprint(text)
    if have == text:
        rec[WORKERS_SCRIPT] = want_fp
        p.say(f"script:{WORKERS_SCRIPT}", CURRENT, str(path))
        return
    if have is not None and rec.get(WORKERS_SCRIPT) not in (None, fingerprint(have)):
        p.say(f"script:{WORKERS_SCRIPT}", OPERATOR, f"{path} was edited by hand — left alone")
        return
    if have is not None and WORKERS_SCRIPT not in rec:
        p.say(f"script:{WORKERS_SCRIPT}", OPERATOR, f"{path} exists and is not Ymir's — left alone")
        return
    p.scripts[WORKERS_SCRIPT] = text
    rec[WORKERS_SCRIPT] = want_fp
    p.say(f"script:{WORKERS_SCRIPT}", SEATED if have is None else CORRECTED, str(path))


# ── reading and writing the operator's files ────────────────────────────────────────────────────

def _yaml():
    try:
        import yaml  # noqa: PLC0415
    except ImportError as exc:
        raise C.HermesError("PyYAML is not importable by this Python", "install python-yaml") from exc
    return yaml


def dump_yaml(doc: dict) -> str:
    return _yaml().safe_dump(doc, sort_keys=False, allow_unicode=True, default_flow_style=False)


def read_inputs(env: Mapping[str, str]) -> tuple[Path, str, dict, dict, dict]:
    cfg_path = C.hermes_config(env)
    src = C.packet_list(env)
    doc = C.load_json(src, None)
    if doc is None:
        raise C.HermesError(f"no packet list at {src}", "bin/bridge/mcp-config.sh seat")
    packets = doc.get("mcpServers") or doc.get("servers") or {}
    try:
        text = cfg_path.read_text(encoding="utf-8")
    except FileNotFoundError:
        text = ""
    try:
        config = _yaml().safe_load(text) or {} if text else {}
    except Exception as exc:  # noqa: BLE001 — any YAML error is the same refusal
        raise C.HermesError(f"{cfg_path} does not parse: {exc}", f"repair {cfg_path}; nothing was written") from exc
    ledger = C.load_json(C.owned_ledger(env), {})
    return cfg_path, text, config, packets, ledger


def config_ops(before: Mapping, after: Mapping, path: tuple[str, ...] = (), depth: int = 3) -> list[tuple[str, str, object]]:
    """The smallest list of `hermes config set|unset` operations that turns `before` into `after`.

    Maps are walked to `depth` (mcp_servers.<name>.<key>); a list or a scalar is set whole. A key
    with a dot in it cannot be addressed by `hermes config set` and is refused, never guessed.
    """
    ops: list[tuple[str, str, object]] = []
    for key in list(before.keys()) + [k for k in after.keys() if k not in before]:
        if "." in str(key):
            raise C.HermesError(f"config key {key!r} has a dot; `hermes config set` cannot address it",
                                "rename the entry in ~/.hermes/config.yaml")
        here = path + (str(key),)
        if key not in after:
            ops.append(("unset", ".".join(here), None))
            continue
        a, b = before.get(key), after[key]
        if a == b and key in before:
            continue
        if isinstance(a, dict) and isinstance(b, dict) and len(here) < depth:
            ops += config_ops(a, b, here, depth)
        else:
            ops.append(("set", ".".join(here), b))
    return ops


def apply_ops(env: Mapping[str, str], ops: list[tuple[str, str, object]]) -> list[str]:
    """Write through Hermes' own writer, so its locks, backups and formatting stay Hermes'."""
    done: list[str] = []
    hermes = C.hermes_bin(env)
    for verb, key, value in ops:
        argv = [hermes, "config", verb, key] + ([json.dumps(value)] if verb == "set" else [])
        r = C.run(argv, timeout=90, env=env)
        if not r.ok:
            raise C.HermesError(f"`hermes config {verb} {key}` exit {r.rc}: {(r.err or r.out).strip()[-200:]}"
                                + (f" — already written: {', '.join(done)}" if done else ""),
                                "the dated backup beside config.yaml restores the file")
        done.append(key)
    return done


def seat(env: Mapping[str, str] | None = None, *, check: bool = False, dry_run: bool = False,
         out=print) -> int:
    """Seat, check or dry-run. Exit: 0 current/seated · 1 drift (check) or a failed write."""
    env = C.environ(env)
    hermes = C.hermes_bin(env)
    if C.run([hermes, "--version"], timeout=30, env=env).rc == 127:
        raise C.HermesError("hermes is not installed on this seat", "install Hermes, then re-run the seat")
    cfg_path, text, config, packets, ledger = read_inputs(env)
    pin = C.pin_link(env)
    p = plan(config, packets, ledger, pin, C.hermes_scripts(env))
    ops = config_ops(config or {}, p.config)
    led_path = C.owned_ledger(env)
    new_ledger = json.dumps(p.ledger, indent=2, sort_keys=True) + "\n"
    try:
        old_ledger = led_path.read_text(encoding="utf-8")
    except FileNotFoundError:
        old_ledger = ""

    out(f"hermes_seat[{len(p.rows)}]{{entry,state,detail}}:")
    for name, state, detail in p.rows:
        out(C.row(name, CHECK_WORDS.get(state, state) if check else state, detail))

    if check:
        if p.pending:
            out(f"hermes-seat: {len(p.pending)} entr{'y' if len(p.pending) == 1 else 'ies'} not as the release wants: "
                + ", ".join(r[0] for r in p.pending))
            out("help: python3 -m ymir_runtime.hermes seat --dry-run, then without it")
            return 1
        out("hermes-seat: every owned entry matches the release (values compared, not names)")
        return 0

    if dry_run:
        if ops:
            out(C.unified(cfg_path, dump_yaml(config or {}), dump_yaml(p.config)).rstrip("\n"))
            for verb, key, value in ops:
                out(f"would run: hermes config {verb} {key}" + (f" '{json.dumps(value)}'" if verb == "set" else ""))
        if new_ledger != old_ledger:
            out(C.unified(led_path, old_ledger, new_ledger).rstrip("\n"))
        for name, body in p.scripts.items():
            spath = C.hermes_scripts(env) / name
            old = spath.read_text(encoding="utf-8") if spath.exists() else ""
            out(C.unified(spath, old, body).rstrip("\n"))
        out("hermes-seat: dry run — nothing written")
        return 0

    if ops:
        kept = C.backup(cfg_path)
        done = apply_ops(env, ops)
        out(f"hermes-seat: {cfg_path}: {', '.join(done)}" + (f" (backup {kept})" if kept else ""))
    if new_ledger != old_ledger:
        C.backup(led_path)
        C.write_atomic(led_path, new_ledger)
        out(f"hermes-seat: ledger {led_path}")
    for name, body in p.scripts.items():
        spath = C.hermes_scripts(env) / name
        C.backup(spath)
        C.write_atomic(spath, body, mode=0o755)
        out(f"hermes-seat: script {spath}")
    if not (ops or new_ledger != old_ledger or p.scripts):
        out("hermes-seat: nothing to change")
    return 0
