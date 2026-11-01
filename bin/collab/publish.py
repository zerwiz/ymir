#!/usr/bin/env python3
"""publish.py — the baton on the Board: what is next and what is blocked become cards.

    collab.sh publish <repo> [--project NAME] [--workspace WS] [--yes] [--dry-run]

It reads `handoff/CURRENT.md` — section 3 (what is next) and section 4 (what is blocked, and on whom) — and
creates one card per bullet in a Plane project, **idempotently by title**: a card that is already there is
skipped, so running it twice adds nothing.

Writes go through Plane's own API (never its database), so a card leaves a trace in Plane's activity log,
its validation runs, and its webhooks fire. The token is read from the vault by its one door
(`bin/vault/hodd-set.sh --get PLANE_API_TOKEN`) — never from a file, never from the environment.

It never creates a project: a Board place is a decision, not a side effect. It prints the project it could
not find and stops.

Exit: 0 published or clean dry run · 1 refused or failed · 2 usage.
"""
import argparse
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request

DEFAULT_BASE = "https://board.zerwiz.org"
DEFAULT_WORKSPACE = "whynotproductions"
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def die(message, code=1):
    print("publish: %s" % message, file=sys.stderr)
    sys.exit(code)


def token():
    door = os.path.join(ROOT, "bin", "vault", "hodd-set.sh")
    try:
        out = subprocess.run(["bash", door, "--get", "PLANE_API_TOKEN"], capture_output=True, text=True, check=True)
    except Exception:
        die("no PLANE_API_TOKEN in the vault — set it with bin/vault/hodd-set.sh PLANE_API_TOKEN <value>")
    value = out.stdout.strip()
    if not value:
        die("PLANE_API_TOKEN is empty in the vault")
    return value


def api(base, path, key, method="GET", body=None):
    url = base.rstrip("/") + path
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(url, data=data, method=method)
    # Cloudflare answers 1010 to a bare Python-urllib agent; a plain name is enough.
    request.add_header("User-Agent", "ymir-collab/1.0")
    request.add_header("X-API-Key", key)
    request.add_header("Accept", "application/json")
    if data:
        request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request, timeout=30) as answer:
            return json.loads(answer.read().decode() or "{}")
    except urllib.error.HTTPError as exc:
        die("%s %s → HTTP %s: %s" % (method, path, exc.code, exc.read().decode()[:200]))
    except Exception as exc:
        die("%s %s → %s" % (method, path, exc))


def section(text, number):
    """The bullets of `## <number> · ...`, stopping at the next `## `."""
    match = re.search(r"^## %d · .*$" % number, text, re.MULTILINE)
    if not match:
        return []
    rest = text[match.end():]
    following = re.search(r"^## ", rest, re.MULTILINE)
    body = rest[: following.start()] if following else rest
    bullets = []
    for line in body.splitlines():
        line = line.strip()
        if line.startswith(("- ", "* ")):
            bullets.append(line[2:].strip())
        elif re.match(r"^\d+\.\s", line):
            bullets.append(re.sub(r"^\d+\.\s+", "", line).strip())
    return bullets


def title_of(bullet, limit=120):
    text = re.sub(r"\s+", " ", bullet).strip()
    return text if len(text) <= limit else text[: limit - 1].rstrip() + "…"


def main():
    parser = argparse.ArgumentParser(add_help=True)
    parser.add_argument("repo")
    parser.add_argument("--project", default="")
    parser.add_argument("--workspace", default=os.environ.get("GIMLE_PLANE_WORKSPACE", DEFAULT_WORKSPACE))
    parser.add_argument("--base", default=os.environ.get("PLANE_API_BASE", DEFAULT_BASE))
    parser.add_argument("--yes", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    baton = os.path.join(os.path.abspath(args.repo), "handoff", "CURRENT.md")
    if not os.path.isfile(baton):
        die("no baton at %s — write one with handoff/check.sh --new" % baton)
    with open(baton, encoding="utf-8") as handle:
        text = handle.read()

    date = re.search(r"\*\*Date:\*\*\s*(\d{4}-\d{2}-\d{2})", text)
    date = date.group(1) if date else "unknown"

    wanted = [("next", bullet) for bullet in section(text, 3)] + \
             [("blocked", bullet) for bullet in section(text, 4)]
    if not wanted:
        die("the baton's sections 3 and 4 carry no bullets — nothing to publish")

    key = token()
    projects = api(args.base, "/api/v1/workspaces/%s/projects/" % args.workspace, key)
    projects = projects.get("results", projects if isinstance(projects, list) else [])
    name = args.project or os.path.basename(os.path.abspath(args.repo))
    match = next((p for p in projects
                  if name.lower() in (p.get("name") or "").lower()
                  or name.lower() == (p.get("identifier") or "").lower()), None)
    if not match:
        names = ", ".join(sorted((p.get("name") or "?") for p in projects)) or "none"
        die("no Board project matching %r in %s — the projects are: %s" % (name, args.workspace, names))

    issues = api(args.base, "/api/v1/workspaces/%s/projects/%s/issues/?per_page=100"
                 % (args.workspace, match["id"]), key)
    existing = {i.get("name", "") for i in issues.get("results", [])}

    created, skipped = [], []
    for kind, bullet in wanted:
        title = title_of(bullet)
        if title in existing:
            skipped.append(title)
            continue
        if args.dry_run or not args.yes:
            created.append(title)
            continue
        api(args.base, "/api/v1/workspaces/%s/projects/%s/issues/" % (args.workspace, match["id"]), key,
            method="POST",
            body={"name": title,
                  "description_html": "<p>From <code>handoff/CURRENT.md</code> §%s, baton of %s.</p>"
                                      % ("3" if kind == "next" else "4", date)})
        created.append(title)

    verb = "would create" if (args.dry_run or not args.yes) else "created"
    print("publish[5]{field,value}:")
    print('  "repo","%s"' % os.path.abspath(args.repo))
    print('  "board","%s / %s"' % (args.workspace, match.get("name")))
    print('  "baton","%s"' % date)
    print('  "cards","%s %d, skipped %d (already there)"' % (verb, len(created), len(skipped)))
    print('  "mode","%s"' % ("dry run" if (args.dry_run or not args.yes) else "written through Plane's API"))
    for title in created:
        print('  "card","%s"' % title)
    if not (args.dry_run or args.yes):
        print("publish: nothing was written — pass --yes to write")
    return 0


if __name__ == "__main__":
    sys.exit(main())
