#!/usr/bin/env python3
"""daily_moved.py — what moved today, read from the record (plan 252). Called by daily-line.sh.

Reads, for one day:
  * the home's commits (the machine's own housekeeping commits are left out)
  * the commits in every project checked out on this machine (hodd/identity/projects.yaml `clones`) and in the Ymir tree
  * mail sent that day (Gná's store hodd/memory/mail/messages.jsonl, direction "out"; the mail ledger, direction "out")
  * meeting records added that day under svartalfaheim/*/meetings/

It prints only what it has not printed before for that day (seen-ledger in the state dir), so daily-line.sh can run
several times a day and the daily log only grows by what is new. Nothing here writes outside the state dir; the log
itself is written by bin/records/daily-log.sh.

  daily_moved.py --home H --root R --state S [--date YYYY-MM-DD] [--dry-run]
  daily_moved.py --self-test
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import socket
import subprocess
import sys
import tempfile
from pathlib import Path

NOISE = re.compile(r"(the day's appends|learn-home|generated copies|snapshot|^Merge (branch|remote-tracking)|"
                   r"index re-seeded|log unioned|ledger snapshot|^wip\b)", re.I)


def git_subjects(repo: Path, day: str) -> list[str]:
    if not (repo / ".git").exists():
        return []
    nxt = (dt.date.fromisoformat(day) + dt.timedelta(days=1)).isoformat()
    try:
        out = subprocess.run(["git", "-C", str(repo), "log", "--all", "--no-merges", f"--since={day} 00:00",
                              f"--until={nxt} 00:00", "--format=%H\t%s"], capture_output=True, text=True,
                             timeout=30).stdout
    except Exception:
        return []
    rows, seen = [], set()
    for line in out.splitlines():
        sha, _, subj = line.partition("\t")
        if subj and subj not in seen and not NOISE.search(subj):
            seen.add(subj)
            rows.append((sha[:10], subj))
    return rows


def clones(home: Path) -> list[tuple[str, Path]]:
    host = socket.gethostname()
    f = home / "hodd/identity/projects.yaml"
    out = []
    if not f.exists():
        return out
    try:
        import yaml
        doc = yaml.safe_load(f.read_text(encoding="utf-8"))
    except Exception:
        return out
    items = doc if isinstance(doc, list) else (doc or {}).get("projects", [])
    for p in items or []:
        c = (p or {}).get("clones") or {}
        path = c.get(host) if isinstance(c, dict) else None
        if path and Path(path).is_dir():
            out.append((str(p.get("name") or p.get("id")), Path(path)))
    return out


def sent_mail(home: Path, day: str) -> list[tuple[str, str]]:
    rows = []
    for name in ("messages.jsonl", "ledger.jsonl"):
        f = home / "hodd/memory/mail" / name
        if not f.exists():
            continue
        for line in f.read_text(encoding="utf-8", errors="replace").splitlines():
            try:
                r = json.loads(line)
            except json.JSONDecodeError:
                continue
            if r.get("direction") != "out":
                continue
            when = str(r.get("received_at") or r.get("ts") or r.get("date") or "")
            if not when.startswith(day):
                continue
            key = str(r.get("id") or r.get("gmail_id") or r.get("subject"))
            to = str(r.get("to") or r.get("to_header") or "")
            n = len([a for a in re.split(r"[,;]", to) if "@" in a]) or 1
            rows.append((key, f"{r.get('subject') or '(no subject)'} — to {n} recipient(s)"))
    return rows


def meetings(home: Path, day: str) -> list[tuple[str, str]]:
    nxt = (dt.date.fromisoformat(day) + dt.timedelta(days=1)).isoformat()
    try:
        out = subprocess.run(["git", "-C", str(home), "log", "--diff-filter=A", "--name-only", "--format=",
                              f"--since={day} 00:00", f"--until={nxt} 00:00", "--", "svartalfaheim/*/meetings/*"],
                             capture_output=True, text=True, timeout=30).stdout
    except Exception:
        return []
    return [(p, p) for p in sorted({l.strip() for l in out.splitlines() if l.strip()})]


def collect(home: Path, root: Path, day: str) -> list[tuple[str, str, str]]:
    """(section, key, text) for everything that moved that day."""
    items = []
    for sha, subj in git_subjects(home, day):
        items.append(("home", f"home:{sha}", subj))
    repos = [("Ymir", root)] + [c for c in clones(home) if c[1].resolve() != root.resolve()]
    for name, path in repos:
        for sha, subj in git_subjects(path, day):
            items.append((f"repo {name}", f"{path}:{sha}", subj))
    for key, text in sent_mail(home, day):
        items.append(("mail sent", f"mail:{key}", text))
    for key, text in meetings(home, day):
        items.append(("meetings recorded", f"meeting:{key}", text))
    return items


def render(items: list[tuple[str, str, str]]) -> str:
    if not items:
        return ""
    out, sections = ["what moved (from the record):"], {}
    for sec, _, text in items:
        sections.setdefault(sec, []).append(text)
    for sec, texts in sections.items():
        out.append(f"  {sec} ({len(texts)}):")
        out += [f"    · {t}" for t in texts[:25]]
        if len(texts) > 25:
            out.append(f"    · … and {len(texts) - 25} more")
    return "\n".join(out)


def run(home: Path, root: Path, state: Path, day: str, dry: bool) -> str:
    seen_file = state / "daily-line-seen.json"
    try:
        seen = json.loads(seen_file.read_text())
    except Exception:
        seen = {}
    done = set(seen.get(day, []))
    new = [i for i in collect(home, root, day) if hashlib.sha1(i[1].encode()).hexdigest() not in done]
    text = render(new)
    if new and not dry:
        done |= {hashlib.sha1(i[1].encode()).hexdigest() for i in new}
        seen = {k: v for k, v in seen.items() if k >= (dt.date.fromisoformat(day) - dt.timedelta(days=14)).isoformat()}
        seen[day] = sorted(done)
        state.mkdir(parents=True, exist_ok=True)
        seen_file.write_text(json.dumps(seen) + "\n")
    return text


def self_test() -> int:
    fails = []
    with tempfile.TemporaryDirectory() as t:
        home, root, state = Path(t, "home"), Path(t, "root"), Path(t, "state")
        for r in (home, root):
            r.mkdir()
            subprocess.run(["git", "init", "-q", str(r)], check=True)
            subprocess.run(["git", "-C", str(r), "config", "user.email", "t@example.invalid"], check=True)
            subprocess.run(["git", "-C", str(r), "config", "user.name", "t"], check=True)
        (home / "svartalfaheim/acme/meetings").mkdir(parents=True)
        (home / "svartalfaheim/acme/meetings/m.md").write_text("# m\n")
        subprocess.run(["git", "-C", str(home), "add", "."], check=True)
        subprocess.run(["git", "-C", str(home), "commit", "-qm", "acme: the meeting recorded"], check=True)
        subprocess.run(["git", "-C", str(home), "commit", "-q", "--allow-empty", "-m", "nidavellir: the day's appends"], check=True)
        (root / "f").write_text("x")
        subprocess.run(["git", "-C", str(root), "add", "."], check=True)
        subprocess.run(["git", "-C", str(root), "commit", "-qm", "feature: a thing"], check=True)
        (home / "hodd/memory/mail").mkdir(parents=True)
        today = dt.date.today().isoformat()
        (home / "hodd/memory/mail/ledger.jsonl").write_text(
            json.dumps({"direction": "out", "ts": today + "T10:00:00Z", "to": "a@example.invalid,b@example.invalid",
                        "subject": "the thread", "gmail_id": "g1"}) + "\n")
        first = run(home, root, state, today, False)
        for want in ("acme: the meeting recorded", "feature: a thing", "the thread — to 2 recipient(s)",
                     "svartalfaheim/acme/meetings/m.md"):
            if want not in first:
                fails.append(f"missing: {want}")
        if "day's appends" in first:
            fails.append("housekeeping noise was logged")
        if run(home, root, state, today, False):
            fails.append("a second run logged the same items again")
    for f in fails:
        print("FAIL", f)
    print(f"daily_moved self-test: {'ok' if not fails else str(len(fails)) + ' failure(s)'}")
    return 1 if fails else 0


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(prog="daily_moved.py")
    ap.add_argument("--home")
    ap.add_argument("--root")
    ap.add_argument("--state")
    ap.add_argument("--date", default=dt.date.today().isoformat())
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args(argv)
    if a.self_test:
        return self_test()
    if not (a.home and a.root and a.state):
        print("daily_moved: --home, --root and --state are required (daily-line.sh passes them)", file=sys.stderr)
        return 2
    sys.stdout.write(run(Path(a.home), Path(a.root), Path(a.state), a.date, a.dry_run))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
