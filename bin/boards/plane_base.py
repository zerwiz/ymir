#!/usr/bin/env python3
"""plane_base.py — which Plane this seat talks to, and proof that it IS Plane (plan 324 F5, F6, F10).

A Plane base was guessed for months: the projector and the desk's reader both defaulted to
`127.0.0.1:8099`, and on a dev machine that port is a model server. A token set without repointing
would have posted cards at a model. So nothing here defaults a base, and a base is refused BY NAME
until it answers like Plane.

The proof, measured on a real Plane (2026-11-19): `GET /api/v1/workspaces/` answers **404** — Plane's
public API has no workspace listing — while `GET /api/v1/users/me/` answers the token's user
(`id`, `email`, `display_name`). So the identity endpoint is the proof, and the workspaces are listed
one slug at a time from the operator's own list (`GIMLE_PLANE_WORKSPACES`, or the home's
`config/gimle/plane-workspaces.txt`). A newer Plane that does list workspaces is used when it answers.

Where the two values come from (Rule 07, secrets by reference — never a literal in a file):
    base   PLANE_API_BASE, else the legacy names PLANE_API / GIMLE_PLANE_URL, else the vault's PLANE_API_BASE
    token  PLANE_API_TOKEN, else the file PLANE_API_TOKEN_FILE / GIMLE_PLANE_TOKEN_FILE, else the vault's PLANE_API_TOKEN

    plane_base.py probe        the verdict: plane · refused <why> · skip <the missing value>   (exit 0 · 1 · 0)
    plane_base.py workspaces   the probe, then each named workspace with its project count
    plane_base.py env          print `export PLANE_API_BASE=…` for a shell (the token is never printed)

Exit codes: 0 Plane (or a clean skip with the missing value named) · 1 a base that is not Plane.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _vault() -> dict:
    """The vault's PLANE_* keys, read through the house's one door. Values stay in this process."""
    if os.environ.get("PLANE_BASE_NO_VAULT"):
        return {}
    door = os.path.join(ROOT, "bin", "vault", "hodd.sh")
    try:
        out = subprocess.run(["bash", door, "emit", "secrets/platform.env"], capture_output=True,
                             text=True, timeout=20).stdout
    except Exception:  # noqa: BLE001
        return {}
    keys = {}
    for line in out.splitlines():
        line = line.strip()
        if line.startswith("export "):
            line = line[7:]
        if line.startswith("PLANE_") and "=" in line:
            k, v = line.split("=", 1)
            keys[k] = v.strip().strip("'\"")
    return keys


def resolve() -> dict:
    """{base, token, base_from, token_from} — an empty value means this seat lacks it."""
    base, base_from = "", ""
    for name in ("PLANE_API_BASE", "PLANE_API", "GIMLE_PLANE_URL"):
        if os.environ.get(name, "").strip():
            base, base_from = os.environ[name].strip(), f"env {name}"
            break
    token, token_from = "", ""
    if os.environ.get("PLANE_API_TOKEN", "").strip():
        token, token_from = os.environ["PLANE_API_TOKEN"].strip(), "env PLANE_API_TOKEN"
    else:
        for name in ("PLANE_API_TOKEN_FILE", "GIMLE_PLANE_TOKEN_FILE"):
            path = os.environ.get(name, "").strip()
            if path and os.path.isfile(path):
                try:
                    token = open(path, encoding="utf-8").read().strip()
                    token_from = f"file {name}"
                    break
                except OSError:
                    pass
    if not base or not token:
        v = _vault()
        if not base and v.get("PLANE_API_BASE"):
            base, base_from = v["PLANE_API_BASE"], "vault PLANE_API_BASE"
        if not token and v.get("PLANE_API_TOKEN"):
            token, token_from = v["PLANE_API_TOKEN"], "vault PLANE_API_TOKEN"
    return {"base": base.rstrip("/"), "token": token, "base_from": base_from, "token_from": token_from}


def _get(base: str, token: str, path: str, timeout: float = 8.0):
    """(status, server header, parsed body or None, raw head) — never raises for an HTTP answer."""
    req = urllib.request.Request(base + path, headers={"X-Api-Key": token, "Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            raw = r.read()
            status, server = r.status, r.headers.get("Server", "")
    except urllib.error.HTTPError as exc:
        raw, status, server = exc.read(), exc.code, exc.headers.get("Server", "")
    head = raw[:160].decode("utf-8", "replace").replace("\n", " ")
    try:
        body = json.loads(raw.decode("utf-8", "replace")) if raw else None
    except json.JSONDecodeError:
        body = None
    return status, server, body, head


def probe(base: str, token: str) -> dict:
    """{verdict: plane|refused|skip, why, user?} — the base is named in every refusal."""
    if not base:
        return {"verdict": "skip", "why": "PLANE_API_BASE is unset (env or vault) — this seat has no Plane"}
    if not token:
        return {"verdict": "skip", "why": f"PLANE_API_TOKEN is unset (env, token file or vault) — base {base} is not probed"}
    try:
        status, server, body, head = _get(base, token, "/api/v1/users/me/")
    except Exception as exc:  # noqa: BLE001 — a dead socket is a refusal, said with its cause
        return {"verdict": "refused", "why": f"{base} did not answer ({exc.__class__.__name__}: {exc})"}
    if status == 200 and isinstance(body, dict) and body.get("id") and ("email" in body or "display_name" in body):
        return {"verdict": "plane", "why": f"{base} answered /api/v1/users/me/ as Plane",
                "user": body.get("display_name") or body.get("email") or body.get("id")}
    said = f"HTTP {status}" + (f", Server: {server}" if server else "") + f", body: {head!r}"
    if status in (401, 403) and isinstance(body, dict) and "detail" in body and "error" not in body:
        return {"verdict": "refused",
                "why": f"{base} looks like Plane but refused the token ({said}) — PLANE_API_TOKEN is wrong or revoked"}
    return {"verdict": "refused",
            "why": f"{base} is not Plane: GET /api/v1/users/me/ answered {said} — set PLANE_API_BASE to the Plane host"}


def named_workspaces() -> list[str]:
    slugs = [w.strip() for w in os.environ.get("GIMLE_PLANE_WORKSPACES", "").split(",") if w.strip()]
    if slugs:
        return slugs
    candidates = [os.environ.get("GIMLE_PLANE_WORKSPACES_FILE", "").strip()]
    home = os.environ.get("YMIR_HOME", "").strip() or os.path.expanduser("~/Documents/ymirhome")
    candidates.append(os.path.join(home, "config", "gimle", "plane-workspaces.txt"))
    for path in candidates:
        if path and os.path.isfile(path):
            with open(path, encoding="utf-8") as fh:
                return [ln.split("#", 1)[0].strip() for ln in fh if ln.split("#", 1)[0].strip()]
    return []


def workspaces(base: str, token: str) -> dict:
    """The probe, then the workspaces: Plane's own list when it has one, else each named slug."""
    v = probe(base, token)
    if v["verdict"] != "plane":
        return v
    status, _server, body, _head = _get(base, token, "/api/v1/workspaces/")
    rows = []
    if status == 200 and isinstance(body, (list, dict)):
        for w in (body if isinstance(body, list) else body.get("results", [])):
            rows.append({"workspace": w.get("slug") or w.get("name"), "projects": None, "state": "listed"})
    else:
        slugs = named_workspaces()
        if not slugs:
            v["workspaces"] = []
            v["why"] += "; Plane lists no workspaces itself and no slug is named (GIMLE_PLANE_WORKSPACES or config/gimle/plane-workspaces.txt)"
            return v
        for slug in slugs:
            st, _s, b, _h = _get(base, token, f"/api/v1/workspaces/{slug}/projects/?per_page=100")
            if st == 200 and isinstance(b, dict):
                n = b.get("total_count", len(b.get("results", [])))
                rows.append({"workspace": slug, "projects": n, "state": "reachable"})
            else:
                rows.append({"workspace": slug, "projects": None, "state": f"HTTP {st}"})
    v["workspaces"] = rows
    return v


def main(argv: list[str]) -> int:
    cmd = argv[0] if argv else "probe"
    r = resolve()
    if cmd == "env":
        if r["base"]:
            print(f"export PLANE_API_BASE={r['base']}")
        return 0
    if cmd == "probe":
        v = probe(r["base"], r["token"])
        print("plane[1]{door,state,why}:")
        print(f'  "plane","{v["verdict"]}","{v["why"].replace(chr(34), chr(39))}"')
        return 1 if v["verdict"] == "refused" else 0
    if cmd == "workspaces":
        v = workspaces(r["base"], r["token"])
        print("plane[1]{door,state,why}:")
        print(f'  "plane","{v["verdict"]}","{v["why"].replace(chr(34), chr(39))}"')
        rows = v.get("workspaces") or []
        if rows:
            print(f"workspaces[{len(rows)}]{{workspace,projects,state}}:")
            for w in rows:
                print(f'  "{w["workspace"]}",{w["projects"] if w["projects"] is not None else "-"},"{w["state"]}"')
        return 1 if v["verdict"] == "refused" else 0
    print("usage: plane_base.py probe|workspaces|env", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
