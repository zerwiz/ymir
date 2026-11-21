"""role_config — which harness and model each ROLE runs, and whether its seat runs unattended.

The Allfather, 2026-11-21: *"we also want to be able to run more types of models for judges and
coders. That must be able to tune for the users."* and, of the permission posture, *"make yolo REAL
and tunable per user"*.

A role is a job, not a person: `judge`, `coder`, `scout`, `helm`. The operator's home
(`config/agents.yaml`, with a per-machine overlay `config/agents.<host>.yaml`) declares, per role,
an ORDERED list of `harness:model` choices and, optionally, the role's yolo posture:

    roles:
      judge: [claude:opus, pi:opencode-go/deepseek-v4.1-flash]
      coder:
        choose: [claude:sonnet, pi:opencode-go/beam-free, pi:llamacpp-host/some-model]
        yolo: on
    yolo: { default: off }            # roles without a yolo of their own take this

THE LAW OF THE LIST. The first choice this seat can serve wins. A choice it cannot serve is
SKIPPED AND NAMED (the reason travels with the answer), never silently replaced; a list with no
servable choice is a refusal that names every choice and why it failed. An explicit
`--harness/--model` from the caller still wins over the whole list.

A machine's overlay replaces a role's declaration as a whole (its list, and its yolo if it names
one); roles the overlay does not name keep the fleet's.

YOLO. `on` means the worker runs unattended with no permission prompts. On Claude that is permission
mode `bypassPermissions` — the profile's deny rules still apply (they fence merging, pushing to
main and leaking tokens); `off` is `dontAsk` with the profile's allow list. Pi and opencode already
run allow-all (they have no allow list), so the posture there is reported, not tightened.
The house default is ON for the coder (RULES/08: the judge merges, so the coder works freely) and
OFF for every other role. Order of authority: an explicit flag, the machine overlay, the fleet row,
the house default.

CLI (bin/model/role-model.sh is its door):
  role_config.py model <role> [--explain]            -> harness<TAB>model<TAB>index<TAB>skipped
  role_config.py choices <role>                      -> harness<TAB>model, one per line
  role_config.py yolo <role> [on|off]                -> on|off<TAB>source
  role_config.py check                               -> every role resolved, or the choice that failed
"""

from __future__ import annotations

import os
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Mapping, Sequence

try:  # PyYAML is how the home's YAML is read everywhere in the house
    import yaml  # type: ignore[import-untyped]
except ImportError:  # pragma: no cover - the doors that call this need it anyway
    yaml = None

ROLES = ("judge", "coder", "scout", "helm")
HARNESSES = ("claude", "pi", "opencode")
# House defaults: the coder works unattended (RULES/08 — the judge, not the coder, answers for a
# merge); everything else asks nothing of a hand only if the operator says so.
HOUSE_YOLO = {"coder": True}
CLAUDE_MODE_YOLO = "bypassPermissions"
CLAUDE_MODE_SAFE = "dontAsk"

EXIT_OK, EXIT_FAULT, EXIT_USAGE, EXIT_REFUSED = 0, 1, 2, 3


class Refused(Exception):
    """No choice for a role can be served here; `skipped` names each choice and why."""

    def __init__(self, message: str, skipped: Sequence[tuple[str, str]] = ()) -> None:
        super().__init__(message)
        self.skipped = list(skipped)


@dataclass(frozen=True)
class Choice:
    harness: str
    model: str

    def __str__(self) -> str:
        return f"{self.harness}:{self.model}"


@dataclass
class Resolved:
    role: str
    choice: Choice
    index: int
    skipped: list[tuple[str, str]] = field(default_factory=list)


# ── parsing ──────────────────────────────────────────────────────────────────────


def parse_choice(text: object) -> Choice:
    """`claude:opus` or `pi:opencode-go/model` -> Choice. A choice without a harness is refused:
    the harness is part of the promise (a pi id handed to Claude fails later and further away)."""
    raw = str(text).strip()
    harness, sep, model = raw.partition(":")
    harness, model = harness.strip().lower(), model.strip()
    if not sep or harness not in HARNESSES or not model:
        raise ValueError(f"'{raw}' is not a choice — write it harness:model, harness one of {', '.join(HARNESSES)}")
    return Choice(harness, model)


def _read_yaml(path: Path) -> dict:
    if yaml is None or not path.is_file():
        return {}
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except (OSError, ValueError, yaml.YAMLError):
        return {}
    return data if isinstance(data, dict) else {}


def load(settings_dir: str | Path, host: str = "") -> dict:
    """The role declarations, the overlay replacing the fleet's PER ROLE. Returns
    {'roles': {role: {'choose': [...], 'yolo': bool|None}}, 'yolo_default': bool|None}."""
    base = Path(settings_dir)
    layers = [("fleet", _read_yaml(base / "agents.yaml"))]
    if host:
        layers.append(("overlay", _read_yaml(base / f"agents.{host}.yaml")))
    roles: dict[str, dict] = {}
    yolo_default: bool | None = None
    for label, cfg in layers:
        yd = (cfg.get("yolo") or {}).get("default") if isinstance(cfg.get("yolo"), dict) else None
        if yd is not None:
            yolo_default = _truthy(yd)
        for name, row in (cfg.get("roles") or {}).items():
            if isinstance(row, (list, tuple)):
                row = {"choose": list(row)}
            if not isinstance(row, dict):
                continue
            current = roles.setdefault(str(name), {"choose": [], "yolo": None, "source": label})
            if "choose" in row:
                current["choose"] = list(row.get("choose") or [])
                current["source"] = label
            if "yolo" in row and row["yolo"] is not None:
                current["yolo"] = _truthy(row["yolo"])
                current["yolo_source"] = label
    return {"roles": roles, "yolo_default": yolo_default}


def _truthy(value: object) -> bool:
    if isinstance(value, bool):
        return value
    return str(value).strip().lower() in ("on", "true", "yes", "1")


def choices(cfg: Mapping, role: str) -> list[Choice]:
    row = (cfg.get("roles") or {}).get(role)
    if not row or not row.get("choose"):
        raise Refused(
            f"the home declares no choices for role '{role}' — add `roles: {{{role}: [harness:model, …]}}` "
            "to config/agents.yaml (see config/agents.yaml.example)"
        )
    return [parse_choice(c) for c in row["choose"]]


# ── resolution ───────────────────────────────────────────────────────────────────

CanServe = Callable[[Choice], "tuple[bool, str]"]


def resolve(cfg: Mapping, role: str, can_serve: CanServe) -> Resolved:
    """The first choice this seat can serve. Skipped choices are kept, with their reasons."""
    skipped: list[tuple[str, str]] = []
    for index, choice in enumerate(choices(cfg, role)):
        ok, why = can_serve(choice)
        if ok:
            return Resolved(role, choice, index, skipped)
        skipped.append((str(choice), why))
    named = "; ".join(f"{c} ({w})" for c, w in skipped)
    raise Refused(f"no choice for role '{role}' can be served on this seat — {named}", skipped)


def resolve_yolo(cfg: Mapping, role: str, explicit: str | None = None) -> tuple[bool, str]:
    """(on?, where it came from): flag, the role's own row (overlay over fleet), the home's
    `yolo.default`, then the house default."""
    if explicit in ("on", "off"):
        return explicit == "on", "explicit flag (--yolo)"
    row = (cfg.get("roles") or {}).get(role) or {}
    if row.get("yolo") is not None:
        return bool(row["yolo"]), f"{row.get('yolo_source', 'fleet')} roles.{role}.yolo"
    if cfg.get("yolo_default") is not None:
        return bool(cfg["yolo_default"]), "config yolo.default"
    if role in HOUSE_YOLO:
        return HOUSE_YOLO[role], "house default (the coder works unattended; the judge merges — RULES/08)"
    return False, "house default (off: the allow list holds)"


def claude_permission_mode(yolo: bool) -> str:
    """Claude's permission mode for the posture. Deny rules in the profile hold in both."""
    return CLAUDE_MODE_YOLO if yolo else CLAUDE_MODE_SAFE


def posture(harness: str, yolo: bool) -> str:
    """One line saying which posture took effect, for the spawn to print."""
    if harness == "claude":
        mode = claude_permission_mode(yolo)
        return (f"yolo {'on' if yolo else 'off'}: claude permission mode {mode}, "
                + ("no prompts; every deny rule in the profile still holds" if yolo
                   else "allow list only; an unlisted tool is denied"))
    if harness in ("pi", "pi-signed", "opencode"):
        return (f"yolo {'on' if yolo else 'off'}: {harness} runs allow-all in both postures "
                "(it has no allow list); the worktree and the wards are the fence")
    return f"yolo {'on' if yolo else 'off'}: harness '{harness}' has no posture switch here"


# ── what this seat can serve ─────────────────────────────────────────────────────


def tree_root() -> Path:
    return Path(__file__).resolve().parents[2]


def seat_can_serve(choice: Choice, root: Path | None = None) -> tuple[bool, str]:
    """Ask the doors that already know: the catalogue for pi, the allow-list for claude and opencode."""
    base = root or tree_root()

    def run(*argv: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(argv, capture_output=True, text=True, timeout=120, cwd=str(base))

    try:
        if choice.harness == "claude":
            out = run("bash", str(base / "bin/seat/claude-seat.sh"), "model", choice.model)
            return (out.returncode == 0, "" if out.returncode == 0 else "Claude's allow-list does not serve it")
        allow = run("bash", str(base / "bin/model/model-allow.sh"), "check", choice.model, "--harness", choice.harness)
        if allow.returncode != 0:
            return False, "the operator's allow-list refuses it"
        if choice.harness == "pi" or choice.model.split("/", 1)[0].startswith("llama"):
            cat = run("bash", str(base / "bin/model/catalog.sh"), "--has", choice.model)
            if cat.returncode != 0:
                return False, "this seat's catalogue does not list it"
        return True, ""
    except (OSError, subprocess.TimeoutExpired) as exc:
        return False, f"could not ask the door ({exc})"


def settings_dir(environ: Mapping[str, str] | None = None, root: Path | None = None) -> Path:
    environ = environ if environ is not None else os.environ
    explicit = environ.get("YMIR_SETTINGS_DIR_OVERRIDE") or environ.get("YMIR_ROLES_DIR")
    if explicit:
        return Path(explicit)
    base = root or tree_root()
    out = subprocess.run(
        ["bash", "-c", f'. "{base}/bin/vault/hoard-lib.sh" && hoard_settings_dir S && printf %s "$S"'],
        capture_output=True, text=True, timeout=30,
    )
    return Path(out.stdout.strip()) if out.returncode == 0 and out.stdout.strip() else base / "config"


def host_name() -> str:
    return os.environ.get("YMIR_HOST_OVERRIDE") or (os.uname().nodename.split(".")[0] if hasattr(os, "uname") else "")


# ── CLI ──────────────────────────────────────────────────────────────────────────


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print((__doc__ or "").split("CLI (", 1)[-1].split("\n", 1)[-1].rstrip())
        return EXIT_OK if argv else EXIT_USAGE
    cmd, rest = argv[0], argv[1:]
    cfg = load(settings_dir(), host_name())
    try:
        if cmd == "choices" and len(rest) == 1:
            for c in choices(cfg, rest[0]):
                print(f"{c.harness}\t{c.model}")
            return EXIT_OK
        if cmd == "model" and rest:
            res = resolve(cfg, rest[0], seat_can_serve)
            skipped = " | ".join(f"{c}: {w}" for c, w in res.skipped)
            print(f"{res.choice.harness}\t{res.choice.model}\t{res.index}\t{skipped}")
            for c, w in res.skipped:
                print(f"role-model: skipped {c} for {rest[0]} — {w}", file=sys.stderr)
            return EXIT_OK
        if cmd == "yolo" and rest:
            on, source = resolve_yolo(cfg, rest[0], rest[1] if len(rest) > 1 else None)
            print(f"{'on' if on else 'off'}\t{source}")
            return EXIT_OK
        if cmd == "check":
            bad = 0
            for role in sorted(set(ROLES) | set(cfg["roles"])):
                try:
                    res = resolve(cfg, role, seat_can_serve)
                    on, _ = resolve_yolo(cfg, role)
                    print(f"ok   {role:<6} {res.choice} (choice {res.index + 1}, yolo {'on' if on else 'off'})")
                    for c, w in res.skipped:
                        print(f"     skipped {c}: {w}")
                except Refused as exc:
                    bad += 1
                    print(f"FAIL {role:<6} {exc}")
            return EXIT_FAULT if bad else EXIT_OK
    except Refused as exc:
        print(f"refused: {exc}", file=sys.stderr)
        return EXIT_REFUSED
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return EXIT_FAULT
    print("usage: role_config.py model <role> | choices <role> | yolo <role> [on|off] | check", file=sys.stderr)
    return EXIT_USAGE


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
