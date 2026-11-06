#!/usr/bin/env python3
"""intake.py — read every registered repo once, and say honestly what could not be read.

WHY (plan 207, the Allfather 2026-11-06: *"we need to have so the user can add all his
repos he's working on. and we wanna see issues and a lot more from the githubs
capabilities"*): Ymir could read exactly one repository — the one it was standing in —
because `reviews()` in Hlidskjalf took `--repo` from this tree's own origin. The registry
already held 78 projects, so the missing thing was never the portfolio; it was the senses.

WHAT IT READS, per registered repo, one call per source:

  repo    the repository's own facts: default branch, issues enabled, archived
  issues  open issues with their age, labels and comment count
  prs     open pull requests with review decision, mergeability and checks
  runs    the last runs on the default branch — is the base green before anyone branches
  alerts  open vulnerability and dependabot alerts

THE THREE LAWS IT OBEYS:

  1. A source that cannot be read is REPORTED with its reason, never counted as zero.
     A `0` that means "I did not look" is the false green this house has paid for twice.
  2. The read is a CACHE with a TTL, and GitHub stays the authority. Nothing here is a
     second copy of the truth; the cache exists so a board can render without hammering
     an API and so two readers cannot disagree.
  3. It never writes to GitHub. This door only looks.

Usage:
  intake.py --home <ymir-home> [--repo <id>]... [--ttl <seconds>] [--limit <n>]
            [--cache-only] [--json]

Exit: 0 the read happened (even with unreadable repos) · 1 no registry · 2 usage.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time

SOURCES = ("repo", "issues", "prs", "runs", "alerts")
ISSUE_LIMIT = 100
DEFAULT_TTL = 300
DEFAULT_LIMIT = 20
GH_TIMEOUT = 30


# ---------------------------------------------------------------- the registry
def load_rows(path: str) -> list[dict]:
    try:
        import yaml  # noqa: PLC0415 — the registry is YAML; the shelf already needs it
    except ImportError:
        sys.stderr.write(
            "intake: python yaml module missing\n"
            "help: the registry is YAML — install pyyaml (the other registry doors need it too)\n"
        )
        raise SystemExit(1)
    with open(path, encoding="utf-8") as fh:
        data = yaml.safe_load(fh) or {}
    rows = data.get("projects") or []
    return [r for r in rows if isinstance(r, dict) and r.get("id")]


def usable_git(row: dict) -> tuple[str, str]:
    """(owner, repo) or ('', '') — an empty pair means the row cannot name a remote."""
    git = row.get("git") or {}
    owner = str(git.get("owner") or "").strip()
    repo = str(git.get("repo") or "").strip()
    if not owner or not repo or owner == "?" or repo == "?":
        return "", ""
    return owner, repo


# ------------------------------------------------------------------- the shell
def gh(args: list[str], timeout: int = GH_TIMEOUT) -> str:
    proc = subprocess.run(
        ["gh", *args], capture_output=True, text=True, timeout=timeout, check=False
    )
    if proc.returncode != 0:
        detail = (proc.stderr or proc.stdout or "").strip().splitlines()
        raise RuntimeError(detail[-1] if detail else f"gh exited {proc.returncode}")
    return proc.stdout


def gh_json(args: list[str]) -> object:
    out = gh(args).strip()
    return json.loads(out) if out else None


_GH_STATE = {"checked": False, "reason": ""}


def gh_unavailable() -> str:
    """'' when gh answers. ASKED LAZILY: a run served entirely from the cache must make no
    call at all — `gh auth status` included — or the cache has not saved the network."""
    if not _GH_STATE["checked"]:
        _GH_STATE["reason"] = can_gh()
        _GH_STATE["checked"] = True
    return _GH_STATE["reason"]


def can_gh() -> str:
    """'' when gh answers, else the reason it does not."""
    try:
        subprocess.run(
            ["gh", "auth", "status"], capture_output=True, text=True, timeout=20, check=False
        )
    except FileNotFoundError:
        return "gh is not installed — the GitHub door has no key"
    except subprocess.TimeoutExpired:
        return "gh auth status timed out"
    return ""


# ------------------------------------------------------------- one repo, read
def read_repo(name: str) -> dict:
    """Read every source for one repo. Each source fails alone, loudly, with its reason."""
    out: dict = {"repo": name, "checked_at": int(time.time()), "data": {}, "unread": [], "needs": []}
    data = out["data"]

    try:  # repo — and it is the ONLY source whose failure is fatal: without it the rest is guesswork
        meta = gh_json(["api", f"repos/{name}"])
        data["repo"] = {
            "default_branch": (meta or {}).get("default_branch") or "main",
            "issues": bool((meta or {}).get("has_issues")),
            "archived": bool((meta or {}).get("archived")),
            "private": bool((meta or {}).get("private")),
        }
    except (RuntimeError, json.JSONDecodeError, subprocess.TimeoutExpired) as exc:
        out["unread"].append({"source": "repo", "reason": f"the repository could not be read — {exc}"})
        return out
    default_branch = data["repo"]["default_branch"]

    try:
        issues = gh_json([
            "issue", "list", "-R", name, "--state", "open", "--limit", str(ISSUE_LIMIT),
            "--json", "number,title,labels,createdAt,updatedAt,assignees,comments",
        ]) or []
        data["issues"] = [
            {
                "number": i.get("number"),
                "title": i.get("title"),
                "labels": [l.get("name") for l in (i.get("labels") or []) if isinstance(l, dict)],
                "created": i.get("createdAt"),
                "updated": i.get("updatedAt"),
                "assignees": [a.get("login") for a in (i.get("assignees") or []) if isinstance(a, dict)],
                "comments": i.get("comments"),
            }
            for i in issues
            if isinstance(i, dict)
        ]
    except (RuntimeError, json.JSONDecodeError, subprocess.TimeoutExpired) as exc:
        out["unread"].append({"source": "issues", "reason": str(exc)})

    try:
        prs = gh_json([
            "pr", "list", "-R", name, "--state", "open", "--limit", "50",
            "--json", "number,title,headRefName,reviewDecision,mergeable,statusCheckRollup,updatedAt",
        ]) or []
        data["prs"] = [
            {
                "number": p.get("number"),
                "title": p.get("title"),
                "head": p.get("headRefName"),
                "review": p.get("reviewDecision") or "",
                "mergeable": p.get("mergeable") or "",
                "updated": p.get("updatedAt"),
                "failing": [
                    c.get("name") or c.get("context")
                    for c in (p.get("statusCheckRollup") or [])
                    if isinstance(c, dict)
                    and c.get("conclusion") not in (None, "SUCCESS", "SKIPPED", "NEUTRAL")
                ],
            }
            for p in prs
            if isinstance(p, dict)
        ]
    except (RuntimeError, json.JSONDecodeError, subprocess.TimeoutExpired) as exc:
        out["unread"].append({"source": "prs", "reason": str(exc)})

    try:
        runs = gh_json([
            "run", "list", "-R", name, "--branch", default_branch, "--limit", "5",
            "--json", "databaseId,name,status,conclusion,createdAt",
        ]) or []
        latest = next((r for r in runs if isinstance(r, dict) and r.get("conclusion")), None)
        data["base"] = {
            "branch": default_branch,
            "conclusion": (latest or {}).get("conclusion") or "unknown",
            "run": (latest or {}).get("databaseId"),
            "name": (latest or {}).get("name"),
        }
    except (RuntimeError, json.JSONDecodeError, subprocess.TimeoutExpired) as exc:
        out["unread"].append({"source": "runs", "reason": str(exc)})

    alerts: dict = {"vulnerability": None, "dependabot": None}
    for kind, path in (("vulnerability", "vulnerability-alerts"), ("dependabot", "dependabot/alerts")):
        try:
            payload = gh_json(["api", f"repos/{name}/{path}"])
            alerts[kind] = len(payload) if isinstance(payload, list) else 0
        except (RuntimeError, json.JSONDecodeError, subprocess.TimeoutExpired) as exc:
            reason = str(exc)
            low = reason.lower()
            # A repository with the feature switched off is not a fault, and must not be
            # reported as one; a CREDENTIAL gap is one fact about the seat, not 22 faults
            # (measured: it printed the same 150-character scope error for every repo), so it
            # is reported per repo in one short line and once as a `needs` row with the fix.
            if "404" in reason or "not enabled" in low or "disabled" in low:
                alerts[kind] = "off"
            elif "scope" in low or "admin:repo_hook" in low or "security_events" in low:
                alerts[kind] = "denied"
                out["unread"].append({
                    "source": f"alerts:{kind}",
                    "reason": f"denied — the token has no scope for {kind} alerts",
                })
                out["needs"].append({
                    "what": f"{kind} alerts",
                    "fix": "gh auth refresh -h github.com -s security_events  (then this line disappears)",
                })
            else:
                out["unread"].append({"source": f"alerts:{kind}", "reason": reason})
                alerts[kind] = None
    data["alerts"] = alerts
    return out


# ---------------------------------------------------------------- the cache
def cache_path(cache_dir: str, name: str) -> str:
    return os.path.join(cache_dir, name.replace("/", "__") + ".json")


def load_cached(cache_dir: str, name: str, ttl: int) -> dict | None:
    path = cache_path(cache_dir, name)
    try:
        with open(path, encoding="utf-8") as fh:
            entry = json.load(fh)
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(entry, dict):
        return None
    if ttl == 0:
        # ttl 0 is "always re-read", not "expire within the same second" — the two are the
        # same arithmetic and one of them silently serves a stale read (measured in the test).
        return None
    if ttl > 0 and int(time.time()) - int(entry.get("checked_at") or 0) > ttl:
        return None
    return entry


def store_cached(cache_dir: str, entry: dict) -> None:
    os.makedirs(cache_dir, exist_ok=True)
    path = cache_path(cache_dir, entry["repo"])
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(entry, fh, ensure_ascii=False, indent=1)
    os.replace(tmp, path)


# ---------------------------------------------------------------- the picture
def summarise(entry: dict) -> dict:
    data = entry.get("data") or {}
    issues = data.get("issues")
    prs = data.get("prs")
    base = (data.get("base") or {}).get("conclusion") or "-"
    alerts = data.get("alerts") or {}
    alert_n = 0
    alert_unknown = False
    for value in alerts.values():
        if isinstance(value, int):
            alert_n += value
        elif value is None or value == "denied":
            alert_unknown = True
    if alert_unknown:
        # a count that hides an unread source is the false green this door exists to refuse
        alert_cell = f"{alert_n}+?"
    else:
        alert_cell = str(alert_n)
    unread = {u.get("source") for u in entry.get("unread") or []}
    state = "read"
    if not data.get("repo"):
        state = "unread"
    elif unread:
        state = "partial"
    return {
        "repo": entry.get("repo") or "?",
        "state": state,
        # a count that is a cap is not a count: `--limit 100` returning 100 says "at least 100"
        "issues": "-" if issues is None else (f"{len(issues)}+" if len(issues) >= ISSUE_LIMIT else len(issues)),
        "prs": "-" if prs is None else len(prs),
        "base": base,
        "alerts": alert_cell,
        "age_s": max(0, int(time.time()) - int(entry.get("checked_at") or 0)),
    }


def toon(rows: list[dict], unread: list[dict], summary: dict, needs: list[dict] | None = None) -> str:
    lines = [f"intake[{len(rows)}]{{repo,state,issues,prs,base,alerts,age_s}}:"]
    for r in rows:
        lines.append(
            '  "%s","%s","%s","%s","%s","%s","%s"'
            % (r["repo"], r["state"], r["issues"], r["prs"], r["base"], r["alerts"], r["age_s"])
        )
    if unread:
        lines.append(f"unread[{len(unread)}]{{repo,source,reason}}:")
        for u in unread:
            lines.append(
                '  "%s","%s","%s"' % (u["repo"], u["source"], str(u["reason"]).replace('"', "'"))
            )
    if needs:
        lines.append(f"needs[{len(needs)}]{{what,fix}}:")
        for n in needs:
            lines.append('  "%s","%s"' % (n["what"], str(n["fix"]).replace('"', "'")))
    lines.append(f"summary[{len(summary)}]{{key,value}}:")
    for key, value in summary.items():
        lines.append('  "%s","%s"' % (key, value))
    return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(prog="intake.py", add_help=True)
    ap.add_argument("--home", default=os.environ.get("YMIR_HOME", ""))
    ap.add_argument("--repo", action="append", default=[], help="project id (repeatable)")
    ap.add_argument("--ttl", type=int, default=DEFAULT_TTL, help="seconds a cached read stays good (0 = always re-read)")
    ap.add_argument("--limit", type=int, default=DEFAULT_LIMIT,
                    help="repos read this run (0 = no cap); the rest are deferred, named")
    ap.add_argument("--cache-only", action="store_true",
                    help="read the cache and nothing else — no network at all")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)

    if not args.home:
        sys.stderr.write("intake: the home is unresolved\nhelp: pass --home, or call through bin/forge/mjollnir.sh\n")
        return 2
    registry = os.path.join(args.home, "hodd", "identity", "projects.yaml")
    if not os.path.isfile(registry):
        sys.stderr.write(f"intake: no registry at {registry}\nhelp: bin/engine/ymir-install.sh seeds it\n")
        return 1
    rows = load_rows(registry)
    wanted = set(args.repo)
    if wanted:
        missing = wanted - {r.get("id") for r in rows}
        if missing:
            sys.stderr.write(f"intake: no such project: {', '.join(sorted(missing))}\n")
            return 2
        rows = [r for r in rows if r.get("id") in wanted]

    cache_dir = os.path.join(args.home, "state", "intake")

    entries: list[dict] = []
    unread: list[dict] = []
    deferred: list[dict] = []
    read_now = 0

    for row in rows:
        owner, repo = usable_git(row)
        if not owner:
            unread.append({
                "repo": str(row.get("id")),
                "source": "registry",
                "reason": "no usable git{} block — bin/agents/project-git.sh doctor names this row",
            })
            continue
        name = f"{owner}/{repo}"
        cached = load_cached(cache_dir, name, args.ttl)
        if cached is not None:
            entries.append(cached)
            continue
        if args.cache_only:
            stale = load_cached(cache_dir, name, -1)
            if stale is not None:
                entries.append(stale)
            else:
                unread.append({"repo": name, "source": "cache", "reason": "cache only, and nothing cached yet"})
            continue
        why_not = gh_unavailable()
        if why_not:
            unread.append({"repo": name, "source": "gh", "reason": why_not})
            continue
        if args.limit and read_now >= args.limit:
            deferred.append({"repo": name, "reason": f"deferred — this run reads {args.limit}"})
            continue
        try:
            entry = read_repo(name)
        except subprocess.TimeoutExpired:
            unread.append({"repo": name, "source": "gh", "reason": f"the read took longer than {GH_TIMEOUT}s"})
            continue
        entry["id"] = row.get("id")
        store_cached(cache_dir, entry)
        entries.append(entry)
        read_now += 1

    needs: list[dict] = []
    for entry in entries:
        for need in entry.get("needs") or []:
            if not any(n["what"] == need["what"] for n in needs):
                needs.append(need)
        for miss in entry.get("unread") or []:
            unread.append({"repo": entry.get("repo"), "source": miss.get("source"), "reason": miss.get("reason")})

    picture = [summarise(e) for e in entries]
    picture.sort(key=lambda r: (r["state"] != "read", r["repo"]))
    summary = {
        "rows": len(rows),
        "read": sum(1 for p in picture if p["state"] == "read"),
        "partial": sum(1 for p in picture if p["state"] == "partial"),
        "unread": len({u["repo"] for u in unread}),
        "deferred": len(deferred),
        "read_this_run": read_now,
        "ttl_s": args.ttl,
        "at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    }
    for d in deferred:
        unread.append({"repo": d["repo"], "source": "limit", "reason": d["reason"]})

    if args.json:
        print(json.dumps({
            "repos": entries,
            "summary": summary,
            "unread": unread,
            "needs": needs,
        }, ensure_ascii=False, indent=1))
        return 0
    sys.stdout.write(toon(picture, sorted(unread, key=lambda u: (u["repo"], u["source"])), summary, needs))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        raise SystemExit(130)
