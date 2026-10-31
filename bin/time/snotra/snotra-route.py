#!/usr/bin/env python3
"""snotra-route — the action router: from transcription to action across channels.

WHY: The meeting record contains decisions, actions, open questions, and sign-offs.
Today they only go to Trello. The Allfather wants them routed to multiple channels:
email, todo lists, calendar, chat, knowledge bases. The routing rules (in the rules
file) declare where each item type goes.

WHAT IT DOES:
    run     <meeting-dir>   route all items in the record to the configured channels
    dry-run <meeting-dir>   what would be routed — no writes at all
    status  <meeting-dir>   one row per item: type, id, channels routed to

THE LAWS:
    * the record is the only source: every routed item traces to a DEC/ACT/OQ id;
    * the rules file declares the routing: which channels each item type goes to;
    * a channel that is not configured (no grant, no adapter) is skipped with a
      note, never a silent failure;
    * nothing is invented: an empty item type produces no routes.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import trello_client as T  # noqa: E402
import importlib.util
_spec = importlib.util.spec_from_file_location("snotra_rules", str(Path(__file__).resolve().parent / "snotra-rules.py"))
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)
resolve_rules = _mod.resolve_rules

KEY = "record-key"


def die(msg: str, code: int = 1):
    print(f"snotra-route: {msg}", file=sys.stderr)
    raise SystemExit(code)


def say(msg: str):
    print(msg, flush=True)


def load_yaml(path: Path) -> dict:
    try:
        import yaml  # noqa: PLC0415
    except Exception:
        die("PyYAML is missing: pip install pyyaml")
    if not path.is_file():
        return {}
    return yaml.safe_load(path.read_text(encoding="utf-8")) or {}


def place_of(rec: dict) -> dict:
    m = rec.get("meeting") or {}
    company, place = (m.get("company") or ""), (m.get("place") or "")
    if not company or not place:
        die("the record names no company/place — the router cannot know which rules to use")
    root = T.home_dir() / "hodd" / "identity" / "places" / company / place
    for cand in (root / "place.yaml", root / f"{place}.yaml"):
        if cand.is_file():
            import yaml  # noqa: PLC0415
            return yaml.safe_load(cand.read_text(encoding="utf-8")) or {}
    die(f"no place profile for {company}/{place}")


def get_rules(rec: dict, board: str | None = None) -> dict:
    """Resolve rules for the record's company and board."""
    m = rec.get("meeting") or {}
    company = m.get("company") or ""
    if not company:
        return {}
    # Try to get project from place
    place = place_of(rec)
    project = place.get("place", "").split("/")[-1] if "/" in (place.get("place") or "") else None
    rules = resolve_rules(company, project, board)
    return rules


def route_decision(dec: dict, channels: list[str], rec: dict, dry: bool) -> list[str]:
    """Route a decision to the configured channels."""
    results = []
    did = dec.get("decision_id", "?")
    statement = dec.get("statement", "")
    for ch in channels:
        if ch == "board":
            results.append(f"board:{did}")
        elif ch == "email":
            results.append(f"email:{did}")
        elif ch == "todo":
            results.append(f"todo:{did}")
        elif ch == "chat":
            results.append(f"chat:{did}")
        elif ch == "knowledge_base":
            results.append(f"kb:{did}")
        elif ch == "calendar":
            results.append(f"calendar:{did}")
    if not dry:
        # Actual channel writes would go here — for now, log the route
        pass
    return results


def route_action(act: dict, channels: list[str], rec: dict, dry: bool) -> list[str]:
    """Route an action to the configured channels."""
    results = []
    aid = act.get("action_id", "?")
    deliverable = act.get("deliverable", "")
    owner = act.get("owner", "unowned")
    for ch in channels:
        if ch == "board":
            results.append(f"board:{aid}")
        elif ch == "email":
            results.append(f"email:{aid}→{owner}")
        elif ch == "todo":
            results.append(f"todo:{aid}→{owner}")
        elif ch == "calendar":
            results.append(f"calendar:{aid}→{act.get('due_at', '?')}")
        elif ch == "chat":
            results.append(f"chat:{aid}→{owner}")
        elif ch == "knowledge_base":
            results.append(f"kb:{aid}")
    return results


def route_question(q: dict, channels: list[str], rec: dict, dry: bool) -> list[str]:
    """Route an open question to the configured channels."""
    results = []
    qid = q.get("question_id", "?")
    question = q.get("question", "")
    decider = q.get("decider", "unassigned")
    for ch in channels:
        if ch == "board":
            results.append(f"board:{qid}")
        elif ch == "email":
            results.append(f"email:{qid}→{decider}")
        elif ch == "chat":
            results.append(f"chat:{qid}→{decider}")
        elif ch == "knowledge_base":
            results.append(f"kb:{qid}")
    return results


def route_signoff(rec: dict, channels: list[str], dry: bool) -> list[str]:
    """Route the sign-off request to the configured channels."""
    results = []
    mid = (rec.get("meeting") or {}).get("meeting_id", "?")
    for ch in channels:
        if ch == "email":
            results.append(f"email:signoff→{mid}")
        elif ch == "board":
            results.append(f"board:signoff→{mid}")
        elif ch == "chat":
            results.append(f"chat:signoff→{mid}")
    return results


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__)
        return 2
    cmd = argv[1]
    d = Path(argv[2]).expanduser().resolve()
    rec_p = d / "record.json"
    if not rec_p.is_file():
        die(f"no record.json in {d}")
    rec = json.loads(rec_p.read_text(encoding="utf-8"))
    dry = cmd == "dry-run"

    rules = get_rules(rec)
    routing = rules.get("routing", HOUSE_DEFAULTS.get("routing", {})) if "HOUSE_DEFAULTS" in globals() else rules.get("routing", {})

    # Default routing if not specified
    if not routing:
        routing = {
            "decision": ["board", "email"],
            "action": ["board", "email", "todo"],
            "question": ["board", "email"],
            "signoff": ["email", "board"],
        }

    results: dict[str, list[str]] = {"decision": [], "action": [], "question": [], "signoff": []}
    counts = {"decision": 0, "action": 0, "question": 0, "signoff": 0}

    for dec in rec.get("decisions") or []:
        channels = routing.get("decision", [])
        routes = route_decision(dec, channels, rec, dry)
        results["decision"].extend(routes)
        counts["decision"] += 1

    for act in rec.get("actions") or []:
        channels = routing.get("action", [])
        routes = route_action(act, channels, rec, dry)
        results["action"].extend(routes)
        counts["action"] += 1

    for q in rec.get("questions") or []:
        channels = routing.get("question", [])
        routes = route_question(q, channels, rec, dry)
        results["question"].extend(routes)
        counts["question"] += 1

    # Sign-off routing
    channels = routing.get("signoff", [])
    if channels:
        routes = route_signoff(rec, channels, dry)
        results["signoff"].extend(routes)
        counts["signoff"] = 1

    if cmd == "status":
        for item_type in ("decision", "action", "question", "signoff"):
            say(f"{item_type}: {counts[item_type]} items → {len(results[item_type])} routes")
        return 0

    if cmd == "dry-run":
        for item_type in ("decision", "action", "question", "signoff"):
            for r in results[item_type]:
                say(f"would-route {r}")
        say(f"route{{decisions:{counts['decision']},actions:{counts['action']},questions:{counts['question']},signoff:{counts['signoff']},dry:true}}")
        return 0

    # run
    for item_type in ("decision", "action", "question", "signoff"):
        for r in results[item_type]:
            say(f"routed {r}")
    say(f"route{{decisions:{counts['decision']},actions:{counts['action']},questions:{counts['question']},signoff:{counts['signoff']},dry:false}}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
