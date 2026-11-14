#!/usr/bin/env python3
"""warden-policy.py — the ONE reader of a machine's wardens.yaml, and of what a warden may touch.

Plan 290 §3. A clock and a warden belong to ONE named machine: it is installed only there, judged
only there, and acts with that machine's own identity. This file answers the four questions every
outward door asks before it acts, and answers them the same way for all of them:

    may this door run here?      `on`            → the machine's own file says on
    is this repository ours?     projects.yaml  → the operator's registry lists it
    whose name does it act as?   `identity`      → the name the machine gives that duty
    may it merge?                `merge`         → on, AND the door may merge, AND merge-verdict yes

Nothing here decides a policy of its own: it reads `$YMIR_HOME/config/machines/<machine>/wardens.yaml`
and the operator's registry. A machine with no file has every seated door OFF — that is the point of
an opt-in (a collaborator's fresh install starts with all of them off), and it is why `on` absent is
`off`, never `on`.

The file's shape (one block per door, top level; the machine-wide scalars are reserved keys):

    identity: <name>            # OPTIONAL machine-wide default for every door that names none
    token_ref: <VAULT_KEY>      # OPTIONAL machine-wide default for the token each door acts with

    queue-warden:
      enabled: off              # opt-in. on|off. absent = off.
      merge: off                # only the fleet's heart may say on (RULES/08, plan 290 P1)
      max_open_prs: 5           # door-specific keys, read by the door itself
      identity: <machine>-queue-warden
      token_ref: GITHUB_TOKEN_QUEUE_WARDEN

(The key is `enabled`, never a bare `on:`: YAML 1.1 — which pyyaml and many other parsers still
implement — reads the KEY `on` as the boolean true, so `on: on` becomes `{True: True}` and every
reader silently sees no policy at all. A key a parser can eat is not a key.)

Precedence, and no third opinion: the door's own key, then the machine-wide default, then the door's
documented default. A door that is not in the register below is not an outward door and is never
gated (the door still keeps every other law of the house).

    warden-policy.py machine                 # this machine, the heart, and whether this is the heart
    warden-policy.py get <door> <key> [--default V]
    warden-policy.py on <door>               # exit 0 when this machine seats the door
    warden-policy.py doors                   # the outward register, resolved for this machine
    warden-policy.py identity <door>         # the name the machine gives that duty (may be empty)
    warden-policy.py owns <owner/repo>       # exit 0 when the operator's registry lists it
    warden-policy.py repos                   # every repository the operator's registry claims

Exit: 0 yes · 1 no (the answer is no, and that is not an error) · 2 usage or a file that cannot be read.
"""
from __future__ import annotations

import json
import os
import socket
import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # the policy is YAML; without a parser nothing can be judged
    print("warden-policy: python3-yaml is required to read wardens.yaml", file=sys.stderr)
    sys.exit(2)

# The outward register. `seat` is how a door comes to be running on a machine: `timer` and `cron`
# are seated by install/update and are gated by `on`; `hand` is a door a person invokes now, so it
# is never seated and never held off — it is gated by the repository, the identity and the record.
DOORS = {
    "queue-warden":  {"seat": "timer", "about": "queue hygiene — cap, stale, re-cut; a merge only where a machine may merge"},
    "review-watch":  {"seat": "timer", "about": "raises an ask for every unjudged open PR"},
    "review-seat":   {"seat": "timer", "about": "keeps the reviewer's herdr seat alive"},
    "review-loop":   {"seat": "timer", "about": "judges the review shelf"},
    "pr-watch":      {"seat": "timer", "about": "tells the operator a PR arrived"},
    "issue-watch":   {"seat": "timer", "about": "tells the operator an issue arrived"},
    "ship-watch":    {"seat": "timer", "about": "settles and ships proved PRs"},
    "gna-mail":      {"seat": "cron",  "about": "imports the desk's mail"},
    "snotra-mail":   {"seat": "cron",  "about": "reads the meeting letters' replies"},
    "git-sync":      {"seat": "cron",  "about": "keeps the record in step with its remote"},
    "private-scan":  {"seat": "cron",  "about": "sweeps the tree for private material and files a triage"},
    "gather":        {"seat": "hand",  "about": "gathers errand branches into one push and one PR"},
    "ship":          {"seat": "hand",  "about": "ships proved work to its remote"},
    "mjollnir":      {"seat": "hand",  "about": "issue to worktree to PR"},
}

RESERVED = ("identity", "token_ref")
ON_VALUES = {"on", "yes", "true", "1"}
OFF_VALUES = {"off", "no", "false", "0", ""}


# ── the home, the machine, the heart ────────────────────────────────────────
def ymir_home() -> Path:
    env = os.environ.get("YMIR_HOME")
    if env:
        return Path(env).expanduser()
    home = Path(os.environ.get("HOME", "~")).expanduser()
    rec = Path(os.environ.get("XDG_CONFIG_HOME") or home / ".config") / "ymir" / "home"
    try:
        first = rec.read_text(encoding="utf-8").splitlines()[0].strip()
        if first:
            return Path(first).expanduser()
    except (OSError, IndexError):
        pass
    return home / "Documents" / "ymirhome"


def fleet_registry(home: Path) -> dict:
    path = Path(os.environ.get("YMIR_FLEET_REGISTRY") or home / "hodd" / "data" / "fleet.json")
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def machine_name(home: Path) -> str:
    """This machine's name, as the fleet registry spells it. Never a second table."""
    explicit = os.environ.get("YMIR_MACHINE") or os.environ.get("YMIR_HOST")
    raw = explicit or socket.gethostname().split(".")[0]
    name = raw.strip().lower()
    hosts = (fleet_registry(home).get("hosts") or {})
    if hosts and raw not in hosts:
        for key in hosts:  # an alias the registry knows (a hostname with a domain, a renamed box)
            if key.lower() == name:
                return key
    return raw


def heart_name(home: Path) -> str:
    return str(fleet_registry(home).get("heart") or "")


# ── the machine's file ──────────────────────────────────────────────────────
def policy_path(home: Path, machine: str) -> Path:
    return Path(os.environ.get("YMIR_WARDENS_FILE") or home / "config" / "machines" / machine / "wardens.yaml")


def load_policy(home: Path, machine: str) -> tuple[dict, str]:
    """The parsed file, and a one-line verdict about where it came from.

    A file that exists but cannot be parsed is NOT an empty policy that silently answers "off":
    it is reported, and the caller sees an empty policy with a loud remark, so a broken file is
    visible in the door's own output rather than mistaken for a machine that named nothing.
    """
    path = policy_path(home, machine)
    if not path.exists():
        return {}, f"no wardens.yaml for {machine} ({path}) — every seated door is off"
    try:
        doc = yaml.safe_load(path.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as exc:
        return {}, f"{path} cannot be read ({exc.__class__.__name__}) — treated as 'no door named'"
    if doc is None:
        return {}, f"{path} is empty — every seated door is off"
    if not isinstance(doc, dict):
        return {}, f"{path} is not a mapping — every seated door is off"
    return doc, str(path)


# A door's opt-in key is `enabled`. `on` is also READ, because a file written before this reader
# shipped used it and a policy that vanishes is worse than an old spelling; `True` is read for the
# same reason — YAML 1.1 parses a bare `on:` key as the boolean true.
ON_KEYS = ("enabled", "on", True)


def door_block(doc: dict, door: str) -> dict:
    block = doc.get(door)
    if isinstance(block, dict):
        return block
    if isinstance(block, (str, bool)):  # `queue-warden: on` — the shortest legal way to name one door
        return {"enabled": block}
    return {}


def raw_get(doc: dict, door: str, key: str):
    """The door's own value, then the machine-wide default. An empty value names nothing."""
    block = door_block(doc, door)
    if norm(block.get(key)) != "":
        return block[key]
    if key in RESERVED and norm(doc.get(key)) != "":
        return doc[key]
    return None


def norm(value) -> str:
    if value is None:
        return ""
    if isinstance(value, bool):
        return "on" if value else "off"
    return str(value).strip()


def get(doc: dict, door: str, key: str, default: str = "") -> str:
    value = norm(raw_get(doc, door, key))
    if value == "" and key not in RESERVED:
        return default
    return value if value != "" else default


def door_on(doc: dict, door: str) -> tuple[bool, str]:
    seat = (DOORS.get(door) or {}).get("seat")
    if seat == "hand":
        return True, "a door a hand invokes — never seated, so never held off"
    if seat is None:
        return True, "not an outward door"
    value = ""
    for key in ON_KEYS:
        value = norm(raw_get(doc, door, key)).lower()
        if value:
            break
    if value in ON_VALUES:
        return True, f"{door}.enabled: on"
    if value in OFF_VALUES:
        return False, (f"{door}.enabled is absent — a door is seated only where the operator names it (plan 290)"
                       if value == "" else f"{door}.enabled: off")
    return False, f"{door}.enabled: {value} (not a value this reader knows — read as off)"


# ── the operator's registry ─────────────────────────────────────────────────
def registry_path(home: Path) -> Path:
    return Path(os.environ.get("PROJECTS_YAML") or home / "hodd" / "identity" / "projects.yaml")


def owned_repos(home: Path) -> tuple[set[str], str]:
    """Every `owner/repo` the operator's registry claims, lowercased, and the path it came from."""
    path = registry_path(home)
    try:
        doc = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except (OSError, yaml.YAMLError) as exc:
        return set(), f"{path} does not answer ({exc.__class__.__name__})"
    found: set[str] = set()
    for row in (doc.get("projects") or []):
        if not isinstance(row, dict):
            continue
        git = row.get("git") or {}
        owner, repo = norm(git.get("owner")), norm(git.get("repo"))
        if owner and repo:
            found.add(f"{owner}/{repo}".lower())
    return found, str(path)


def owns(home: Path, target: str) -> tuple[bool, str]:
    target = target.strip().strip("/")
    if target.endswith(".git"):
        target = target[:-4]
    repos, source = owned_repos(home)
    if not repos:
        return False, f"no repository is this operator's — {source} lists none"
    if target.lower() in repos:
        return True, f"{target} is in {source}"
    return False, f"{target} is not in {source} — an outward act touches only the operator's own repositories"


# ── output ─────────────────────────────────────────────────────────────────
def toon_rows(name: str, rows: list[tuple[str, ...]], cols: list[str]) -> str:
    out = [f"{name}[{len(rows)}]{{{','.join(cols)}}}:"
           if rows else f"{name}: none"]
    for row in rows:
        out.append("  " + ",".join('"%s"' % str(c).replace('"', "'") for c in row))
    return "\n".join(out)


def main(argv: list[str]) -> int:
    argv = list(argv)
    default = ""
    if "--default" in argv:
        i = argv.index("--default")
        default = argv[i + 1] if i + 1 < len(argv) else ""
        del argv[i:i + 2]
    args = [a for a in argv if not a.startswith("--")]
    if not args or args[0] in ("-h", "--help", "help"):
        print(__doc__.strip())
        return 0 if args else 2
    verb = args[0]
    home = ymir_home()
    machine = machine_name(home)
    doc, source = load_policy(home, machine)
    heart = heart_name(home)

    if verb == "machine":
        print(toon_rows("machine", [(machine, heart, "yes" if machine == heart else "no", source)],
                        ["machine", "heart", "is_heart", "policy"]))
        return 0

    if verb == "name":  # one field, for a shell caller that should not parse a table
        print(machine)
        return 0

    if verb == "heart":
        print(heart)
        return 0

    if verb == "source":
        print(source)
        return 0

    if verb == "get":
        if len(args) < 3:
            print("usage: warden-policy.py get <door> <key> [--default V]", file=sys.stderr)
            return 2
        print(get(doc, args[1], args[2], default))
        return 0

    if verb in ("on", "seated"):
        if len(args) < 2:
            print("usage: warden-policy.py on <door>", file=sys.stderr)
            return 2
        ok, why = door_on(doc, args[1])
        # the reason always travels with the answer: a refusal that names nothing is a mystery
        print(why, file=sys.stderr)
        return 0 if ok else 1

    if verb == "identity":
        if len(args) < 2:
            print("usage: warden-policy.py identity <door>", file=sys.stderr)
            return 2
        print(get(doc, args[1], "identity", ""))
        return 0

    if verb == "seat-plan":
        # name<TAB>seat<TAB>on|off — what the seater (bin/engine/units.py) reads for every outward door,
        # so seating and acting are decided by one parser and cannot disagree.
        for door, meta in DOORS.items():
            ok, _why = door_on(doc, door)
            print(f"{door}\t{meta['seat']}\t{'on' if ok else 'off'}")
        return 0

    if verb == "doors":
        rows = []
        for door, meta in DOORS.items():
            ok, why = door_on(doc, door)
            rows.append((door, meta["seat"], "on" if ok else "off",
                         get(doc, door, "identity", "") or "-",
                         get(doc, door, "token_ref", "") or "-",
                         get(doc, door, "merge", "off").lower(),
                         why))
        print(toon_rows("wardens", rows,
                        ["door", "seat", "on", "identity", "token_ref", "merge", "why"]))
        print(f"# machine {machine} · heart {heart or '-'} · {source}")
        return 0

    if verb == "owns":
        if len(args) < 2:
            print("usage: warden-policy.py owns <owner/repo>", file=sys.stderr)
            return 2
        ok, why = owns(home, args[1])
        print(why, file=sys.stderr)
        return 0 if ok else 1

    if verb == "repos":
        repos, source = owned_repos(home)
        print(toon_rows("repos", [(r,) for r in sorted(repos)], ["repo"]))
        print(f"# {source}")
        return 0 if repos else 1

    print(f"warden-policy: unknown verb {verb}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
