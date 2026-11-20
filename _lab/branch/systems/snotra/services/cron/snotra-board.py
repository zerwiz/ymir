#!/usr/bin/env python3
"""snotra-board — a place declares a board; this door makes it, once.

WHY: a place profile names a board and its lists, and until that board exists the first projection fails.
Making it by hand is how two boards end up with the same name (measured 2026-10-22: a second "Control Tower"
was created) — so a declaration should be executable, idempotent, and refuse to guess.

WHAT IT DOES
    check  <place>          is the board there? does it hold the lists and labels the place names?
    ensure <place>          create what is missing: the board (in the workspace's organisation), its lists,
                            its labels — never a duplicate, never a rename
    show   [<place>]        the places this home declares

THE LAWS
    * a board is found by NAME in the map (`trello-map.yaml`); a name that exists is never created again;
    * a list that exists is never renamed (a profile that renames silently files cards nowhere);
    * the board is created private, in the organisation the other boards already belong to — never in a
      random workspace;
    * `ensure` prints what it created and what it left alone, and re-reads the board to prove it.
"""
from __future__ import annotations

import sys
from pathlib import Path

for _svc in ("record", "cron"): sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "services" / _svc))
import trello_client as T  # noqa: E402


def die(msg: str, code: int = 1):
    print(f"snotra-board: {msg}", file=sys.stderr)
    raise SystemExit(code)


def say(msg: str):
    print(msg, flush=True)


def load_yaml(path: Path) -> dict:
    try:
        import yaml  # noqa: PLC0415
    except Exception:  # noqa: BLE001
        die("PyYAML is missing: pip install pyyaml")
    return yaml.safe_load(path.read_text(encoding="utf-8")) or {}


def places() -> list[Path]:
    return sorted((T.home_dir() / "hodd" / "identity" / "places").glob("*/*/place.yaml"))


def place_file(ref: str) -> Path:
    p = Path(ref).expanduser()
    if p.is_file():
        return p
    cand = T.home_dir() / "hodd" / "identity" / "places" / ref / "place.yaml"
    if cand.is_file():
        return cand
    have = ", ".join(str(x.relative_to(T.home_dir() / "hodd" / "identity" / "places")) for x in places()) or "none"
    die(f"no place at {ref!r} — the home declares: {have}")


def board_in_map(name: str) -> dict | None:
    q = (name or "").strip().lower()
    for b in T.load_map().get("boards") or []:
        if (b.get("name") or "").strip().lower() == q:
            return b
    return None


def org_of_house() -> str | None:
    for b in T.load_map().get("boards") or []:
        try:
            bid = T.board_id_of(b["name"])
            o = T.api("GET", f"/boards/{bid}/organization", {"fields": "id"})
            if o.get("id"):
                return o["id"]
        except SystemExit:
            continue
    return None


def board_in_org(name: str) -> dict | None:
    """A board that exists in Trello but is not in the map yet — the duplicate a door must never make."""
    org = org_of_house()
    if not org:
        return None
    q = (name or "").strip().lower()
    for b in T.api("GET", f"/organizations/{org}/boards", {"fields": "name,id", "filter": "all"}):
        if (b.get("name") or "").strip().lower() == q:
            return b
    return None


def refresh_map() -> None:
    import subprocess
    root = next(_p for _p in Path(__file__).resolve().parents if (_p / "RULES").is_dir() and (_p / ".agents").is_dir())
    tool = root / "bin" / "time" / "snotra" / "trello-map.sh"
    if tool.is_file():
        r = subprocess.run(["bash", str(tool)], capture_output=True, text=True, timeout=180)
        say(f"map{{refreshed:{str(r.returncode == 0).lower()}}}")


def want_lists(place: dict) -> list[str]:
    names = [v for v in (place.get("lists") or {}).values() if v]
    mc = place.get("meeting_card") or {}
    if mc.get("list") and (mc.get("board") or "").strip().lower() == (place.get("board") or "").strip().lower():
        names.append(mc["list"])
    seen, out = set(), []
    for n in names:
        if n.lower() not in seen:
            seen.add(n.lower())
            out.append(n)
    return out


def check(place: dict) -> int:
    name = place.get("board") or die("the place names no board")
    b = board_in_map(name)
    if not b:
        say(f"board{{name:{name},in_map:false,verdict:'missing — run ensure'}}")
        return 1
    real = T.board_id_of(name)
    have = {x["name"]: x["id"] for x in T.api("GET", f"/boards/{real}/lists", {"fields": "name"})}
    missing = [n for n in want_lists(place) if n not in have]
    labels = {l.get("name") for l in T.api("GET", f"/boards/{real}/labels", {"fields": "name", "limit": 1000})}
    missing_labels = [n for n in (place.get("labels") or {}) if n not in labels]
    say(f"board{{name:{name},id:{real},lists:{len(have)},missing_lists:{missing},"
        f"missing_labels:{missing_labels},verdict:{'ok' if not missing and not missing_labels else 'incomplete'}}}")
    return 0 if not missing and not missing_labels else 1


def ensure(place: dict) -> int:
    name = place.get("board") or die("the place names no board")
    existing = board_in_map(name) or board_in_org(name)
    if existing:
        real = existing.get("id") if existing.get("id") else T.board_id_of(name)
        say(f"board{{name:{name},id:{real},created:false}}")
    else:
        # the organisation the house's boards already live in — never a guess, and never a personal board
        org = None
        for b in T.load_map().get("boards") or []:
            try:
                bid = T.board_id_of(b["name"])
                o = T.api("GET", f"/boards/{bid}/organization", {"fields": "id"})
                if o.get("id"):
                    org = o["id"]
                    break
            except SystemExit:
                continue
        if not org:
            die("no organisation found on any mapped board — refusing to create a board in a personal space")
        made = T.api("POST", "/boards", {"name": name, "defaultLists": "false",
                                         "prefs_permissionLevel": "private", "idOrganization": org})
        real = made["id"]
        say(f"board{{name:{name},id:{real},created:true,org:{org}}}")
    have = {x["name"]: x["id"] for x in T.api("GET", f"/boards/{real}/lists", {"fields": "name"})}
    for lst in want_lists(place):
        if lst in have:
            say(f"list{{name:{lst},created:false}}")
            continue
        made_l = T.api("POST", "/lists", {"idBoard": real, "name": lst, "pos": "bottom"})
        have[lst] = made_l["id"]
        say(f"list{{name:{lst},created:true}}")
    for lab, colour in (place.get("labels") or {}).items():
        T.ensure_label(real, lab, colour)
        say(f"label{{name:{lab},colour:{colour}}}")
    # read back: the lists the place names must exist, or this door did not do its job
    refresh_map()
    back = {x["name"] for x in T.api("GET", f"/boards/{real}/lists", {"fields": "name"})}
    missing = [n for n in want_lists(place) if n not in back]
    say(f"verify{{board:{name},lists:{len(back)},missing:{missing},ok:{str(not missing).lower()}}}")
    return 0 if not missing else 1


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    cmd = argv[1]
    if cmd == "show":
        for p in places():
            prof = load_yaml(p)
            say(f"place{{id:{prof.get('place') or p.parent.parent.name + '/' + p.parent.name},"
                f"surface:{prof.get('surface') or 'trello'},board:{prof.get('board')},"
                f"authority:{'cited' if (prof.get('authority') or {}).get('decisions') or (prof.get('authority') or {}).get('documents') else 'house default'}}}")
        return 0
    if cmd in ("check", "ensure"):
        if len(argv) < 3:
            die(f"{cmd} needs a place, e.g. ymir/projects", 2)
        prof = load_yaml(place_file(argv[2]))
        surface = (prof.get("surface") or "trello").strip().lower()
        if surface != "trello":
            die(f"the place declares surface {surface!r}; this door speaks trello only — refusing")
        return check(prof) if cmd == "check" else ensure(prof)
    die(f"unknown command {cmd!r} — check | ensure | show", 2)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
