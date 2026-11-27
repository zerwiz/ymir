#!/usr/bin/env python3
"""telegram-reader — one bot per machine, read by the harness of whoever holds the arm.

The door is bin/notify/telegram-reader.sh; its header is the manual. This is the body.

The law it keeps: every reader that is not the holder's is withheld and stopped FIRST, and the
holder's harness is only given the bot once no other reader is left. A token is never printed.
"""
from __future__ import annotations

import fcntl
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
TOKEN_KEY = "TELEGRAM_BOT_TOKEN"
SENTINEL = "ymir-arm-handover"
CHANNELS = ("pi", "claude", "hermes")
ROLE_HARNESS = {"pi": "pi", "counsellor": "pi", "claude": "claude", "hermes": "hermes"}
NEXT_STEP = {
    "pi": "nothing: an idle pi session connects by itself within a minute (else run /telegram-connect)",
    "claude": "agent: search your tools for plugin_telegram_telegram, which retries a server that failed to "
    "connect, then run bin/notify/telegram-reader.sh status; if nothing reads, ask for /mcp and a "
    "reconnect of the telegram server",
    "hermes": "nothing: the gateway is restarted by this door",
}


class Refused(Exception):
    pass


# ── the home ────────────────────────────────────────────────────────────────
def run(*argv: str) -> str:
    done = subprocess.run(list(argv), capture_output=True, text=True, check=False, timeout=60)
    return done.stdout.strip() if done.returncode == 0 else ""


def home() -> Path:
    if os.environ.get("YMIR_HOME"):
        return Path(os.environ["YMIR_HOME"]).expanduser()
    found = run("bash", "-c", '. "$1"; ymir_home_root h; printf %s "$h"', "_", str(ROOT / "bin/vault/hoard-lib.sh"))
    if not found:
        raise Refused("the home could not be resolved (bin/vault/hoard-lib.sh)")
    return Path(found)


def machine_name() -> str:
    if os.environ.get("YMIR_MACHINE"):
        return os.environ["YMIR_MACHINE"]
    seat = Path.home() / ".pi/agent/extensions/.ymir-seat"
    try:
        for line in seat.read_text().splitlines():
            if line.startswith("host=") and line[5:].strip():
                return line[5:].strip()
    except OSError:
        pass
    return os.uname().nodename.split(".")[0].lower()


def read_yaml(path: Path) -> dict:
    try:
        return yaml.safe_load(path.read_text()) or {}
    except FileNotFoundError:
        return {}
    except (OSError, yaml.YAMLError) as exc:
        raise Refused(f"{path} cannot be read: {exc.__class__.__name__}") from exc


def machine_row(base: Path) -> dict:
    registry = read_yaml(base / "hodd/identity/machines.yaml")
    return (((registry.get("machines") or {}).get(machine_name()) or {}).get("telegram")) or {}


def secret(ref: str, key: str) -> str:
    return run("bash", str(ROOT / "bin/vault/hodd.sh"), "get", ref, key)


def allowlist(base: Path) -> list[str]:
    tg = read_yaml(base / "hodd/identity/operator.yaml").get("telegram")
    value = tg.get("user_id") if isinstance(tg, dict) else None
    ids = [str(v).strip() for v in (value if isinstance(value, list) else [value]) if v]
    if not ids or not all(i.isdigit() for i in ids):
        raise Refused("no operator Telegram id: set telegram.user_id in hodd/identity/operator.yaml")
    return ids


def bot_id(token: str) -> str:
    head = (token or "").split(":", 1)[0]
    return head if ":" in (token or "") and head.isdigit() else ""


def machine_bot(base: Path, row: dict) -> tuple[str, str]:
    ref = row.get("token_ref")
    if not ref:
        raise Refused(f"machine {machine_name()} has no telegram.token_ref in the registry")
    token = secret(ref, TOKEN_KEY)
    ident = bot_id(token)
    if not ident:
        raise Refused(f"no usable {TOKEN_KEY} at {ref}")
    declared = str(row.get("bot_id") or "")
    if declared and declared != ident:
        raise Refused(f"the token at {ref} is not the bot the registry names — nothing was changed")
    if bot_id(secret("secrets/platform.env", "SKIRNIR_TELEGRAM_BOT_TOKEN")) == ident:
        raise Refused("the machine's bot is the assistant's own bot (SKIRNIR_TELEGRAM_BOT_TOKEN) — give the machine its own")
    return token, ident


# ── processes (Linux and macOS: ps, never /proc alone) ──────────────────────
def alive(pid: int) -> bool:
    if pid <= 1:
        return False
    state = run("ps", "-o", "stat=", "-p", str(pid))
    return bool(state) and not state.startswith("Z")


def under(pid: int, ancestor: int) -> bool:
    for _ in range(16):
        if pid == ancestor:
            return True
        parent = run("ps", "-o", "ppid=", "-p", str(pid))
        if not parent.isdigit() or int(parent) <= 1:
            return False
        pid = int(parent)
    return False


# ── files ───────────────────────────────────────────────────────────────────
def write_private(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    temp = path.with_name(f".{path.name}.{os.getpid()}")
    fd = os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as handle:
        handle.write(text)
    os.replace(temp, path)


def keep_first(path: Path) -> None:
    """One copy of what stood before this door first wrote the file."""
    backup = path.with_name(path.name + ".before-ymir-reader")
    if path.exists() and not backup.exists():
        shutil.copy2(path, backup)
        backup.chmod(0o600)


def read_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        return {}
    except (OSError, ValueError) as exc:
        raise Refused(f"{path} does not parse — left as it is") from exc


def save_json(path: Path, doc: dict) -> bool:
    if read_json(path) == doc:
        return False
    keep_first(path)
    write_private(path, json.dumps(doc, indent=2) + "\n")
    return True


def env_lines(path: Path) -> list[str]:
    try:
        return path.read_text().splitlines()
    except FileNotFoundError:
        return []


def env_value(path: Path, key: str) -> str:
    for line in env_lines(path):
        if line.startswith(key + "="):
            return line.split("=", 1)[1].strip().strip("'\"")
    return ""


def env_set(path: Path, values: dict[str, str | None]) -> bool:
    old = env_lines(path)
    new = [line for line in old if line.split("=", 1)[0] not in values]
    new += [f"{k}={v}" for k, v in values.items() if v is not None]
    if sorted(new) == sorted(old):
        return False
    keep_first(path)
    write_private(path, "".join(line + "\n" for line in new))
    return True


# ── the channels ────────────────────────────────────────────────────────────
class Pi:
    def __init__(self) -> None:
        agent = Path(os.environ.get("PI_CODING_AGENT_DIR") or Path.home() / ".pi/agent")
        self.config = agent / "telegram.json"
        self.state = agent / "tmp/pi-telegram/state.json"

    def present(self) -> bool:
        return self.config.parent.is_dir()

    def token(self) -> str:
        doc = read_json(self.config)
        profile = (doc.get("profiles") or {}).get("default") or {}
        return str(profile.get("botToken") or doc.get("botToken") or "")

    def transport(self) -> dict:
        return (((read_json(self.state).get("profiles") or {}).get("default") or {}).get("transport")) or {}

    def reader(self) -> int:
        record = self.transport()
        pid = record.get("pid")
        if record.get("instanceId") == SENTINEL or not isinstance(pid, int):
            return 0
        return pid if alive(pid) else 0

    def set_transport(self, record: dict | None) -> None:
        doc = read_json(self.state)
        entry = doc.setdefault("profiles", {}).setdefault("default", {})
        if record is None:
            entry.pop("transport", None)
        else:
            entry["transport"] = record
        write_private(self.state, json.dumps(doc, indent=2) + "\n")

    def stop(self, holder: int) -> str:
        """pi-telegram stands down within a second once another owner is recorded; pi itself is never killed."""
        pid = self.reader()
        if not pid:
            return ""
        old = self.transport()
        record = {"pid": holder or os.getpid(), "instanceId": SENTINEL}
        if old.get("journalPath"):
            record["journalPath"] = old["journalPath"]
        self.set_transport(record)
        time.sleep(2)  # its ownership watch runs every second
        return f"pi pid {pid} told to stand down"

    def withhold(self, ident: str) -> bool:
        doc = read_json(self.config)
        changed = False
        for block in (doc, (doc.get("profiles") or {}).get("default") or {}):
            if bot_id(str(block.get("botToken") or "")) == ident:
                del block["botToken"]
                changed = True
        return save_json(self.config, doc) if changed else False

    def grant(self, token: str, ident: str, ids: list[str]) -> bool:
        doc = read_json(self.config)
        profile = doc.setdefault("profiles", {}).setdefault("default", {})
        if str(profile.get("botId") or "") != ident:
            profile.pop("botUsername", None)
        profile.update(botToken=token, botId=int(ident), allowedUserId=int(ids[0]))
        for key in ("botToken", "botId", "botUsername", "allowedUserId"):
            doc.pop(key, None)
        changed = save_json(self.config, doc)
        if self.transport().get("instanceId") == SENTINEL:
            self.set_transport(None)
            changed = True
        return changed


class Claude:
    def __init__(self) -> None:
        config = Path(os.environ.get("CLAUDE_CONFIG_DIR") or Path.home() / ".claude")
        self.dir = Path(os.environ.get("YMIR_CLAUDE_TELEGRAM_DIR") or config / "channels/telegram")
        self.env = self.dir / ".env"
        self.access = self.dir / "access.json"

    def present(self) -> bool:
        return self.dir.parent.parent.is_dir()

    def token(self) -> str:
        return env_value(self.env, TOKEN_KEY)

    def reader(self) -> int:
        try:
            pid = int((self.dir / "bot.pid").read_text().strip())
        except (OSError, ValueError):
            return 0
        # a recycled pid is somebody else's process: only the plugin's own server counts
        return pid if alive(pid) and "server.ts" in run("ps", "-o", "args=", "-p", str(pid)) else 0

    def stop(self, holder: int) -> str:
        pid = self.reader()
        if not pid:
            return ""
        os.kill(pid, signal.SIGTERM)
        for _ in range(50):
            if not alive(pid):
                return f"Claude poller pid {pid} stopped"
            time.sleep(0.1)
        os.kill(pid, signal.SIGKILL)
        time.sleep(0.2)
        return f"Claude poller pid {pid} killed (it ignored SIGTERM)"

    def withhold(self, ident: str) -> bool:
        return env_set(self.env, {TOKEN_KEY: None}) if bot_id(self.token()) == ident else False

    def grant(self, token: str, ident: str, ids: list[str]) -> bool:
        changed = env_set(self.env, {TOKEN_KEY: token})
        doc = read_json(self.access)
        doc.update(dmPolicy="allowlist", allowFrom=ids, pending={})
        doc.setdefault("groups", {})
        return save_json(self.access, doc) or changed


class Hermes:
    def __init__(self) -> None:
        self.dir = Path(os.environ.get("HERMES_HOME") or Path.home() / ".hermes")
        self.env = self.dir / ".env"

    def present(self) -> bool:
        return self.dir.is_dir()

    def token(self) -> str:
        return env_value(self.env, TOKEN_KEY)

    def reader(self) -> int:
        # the gateway reads its env at start; it is moved by restarting it, not by signalling a pid
        return 0

    def stop(self, holder: int) -> str:
        return ""

    def restart(self) -> str:
        command = os.environ.get("YMIR_HERMES_CMD") or shutil.which("hermes")
        if not command:
            raise Refused("hermes is not on PATH, so its gateway cannot be restarted")
        if run("bash", str(ROOT / "bin/desk/in-call.sh"), "holder"):
            raise Refused("the desk is in a call: the Hermes gateway is not restarted now")
        done = subprocess.run([command, "gateway", "restart"], capture_output=True, check=False, timeout=60)
        if done.returncode != 0:
            raise Refused("hermes gateway restart failed")
        return "hermes gateway restarted"

    def withhold(self, ident: str) -> bool:
        if bot_id(self.token()) != ident:
            return False
        before = self.env.read_text()
        env_set(self.env, {TOKEN_KEY: None})
        try:
            self.restart()
        except Refused:
            write_private(self.env, before)  # the gateway still reads it: say so by keeping the file true
            raise
        return True

    def grant(self, token: str, ident: str, ids: list[str]) -> bool:
        before = self.env.read_text() if self.env.exists() else ""
        changed = env_set(self.env, {TOKEN_KEY: token, "TELEGRAM_ALLOWED_USERS": ",".join(ids)})
        if changed:
            try:
                self.restart()
            except Refused:
                write_private(self.env, before)  # so the next beat sees the change as owed and restarts
                raise
        return changed


def channels() -> dict:
    return {"pi": Pi(), "claude": Claude(), "hermes": Hermes()}


# ── the arm ─────────────────────────────────────────────────────────────────
def holder() -> tuple[int, str]:
    """(session pid, role) of the live arm holder; (0, '') when the arm is vacant."""
    state_door = str(ROOT / "bin/records/ymir-state.sh")
    owner = run("bash", state_door, "lock", "owner")
    if not owner.isdigit() or not alive(int(owner)):
        return 0, ""
    role = ""
    state = run("bash", state_door, "lock", "state-dir")
    try:
        fields = dict(p.split("=", 1) for p in (Path(state) / ".arm.role").read_text().split() if "=" in p)
        if fields.get("session") == owner:
            role = fields.get("role", "")
    except OSError:
        pass
    if role not in ROLE_HARNESS:
        comm = os.path.basename(run("ps", "-o", "comm=", "-p", owner))
        role = comm if comm in ROLE_HARNESS else (role or comm or "unknown")
    return int(owner), role


# ── the verbs ───────────────────────────────────────────────────────────────
def table(name: str, columns: str, rows: list[tuple]) -> None:
    print(f"{name}[{len(rows)}]{{{columns}}}:")
    for row in rows:
        print("  " + ",".join(json.dumps(str(v), ensure_ascii=False) for v in row))


def sync(released: bool) -> int:
    base = home()
    row = machine_row(base)
    if row.get("reader") != "arm":
        table("telegram-reader", "result,detail", [("off", "telegram.reader is not `arm` for this machine — nothing changed")])
        return 0
    pid, role = (0, "") if released else holder()
    if not pid and not released:
        table("telegram-reader", "result,detail", [("vacant", "no arm is held — nothing changed")])
        return 0
    token, ident = machine_bot(base, row)
    wanted = ROLE_HARNESS.get(role, "")
    ids = allowlist(base) if wanted else []
    rows, blocked = [], []
    found = channels()
    for name, channel in found.items():
        if not channel.present():
            continue
        try:
            ours = bot_id(channel.token()) == ident
            live = channel.reader()
            if name == wanted:
                # a second session of the holder's own harness is still a second reader
                if live and ours and not under(live, pid):
                    rows.append((name, "stopped", channel.stop(pid)))
                    tell_holder(f"A second {name} session took the Telegram bot and was stopped. Next: {NEXT_STEP[name]}")
                continue
            if not ours:
                continue
            note = channel.stop(pid) if live else ""
            channel.withhold(ident)
            if channel.reader():
                blocked.append(name)
            rows.append((name, "withheld", note or "the bot was taken out of its config"))
        except (Refused, OSError, subprocess.SubprocessError) as exc:
            blocked.append(name)
            rows.append((name, "FAILED", str(exc)))
    if blocked:
        rows.append((wanted or "-", "not-granted", f"another reader may still stand ({', '.join(blocked)})"))
    elif wanted:
        channel = found[wanted]
        if not channel.present():
            rows.append((wanted, "FAILED", "the holder's harness has no home on this machine"))
            blocked.append(wanted)
        else:
            try:
                changed = channel.grant(token, ident, ids)
                live = channel.reader()
                reading = bool(live) and under(live, pid) and not changed
                note = "" if reading or wanted == "hermes" else NEXT_STEP[wanted]
                rows.append((wanted, "granted" if changed else "current", note or "reading"))
                if note and changed:
                    tell_holder(f"Telegram moved to this seat. Next: {note}")
            except (Refused, OSError, subprocess.SubprocessError) as exc:
                blocked.append(wanted)
                rows.append((wanted, "FAILED", str(exc)))
    elif pid:
        rows.append((role, "no-channel", "this harness has no Telegram channel: nobody reads until the arm moves"))
        if rows[:-1]:
            tell_holder(f"Telegram has no reader while a {role} session holds the arm")
    table("telegram-reader", "channel,result,detail", rows or [("-", "current", "nothing to move")])
    return 1 if blocked else 0


def tell_holder(text: str) -> None:
    run("bash", str(ROOT / "bin/voice/rodd-arm.sh"), "tell", "--from", "script telegram-reader", "--class", "report", text)


def status(check: bool) -> int:
    base = home()
    row = machine_row(base)
    ident = ""
    if row.get("reader") == "arm":
        _, ident = machine_bot(base, row)
    pid, role = holder()
    rows, readers, strays = [], 0, 0
    for name, channel in channels().items():
        if not channel.present():
            continue
        current = bot_id(channel.token())
        bot = "machine" if ident and current == ident else ("other" if current else "none")
        live = channel.reader()
        mine = bool(live) and bool(pid) and under(live, pid)
        if live and bot == "machine":
            readers += 1
            strays += 0 if mine else 1
        rows.append((name, bot, live or "", "yes" if mine else "no"))
    table("telegram-reader", "mode,holder_pid,holder_role", [("arm" if ident else "off", pid or "", role)])
    table("channels", "channel,bot,reader_pid,holders_own", rows)
    return 1 if check and (readers > 1 or strays) else 0


def wants(name: str) -> int:
    """0 when the holder's harness has the bot and nothing reads it yet: it may connect itself."""
    base = home()
    row = machine_row(base)
    pid, role = holder()
    if row.get("reader") != "arm" or not pid or ROLE_HARNESS.get(role) != name:
        return 1
    _, ident = machine_bot(base, row)
    channel = channels()[name]
    return 0 if bot_id(channel.token()) == ident and not channel.reader() else 1


def main(argv: list[str]) -> int:
    verb = argv[0] if argv else "status"
    if verb == "wants" and argv[1:] and argv[1] in CHANNELS:
        try:
            return wants(argv[1])
        except Refused as exc:
            print(f"telegram-reader: {exc}", file=sys.stderr)
            return 1
    flags = set(argv[1:])
    if verb not in ("sync", "status", "check") or flags - {"--released", "--quiet"}:
        print("usage: telegram-reader.sh status | check | wants <harness> | sync [--released] [--quiet]", file=sys.stderr)
        return 2
    try:
        if verb != "sync":
            return status(verb == "check")
        lock_path = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "ymir/telegram-reader.lock"
        lock_path.parent.mkdir(parents=True, exist_ok=True)
        with open(lock_path, "w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)  # one hand-over at a time
            if "--quiet" in flags:
                sys.stdout = open(os.devnull, "w")
            return sync("--released" in flags)
    except Refused as exc:
        print(f"telegram-reader: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
