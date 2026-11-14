#!/usr/bin/env python3
"""Board reader for the desk — what is assigned to *this person*, read from Plane.

Three lessons, each bought once:
  · the API token's identity is not the viewer's — map a person to their board account by email;
  · Plane's member endpoint returns a bare list, while issues return a `results` envelope;
  · Plane rate-limits hard (error_code 5900), so read once, keep it, and back off rather than hammering.
"""
import json
import os
import subprocess
import time
import urllib.error
import urllib.request

PLANE_BASE = os.environ.get("GIMLE_PLANE_URL", "http://127.0.0.1:8099")
TOKEN_FILE = os.environ.get("GIMLE_PLANE_TOKEN_FILE", os.path.expanduser("~/gimle/desk/etc/plane-token"))
# person → board account email. Private: it lives on the heart beside the token, never in this
# repository (Rule 04). The file is a flat JSON object, keys lower-cased.
PEOPLE_FILE = os.environ.get("GIMLE_PEOPLE_FILE", os.path.expanduser("~/gimle/desk/etc/people.json"))
# WHICH workspaces to read is the operator's fact, never a list in this repository (RULES/04).
# $GIMLE_PLANE_WORKSPACES (comma-separated), else $GIMLE_PLANE_WORKSPACES_FILE, else the home's
# own config/gimle/plane-workspaces.txt (one slug per line), resolved through the house's door.
def _workspaces() -> list[str]:
    slugs = [w.strip() for w in os.environ.get("GIMLE_PLANE_WORKSPACES", "").split(",") if w.strip()]
    if slugs:
        return slugs
    candidates = []
    named = os.environ.get("GIMLE_PLANE_WORKSPACES_FILE", "").strip()
    if named:
        candidates.append(named)
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    door = os.path.join(root, "bin", "vault", "hodd.sh")
    try:
        hoard = subprocess.run(["bash", door, "path"], capture_output=True, text=True, timeout=15).stdout.strip()
        home = os.path.dirname(hoard) if hoard else ""
    except Exception:
        home = ""
    if home:
        candidates.append(os.path.join(home, "config", "gimle", "plane-workspaces.txt"))
    for path in candidates:
        try:
            with open(path, encoding="utf-8") as fh:
                return [line.split("#", 1)[0].strip() for line in fh if line.split("#", 1)[0].strip()]
        except OSError:
            continue
    return []


WORKSPACES = _workspaces()


def _people():
    try:
        with open(PEOPLE_FILE, encoding="utf-8") as fh:
            return {str(k).lower(): str(v).lower() for k, v in json.load(fh).items()}
    except (OSError, json.JSONDecodeError, AttributeError):
        return {}

_cache = {"at": 0.0, "members": {}, "cards": {}, "detail": ""}
CACHE_SECONDS = 180
_last_refresh = 0.0


def _token():
    try:
        return open(TOKEN_FILE, encoding="utf-8").read().strip()
    except OSError:
        return ""


def _get(path, retries=2):
    token = _token()
    if not token:
        raise RuntimeError("no plane token")
    delay = 1.5
    for attempt in range(retries + 1):
        req = urllib.request.Request(PLANE_BASE + path, headers={"X-Api-Key": token})
        try:
            with urllib.request.urlopen(req, timeout=8) as resp:
                return json.loads(resp.read().decode())
        except urllib.error.HTTPError as exc:
            body = exc.read().decode(errors="ignore")
            if "RATE_LIMIT_EXCEEDED" in body and attempt < retries:
                time.sleep(delay)
                delay *= 2
                continue
            raise


def _rows(payload):
    if isinstance(payload, list):
        return payload
    return payload.get("results", [])


# ── the cache the MCP shares with the desk ────────────────────────────────────────────────────────
# One reader for both faces of the hall (plan 217): the desk asks *what is assigned to me*, the MCP asks
# *what is in this place* and *who owes what*. Both go through these functions, so a fault in the reader
# is a fault in one place and a fix is too. Plane rate-limits hard (error_code 5900): read once, keep it.
_pcache: dict = {}


def _cached(key, fn, ttl=None):
    now = time.time()
    hit = _pcache.get(key)
    if hit and now - hit[0] < (ttl if ttl is not None else CACHE_SECONDS):
        return hit[1]
    value = fn()
    _pcache[key] = (now, value)
    return value


def projects(slug: str) -> list:
    """The workspace's live projects."""
    def read():
        rows = _rows(_get(f"/api/v1/workspaces/{slug}/projects/?per_page=50"))
        return [p for p in rows if not p.get("archived_at")]
    return _cached(("projects", slug), read)


def states(slug: str, project_id: str) -> list:
    """The project's state groups (Backlog, Todo, In Progress, Done, Cancelled, or its own names)."""
    return _cached(("states", slug, project_id),
                   lambda: _rows(_get(f"/api/v1/workspaces/{slug}/projects/{project_id}/states/")))


def issues(slug: str, project_id: str, per_page: int = 100) -> list:
    """The project's issues, as Plane returns them."""
    return _cached(("issues", slug, project_id, per_page),
                   lambda: _rows(_get(
                       f"/api/v1/workspaces/{slug}/projects/{project_id}/issues/?per_page={per_page}")))


def members(slug: str) -> dict:
    """member id → the best human name the board holds (display_name, else email, else the id)."""
    def read():
        out = {}
        for m in _rows(_get(f"/api/v1/workspaces/{slug}/members/?per_page=100")):
            if m.get("id"):
                out[m["id"]] = (m.get("display_name") or m.get("email") or m["id"])
        return out
    return _cached(("members", slug), read)


def write(method: str, path: str, body=None):
    """The one door for a write to the board (plan 217 §3: a target is named, never guessed).

    GET lives in `_get`; this is the shape a create or an update needs. It is deliberately the only
    place in this file that sends a body, so a write can be found by grepping for one word.
    """
    token = _token()
    if not token:
        raise RuntimeError("no plane token")
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(PLANE_BASE + path, method=method, data=data,
                                 headers={"X-Api-Key": token, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=20) as resp:
        raw = resp.read().decode()
        return json.loads(raw) if raw else {}


def _refresh():
    global _last_refresh
    now = time.time()
    if _cache["cards"] and now - _cache["at"] < CACHE_SECONDS:
        return
    if now - _last_refresh < 20:          # never more than one rebuild per twenty seconds
        return
    _last_refresh = now

    members, cards, notes = {}, {}, []
    for slug in WORKSPACES:
        try:
            for m in _rows(_get(f"/api/v1/workspaces/{slug}/members/?per_page=100")):
                email = (m.get("email") or "").lower()
                if email:
                    members[email] = m.get("id")
        except Exception as exc:  # noqa: BLE001
            notes.append(f"{slug}: members {exc.__class__.__name__}")
        try:
            projects = _rows(_get(f"/api/v1/workspaces/{slug}/projects/?per_page=50"))
        except Exception as exc:  # noqa: BLE001
            notes.append(f"{slug}: projects {exc.__class__.__name__}")
            continue
        for project in projects:
            if project.get("archived_at"):
                continue
            try:
                issues = _rows(_get(f"/api/v1/workspaces/{slug}/projects/{project['id']}/issues/?per_page=100"))
            except Exception:
                continue
            for issue in issues:
                for who in issue.get("assignees") or []:
                    cards.setdefault(who, []).append({
                        "name": issue.get("name", ""),
                        "state": issue.get("state") or "",
                        "due": issue.get("target_date"),
                        "project": f"{project.get('identifier', '')} · {project.get('name', '')}",
                        "workspace": slug,
                    })
    _cache.update({"at": now, "members": members, "cards": cards, "detail": "; ".join(notes)})


def board_for(person: str, limit: int = 40):
    email = _people().get(person.lower())
    if not email:
        return [], f"no board identity mapped for {person}"
    try:
        _refresh()
    except Exception as exc:  # noqa: BLE001
        return [], f"the board did not answer ({exc.__class__.__name__})"
    if not _cache["cards"]:
        return [], _cache["detail"] or "the board held no assignments when it was last read"
    who = _cache["members"].get(email)
    if not who:
        return [], f"{email} is not a member of a board workspace yet"
    cards = sorted(_cache["cards"].get(who, []), key=lambda c: (c["due"] or "9999-99-99"))
    return cards[:limit], f"{len(cards)} card(s) assigned"
