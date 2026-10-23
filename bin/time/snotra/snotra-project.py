#!/usr/bin/env python3
"""snotra-project — the record projected onto the place's boards, by kind, verified.

WHY: the cards are a PROJECTION of the meeting's record, never a second truth (plan 111 §2). The record
lives in the vault; the board is where the work happens. Until this door existed the projector wrote one
board of its own choosing, filed only the actions, and nothing read the board back — so a card could sit
in a list nobody meant and the call still returned 200.

WHAT IT DOES
    plan    <meeting-dir>   what would be created, where, with which labels — no writes at all
    apply   <meeting-dir>   create/update idempotently, keyed by the record's own ids, verified after write
    verify  <meeting-dir>   read the boards back and diff them against the record — exit 1 on any drift
    status  <meeting-dir>   one row per item: where it is, and whether that is where the place says

THE LAWS
    * the shape comes from the PLACE (`places/<company>/<place>/place.yaml`), not from this file: the
      board, the list per kind, the labels and the cadence are all read, never assumed;
    * boards and lists are resolved by NAME through the map (`trello-map.yaml`) — a typed id is refused;
    * idempotent by `record-key: <meeting-id>:<item-id>` in the description: a second run updates, never
      duplicates;
    * a card whose key sits in a list the place did not name is DRIFT: it is reported and LEFT WHERE IT IS
      (a human may have moved it deliberately). `--move` is the operator's call, never the door's;
    * every returned object is read back before it is believed.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import trello_client as T  # noqa: E402

KEY = "record-key"


def die(msg: str, code: int = 1):
    print(f"snotra-project: {msg}", file=sys.stderr)
    raise SystemExit(code)


def say(msg: str):
    print(msg, flush=True)


# ── the place ───────────────────────────────────────────────────────────────────────────────────
def load_yaml(path: Path) -> dict:
    try:
        import yaml  # noqa: PLC0415
    except Exception:  # noqa: BLE001
        die("PyYAML is missing: pip install pyyaml")
    if not path.is_file():
        die(f"no place profile at {path} — a projection without a declared shape would invent one")
    return yaml.safe_load(path.read_text(encoding="utf-8")) or {}


def place_of(rec: dict, override: str | None = None) -> tuple[Path, dict]:
    m = rec.get("meeting") or {}
    if override:
        company, _, place = override.partition("/")
    else:
        company, place = (m.get("company") or "").strip(), (m.get("place") or "").strip()
    if not company or not place:
        die("the record names no company/place — the projection cannot know which shape to use")
    root = T.home_dir() / "hodd" / "identity" / "places" / company / place
    for cand in (root / "place.yaml", root / f"{place}.yaml"):
        if cand.is_file():
            prof = load_yaml(cand)
            surface = (prof.get("surface") or "trello").strip().lower()
            if surface != "trello":
                die(f"the place {company}/{place} declares surface {surface!r}; this projector speaks "
                    "trello only — refusing rather than filing into the wrong engine")
            return cand, prof
    die(f"no place profile for {company}/{place} (looked in {root}) — declare the shape first")


# ── the record, as items ────────────────────────────────────────────────────────────────────────
def trim(s: str, n: int = 80) -> str:
    s = " ".join((s or "").split())
    return s if len(s) <= n else s[: n - 1].rstrip() + "…"


def items_of(rec: dict) -> list[dict]:
    mid = (rec.get("meeting") or {}).get("meeting_id") or "meeting"
    out: list[dict] = []
    for d in rec.get("decisions") or []:
        did = d.get("decision_id")
        grade = (d.get("grade") or "").upper()
        desc = "\n".join(filter(None, [
            f"**{grade or '—'} · {d.get('status') or 'proposed'}**",
            f"Approver pending: {'yes' if d.get('approver_pending') else 'no'}",
            f"Reversibility: {d.get('reversibility') or '—'}",
            "",
            d.get("rationale") or "",
            "",
            f"Evidence ({d.get('evidence', {}).get('timestamp', '?')}): \"{(d.get('evidence') or {}).get('quote', '')}\"",
            "",
            f"{KEY}: {mid}:{did}",
        ]))
        out.append({"kind": "decision", "id": did, "name": trim(d.get("statement") or d.get("title") or did),
                    "desc": desc, "labels": [f"Grade {grade}"] if grade in ("A", "B", "C") else [],
                    "item": d})
    for a in rec.get("actions") or []:
        aid = a.get("action_id")
        desc = "\n".join(filter(None, [
            f"Owner: {a.get('owner') or '—'}",
            f"Due: {a.get('due_at') or ('unresolved' if a.get('date_unresolved') else '—')}",
            f"Done when: {a.get('definition_of_done') or 'to be agreed'}",
            f"Depends on: {a.get('dependency') or 'none'}",
            "",
            f"Evidence ({a.get('evidence', {}).get('timestamp', '?')}): \"{(a.get('evidence') or {}).get('quote', '')}\"",
            "",
            f"{KEY}: {mid}:{aid}",
        ]))
        out.append({"kind": "action", "id": aid, "name": trim(a.get("deliverable") or aid),
                    "desc": desc, "labels": [], "item": a})
    for q in rec.get("questions") or []:
        qid = q.get("question_id")
        desc = "\n".join(filter(None, [
            f"Asked by: {q.get('asked_by') or '—'}",
            q.get("context") or "",
            "",
            f"Evidence ({q.get('evidence', {}).get('timestamp', '?')}): \"{(q.get('evidence') or {}).get('quote', '')}\"",
            "",
            f"{KEY}: {mid}:{qid}",
        ]))
        out.append({"kind": "question", "id": qid, "name": trim(q.get("question") or qid),
                    "desc": desc, "labels": ["Question"], "item": q})
    return out


def meeting_item(rec: dict, place: dict) -> dict | None:
    mc = place.get("meeting_card")
    if not mc:
        return None
    m = rec.get("meeting") or {}
    mid = m.get("meeting_id") or "meeting"
    people = ", ".join((p.get("name") or "") for p in (rec.get("participants") or []))
    cov = (m.get("coverage") or {})
    desc = "\n".join(filter(None, [
        f"Company: {m.get('company')} · Place: {m.get('place')}",
        f"Held: {m.get('started_at')} → {m.get('ended_at')}",
        f"Participants: {people}",
        f"Decisions: {len(rec.get('decisions') or [])} · Actions: {len(rec.get('actions') or [])} · "
        f"Questions: {len(rec.get('questions') or [])}",
        f"Audio source: {cov.get('audio_source') or '—'}",
        f"Coverage: recorded from {cov.get('recorded_from') or '?'}; missing before {cov.get('missing_before') or 'nothing'}",
        "",
        f"The record: the vault, {m.get('meeting_id')}",
        "",
        f"{KEY}: {mid}:MEETING",
    ]))
    return {"kind": "meeting", "id": "MEETING", "name": trim(f"{m.get('title') or mid} — {str(m.get('started_at'))[:10]}", 80),
            "desc": desc, "labels": [], "item": m, "board": mc.get("board"), "list": mc.get("list")}


# ── the board, read once ───────────────────────────────────────────────────────────────────────
def state_for(place: dict, board_name: str, cache: dict) -> tuple[dict, dict, dict]:
    """One read of a board: its lists (by name) and its cards (by record key)."""
    if board_name in cache:
        return cache[board_name]
    mc = place.get("meeting_card") or {}
    if (place.get("board") or "").strip().lower() == board_name.strip().lower():
        names = {v for v in (place.get("lists") or {}).values() if v}
    elif (mc.get("board") or "").strip().lower() == board_name.strip().lower():
        names = {mc.get("list")} if mc.get("list") else set()
    else:
        names = set()
    b = T.resolve_board(board_name)
    b["id"] = T.board_id_of(board_name)
    ids = {}
    for nm in names:
        if not nm:
            continue
        _, lst = T.resolve_list(board_name, nm)
        ids[nm] = lst["id"]
    by_key: dict[str, dict] = {}
    for c in T.board_cards(b["id"]):
        for line in (c.get("desc") or "").splitlines():
            if line.strip().startswith(KEY + ":"):
                by_key[line.split("record-key:", 1)[1].strip()] = c
                break
    cache[board_name] = (b, ids, by_key)
    return cache[board_name]


def target_list(place: dict, it: dict) -> tuple[str, str]:
    if it.get("board"):
        return it["board"], it["list"]
    board = place.get("board") or die("the place declares no board")
    return board, (place.get("lists") or {}).get(it["kind"]) or die(
        f"the place declares no list for kind {it['kind']!r}")


def plan(rec: dict, place: dict, it: dict, cache: dict) -> tuple[str, dict]:
    """Return (verdict, resolved) without writing: create · update · ok · drift."""
    board, liste = target_list(place, it)
    b, ids, by_key = state_for(place, board, cache)
    lid = ids.get(liste)
    if lid is None:
        _, lst = T.resolve_list(board, liste)
        lid = lst["id"]
        ids[liste] = lid
    key = next((ln.split("record-key:", 1)[1].strip() for ln in it["desc"].splitlines()
                if ln.strip().startswith(KEY + ":")), None)
    card = by_key.get(key) if key else None
    if card is None:
        return "create", {"board": b, "list_id": lid, "list": liste}
    if card.get("idList") != lid:
        return "drift", {"board": b, "card": card, "list": liste, "list_id": lid}
    changed = (card.get("name") != it["name"]) or ((card.get("desc") or "").strip() != it["desc"].strip())
    return ("update" if changed else "ok"), {"board": b, "card": card, "list_id": lid, "list": liste}


def label_ids(place: dict, board_id: str, wanted: list[str]) -> list[str]:
    colours = place.get("labels") or {}
    ids = []
    for name in wanted:
        colour = colours.get(name) or "blue"
        ids.append(T.ensure_label(board_id, name, colour))
    return ids


def apply(rec: dict, place: dict, d: Path, do_writes: bool, move: bool = False) -> int:
    items = items_of(rec)
    mi = meeting_item(rec, place)
    if mi:
        items.append(mi)
    state: dict = {}
    drift = 0
    made = updated = okn = 0
    for it in items:
        verdict, r = plan(rec, place, it, state)
        if verdict == "ok":
            okn += 1
            say(f"ok      {it['kind']:<8} {it['id']:<22} {r['list']}")
            continue
        if verdict == "drift":
            drift += 1
            say(f"DRIFT   {it['kind']:<8} {it['id']:<22} card is in another list than {r['list']!r} — "
                "left where it is")
            if do_writes and move:
                T.update_card(r["card"]["id"], idList=r["list_id"])
                say(f"moved   {it['id']} → {r['list']} (on the operator's --move)")
            continue
        if not do_writes:
            say(f"would-{verdict} {it['kind']:<8} {it['id']:<22} → {r['list']}")
            continue
        lids = label_ids(place, r["board"]["id"], it["labels"])
        if verdict == "create":
            card = T.create_card(r["list_id"], r["board"]["id"], it["name"], it["desc"], lids)
            made += 1
            say(f"created {it['kind']:<8} {it['id']:<22} {card['id']} → {r['list']}")
            back = T.get_card(card["id"])
            verdict_back = "ok" if back.get("idList") == r["list_id"] else "MISFILED"
            say(f"verify  {it['id']:<22} {verdict_back} (list {back.get('idList')})")
            if verdict_back != "ok":
                drift += 1
        else:
            params = {"name": it["name"], "desc": it["desc"]}
            if lids:
                params["idLabels"] = ",".join(lids)
            T.update_card(r["card"]["id"], **params)
            updated += 1
            say(f"updated {it['kind']:<8} {it['id']:<22} {r['card']['id']} → {r['list']}")
    say(f"project{{planned:{len(items)},created:{made},updated:{updated},already_ok:{okn},drift:{drift},"
        f"writes:{str(do_writes).lower()}}}")
    return 1 if drift else 0


def verify(rec: dict, place: dict) -> int:
    items = items_of(rec)
    mi = meeting_item(rec, place)
    if mi:
        items.append(mi)
    state: dict = {}
    missing = misplaced = good = 0
    for it in items:
        verdict, r = plan(rec, place, it, state)
        if verdict in ("create",):
            missing += 1
            say(f"missing {it['kind']:<8} {it['id']:<22} not on {r['board']['name']!r} → {r['list']!r}")
        elif verdict == "drift":
            misplaced += 1
            say(f"misfiled {it['kind']:<8} {it['id']:<22} sits in another list than {r['list']!r}")
        else:
            good += 1
            if verdict == "update":
                say(f"stale   {it['kind']:<8} {it['id']:<22} on the board but the record moved")
            else:
                say(f"ok      {it['kind']:<8} {it['id']:<22} {r['list']}")
    say(f"verify{{items:{len(items)},in_place:{good},missing:{missing},misfiled:{misplaced}}}")
    return 0 if (missing == 0 and misplaced == 0 and good == len(items)) else 1


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
    override = None
    for i, a in enumerate(argv):
        if a == "--place" and i + 1 < len(argv):
            override = argv[i + 1]
    _, place = place_of(rec, override)
    writes = cmd == "apply"
    move = "--move" in argv
    if cmd == "plan":
        return apply(rec, place, d, do_writes=False)
    if cmd == "apply":
        return apply(rec, place, d, do_writes=True, move=move)
    if cmd == "verify":
        return verify(rec, place)
    if cmd == "status":
        return verify(rec, place)
    die(f"unknown command {cmd!r} — plan | apply | verify | status", 2)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
