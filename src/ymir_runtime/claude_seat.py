"""claude_seat — what a Claude Code worker needs to start with no human click.

Measured 2026-11-20 on the dev machine: Claude workers sat on three kinds of screen
that nobody was watching.

* The model: `claude --model claude/claude-opus-5-5` answers "There's an issue with
  the selected model" and waits. Claude takes a bare id or an alias, never a
  provider/model token. The bare name comes from the allow-list (allow.py), so the
  seat and the policy name the model the same way.
* The trust dialog: Claude asks "Yes, I trust this folder" in any folder whose
  entry in `~/.claude.json` lacks `hasTrustDialogAccepted`. A worktree under a
  project that was never opened by hand is such a folder. `trust()` marks one seat
  folder, under a lock, with an atomic replace that keeps every other key. It
  never marks `$HOME` or `/`: trusting the home trusts every folder below it.
* Permission dialogs: a tool outside the profile's allow list stops the worker at
  a dialog. The seat runs in `dontAsk` mode (an unlisted tool is denied and the
  worker carries on), with the shipped profile's allow and deny lists, plus one
  allow entry per MCP server Claude is configured with. Hooks are untouched.

`classify()` reads a pane and names what the worker is stuck on, so the seat check
in bin/seat/herdr-run.sh can call a stuck seat FAILED with its reason.

CLI (bin/seat/claude-seat.sh is its door):
  claude_seat.py trust <dir>
  claude_seat.py settings <profile.json> <seat-cwd> <out.json>
  classify < pane-text            -> prints `<state>\t<reason>`
"""

from __future__ import annotations

import contextlib
import fcntl
import json
import os
import re
import sys
import tempfile
import time
from pathlib import Path
from typing import Iterator, Mapping

EXIT_OK, EXIT_FAULT, EXIT_USAGE, EXIT_REFUSED = 0, 1, 2, 3


# ── trust ────────────────────────────────────────────────────────────────────────


def config_path(env: Mapping[str, str] | None = None) -> Path:
    environ = env if env is not None else os.environ
    explicit = environ.get("CLAUDE_CONFIG_FILE", "")
    if explicit:
        return Path(explicit)
    return Path(environ.get("HOME", str(Path.home()))) / ".claude.json"


@contextlib.contextmanager
def _locked(target: Path, timeout: float = 10.0) -> Iterator[None]:
    """One writer at a time among the house's own writers of ~/.claude.json."""
    lock = target.with_name(target.name + ".ymir-lock")
    fd = os.open(str(lock), os.O_CREAT | os.O_RDWR, 0o600)
    try:
        deadline = time.monotonic() + timeout
        while True:
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() > deadline:
                    raise TimeoutError(f"could not lock {lock} within {timeout:.0f}s")
                time.sleep(0.1)
        yield
    finally:
        os.close(fd)


def _write_atomic(target: Path, data: dict) -> None:
    fd, tmp = tempfile.mkstemp(prefix=target.name + ".ymir.", dir=str(target.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=2, ensure_ascii=False)
            fh.write("\n")
            fh.flush()
            os.fsync(fh.fileno())
        os.chmod(tmp, 0o600)
        os.replace(tmp, target)
    except BaseException:
        with contextlib.suppress(FileNotFoundError):
            os.unlink(tmp)
        raise


def _is_trusted(data: dict, key: str) -> bool:
    entry = (data.get("projects") or {}).get(key)
    return isinstance(entry, dict) and entry.get("hasTrustDialogAccepted") is True


def trust(folder: str | Path, env: Mapping[str, str] | None = None) -> str:
    """Mark one seat folder trusted. Returns 'already', 'marked'; raises ValueError on refusal."""
    environ = env if env is not None else os.environ
    path = Path(folder).expanduser()
    if not path.is_absolute():
        raise ValueError(f"'{folder}' is not an absolute path")
    path = Path(os.path.realpath(path))
    home = Path(os.path.realpath(environ.get("HOME", str(Path.home()))))
    if path == home or path == Path("/") or home.is_relative_to(path):
        raise ValueError(
            f"refusing to trust {path}: it is the home or above it, and trusting it would trust every folder below"
        )
    if not path.is_dir():
        raise ValueError(f"{path} is not a folder")
    target = config_path(environ)
    key = str(path)
    with _locked(target):
        # Claude rewrites this file from its own memory; a write it makes between our
        # read and our replace can drop our key. So verify, and apply once more.
        for _attempt in range(3):
            data = json.loads(target.read_text(encoding="utf-8")) if target.exists() else {}
            if not isinstance(data, dict):
                raise ValueError(f"{target} is not a JSON object — not touched")
            if _is_trusted(data, key):
                return "already" if _attempt == 0 else "marked"
            projects = data.setdefault("projects", {})
            entry = projects.setdefault(key, {})
            entry.setdefault("allowedTools", [])
            entry["hasTrustDialogAccepted"] = True
            _write_atomic(target, data)
            time.sleep(0.05)
        reread = json.loads(target.read_text(encoding="utf-8"))
        if _is_trusted(reread, key):
            return "marked"
    raise ValueError(f"{key} was marked three times and lost each time — a Claude process keeps rewriting {target}")


# ── settings ─────────────────────────────────────────────────────────────────────

_SERVER_NAME = re.compile(r"[^A-Za-z0-9_-]")


def mcp_servers(seat_cwd: str | Path, env: Mapping[str, str] | None = None) -> list[str]:
    """The MCP server names Claude will load in this folder: user scope, project scope, .mcp.json."""
    names: set[str] = set()
    target = config_path(env)
    try:
        data = json.loads(target.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        data = {}
    names.update((data.get("mcpServers") or {}).keys())
    cwd = Path(os.path.realpath(seat_cwd))
    for key, entry in (data.get("projects") or {}).items():
        if isinstance(entry, dict) and (cwd == Path(key) or cwd.is_relative_to(Path(key))):
            names.update((entry.get("mcpServers") or {}).keys())
    for parent in (cwd, *cwd.parents):
        mcp_json = parent / ".mcp.json"
        if mcp_json.is_file():
            with contextlib.suppress(OSError, ValueError):
                names.update((json.loads(mcp_json.read_text(encoding="utf-8")).get("mcpServers") or {}).keys())
            break
    return sorted(_SERVER_NAME.sub("_", n) for n in names if n)


def settings(profile: str | Path, seat_cwd: str | Path, env: Mapping[str, str] | None = None) -> dict:
    """The shipped worker profile, plus an allow entry for each configured MCP server."""
    base = json.loads(Path(profile).read_text(encoding="utf-8"))
    perms = base.setdefault("permissions", {})
    allow = list(perms.get("allow") or [])
    for name in mcp_servers(seat_cwd, env):
        rule = f"mcp__{name}"
        if rule not in allow:
            allow.append(rule)
    perms["allow"] = allow
    perms["defaultMode"] = "dontAsk"
    return base


# ── classify a pane ──────────────────────────────────────────────────────────────

# A dialog is a fault only when it is ON SCREEN NOW: its words and a numbered option
# line ("❯ 1. Yes …") both sit in the last lines of the pane. A reply is a fault only
# when Claude printed it (a line led by its reply or result marker), never when the
# words are part of the brief echoed above — a brief about these faults quotes them.
_DIALOGS: tuple[tuple[str, str, re.Pattern[str]], ...] = (
    ("trust", "the trust dialog is open", re.compile(
        r"trust this folder|Do you trust the files|Yes, I trust|Is this a project you trust", re.I)),
    ("confirm", "a model-switch confirmation is open", re.compile(
        r"Yes, switch to|switch to (Opus|Sonnet|Haiku|Fable)\?|Switch model\?", re.I)),
    ("permission", "a permission dialog is open", re.compile(
        r"Do you want to (proceed|make this edit|create|allow|run)|Allow this (tool|command)|"
        r"don't ask again for", re.I)),
)
_OPTION = re.compile(r"^\s*(❯|>)?\s*\d\.\s+\S")
_REPLIES: tuple[tuple[str, str, re.Pattern[str]], ...] = (
    ("model", "Claude refused the model", re.compile(
        r"issue with the selected model|model .{0,40}(not found|does not exist|not available)|invalid model", re.I)),
    ("login", "Claude is not signed in", re.compile(
        r"Please run /login|Invalid API key|OAuth token has expired|Not logged in", re.I)),
)
_REPLY_LINE = re.compile(r"^\s*(⏺|⎿|✗|●|Error:|API Error)")

# What a Claude pane shows once the worker has done anything: a spinner with its
# interrupt hint, or a tool line.
_WORKING = re.compile(r"esc to interrupt|\b(Bash|Read|Update|Write|Edit|Grep|Glob|Search)\(")


def classify(text: str, state: str = "") -> tuple[str, str]:
    """Name what the pane shows: ('ok', why) or ('<fault>', reason)."""
    lines = [ln for ln in text.splitlines() if ln.strip()]
    bottom = lines[-18:]
    if any(_OPTION.match(ln) for ln in bottom):
        joined = "\n".join(bottom)
        for name, reason, pattern in _DIALOGS:
            if pattern.search(joined):
                return name, reason
    for ln in lines[-40:]:
        if _REPLY_LINE.match(ln):
            for name, reason, pattern in _REPLIES:
                if pattern.search(ln):
                    return name, reason
    if state == "working" or _WORKING.search("\n".join(lines[-40:])):
        return "ok", "the worker is working"
    if state in ("done", "idle") and any(ln.lstrip()[:1] in ("⏺", "●") for ln in lines[-40:]):
        return "ok", f"the worker answered (herdr state '{state}')"
    return "empty", f"no sign of work (herdr state '{state or 'unknown'}') — the brief did not land"


# ── CLI ──────────────────────────────────────────────────────────────────────────


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__.split("CLI (")[1].split("\n", 1)[1].rstrip() if "CLI (" in (__doc__ or "") else "")
        return EXIT_OK if argv else EXIT_USAGE
    cmd, rest = argv[0], argv[1:]
    try:
        if cmd == "trust" and len(rest) == 1:
            print(f"{trust(rest[0])}\t{os.path.realpath(rest[0])}")
            return EXIT_OK
        if cmd == "settings" and len(rest) == 3:
            data = settings(rest[0], rest[1])
            Path(rest[2]).parent.mkdir(parents=True, exist_ok=True)
            Path(rest[2]).write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
            print(rest[2])
            return EXIT_OK
        if cmd == "classify":
            state = rest[0] if rest else ""
            name, reason = classify(sys.stdin.read(), state)
            print(f"{name}\t{reason}")
            return EXIT_OK
    except ValueError as exc:
        print(f"refused: {exc}", file=sys.stderr)
        return EXIT_REFUSED
    except (OSError, TimeoutError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return EXIT_FAULT
    print("usage: claude_seat.py trust <dir> | settings <profile> <seat-cwd> <out> | classify [state] < text",
          file=sys.stderr)
    return EXIT_USAGE


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
