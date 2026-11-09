#!/usr/bin/env python3
"""assistant_brief.py — Skírnir's database: the house's current state, compiled into ONE dated briefing.

    assistant-brief.sh refresh            compile today's briefing, file it, observe it into the well
    assistant-brief.sh show [date]        print a briefing
    assistant-brief.sh recall <question>  the well first (the briefing's tags), then the wider store
    assistant-brief.sh status             what he currently knows, and whether it is STALE

WHY (plan 227 §S1.5, the Allfather's word 2026-11-09): an agent with a mind but no current knowledge is
a clever stranger. A model reasons over PROSE, not over a directory listing — so the plan ledger, the
errand record and the git record are read live by their own doors and TIED TOGETHER in sentences,
filed as a dated briefing, and observed into the one well under a STABLE tag.

WHAT "HIS DATABASE" IS NOT (plan 227 §S1.5, and he is emphatic about it):
  * not a second memory store — the well already exists (engram, `bin/records/mimir.sh`), and a private
    shelf beside it is how two memories start disagreeing. The briefing is CONTENT in the one well.
  * not a copy of the plans — a copy is stale the hour it is written. Every line here names the record
    it came from, so a reader can always go and ask that record.
  * not a vector index he maintains — the well embeds and recalls; he tags.

SOURCES, each through the door that already owns it — never a second implementation:

```
sources[6]{source,door,what_it_yields}:
  "plans","bin/gates/plan-audit.sh --json (the shelf) + the ledger index + each plan's CHANGE LOG","what is open, what moved this week, and the decision line itself"
  "errands","bin/agents/eindri-liveness.sh list","who is working, whose pane cannot be read, and what died"
  "pull requests","gh pr list","what shipped this week, and what waits for his hand"
  "decisions","bin/records/daily-log.sh list|show","the day's decisions, by the house's own log"
  "the record","bin/records/ymir-state.sh runes path","the acts, chained"
  "the well","bin/records/mimir.sh recall|observe","what the house already learned, and where this goes"
```

THE BOUNDS (plan 227 §S1.5.4) are enforced here, not promised:
  * a briefing is the house's INTERNAL state — for any tier but `owner` this door REFUSES, naming the limit;
  * no vault, no NDA, no other tenant: the sources below are the plans, the errands, the PRs and the
    daily log, and a shelf that is excluded upstream is excluded here by construction;
  * an answer about this week cites the briefing's DATE — `recall` and `status` both print it.

Exit: 0 ok · 1 a fault · 2 usage · 3 refused (a tier that may not hear the briefing).
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time

VERSION = "1.0.0"
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))

TAG = "assistant-briefing"          # the STABLE tag: one tag, every briefing, forever
WINDOW_DAYS = 7                     # "this week"
STALE_HOURS = 26                    # a briefing untouched for more than a day says so out loud


# ── the home, resolved the one way (Rule 07) ───────────────────────────────────────────────────────
def home() -> str:
    env = os.environ.get("YMIR_HOME")
    if env:
        return os.path.expanduser(env)
    lib = os.path.join(ROOT, "bin", "vault", "hoard-lib.sh")
    out = run(["bash", "-c",
               f'. "{lib}" >/dev/null 2>&1; r=""; ymir_home_root r 2>/dev/null; printf "%s" "$r"']).strip()
    if out and os.path.isdir(out):
        return out
    raise SystemExit("assistant-brief: the hoard is unresolved — set YMIR_HOME")


def read_text(path: str) -> str:
    """One reader, closed properly: an unclosed handle is a leak the next hand has to hunt."""
    try:
        with open(path, encoding="utf-8", errors="ignore") as fh:
            return fh.read()
    except Exception:
        return ""


def tail_text(text: str, limit: int) -> str:
    text = (text or "").strip()
    return text if len(text) <= limit else text[: limit - 1].rstrip() + "…"


def run(cmd: list[str], timeout: int = 90) -> str:
    """A door is a command. A door that fails prints its reason; it never takes the briefing with it."""
    try:
        done = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except Exception as exc:                      # no door, no shell, no time
        print(f"assistant-brief: {os.path.basename(cmd[0])} unavailable — {type(exc).__name__}",
              file=sys.stderr)
        return ""
    if done.returncode != 0 and done.stderr.strip():
        print(f"assistant-brief: {os.path.basename(cmd[0])}: "
              f"{tail_text(done.stderr.strip().splitlines()[-1], 160)}", file=sys.stderr)
    return done.stdout or ""


def door(*parts: str) -> str:
    return os.path.join(ROOT, *parts)


# ── the window ─────────────────────────────────────────────────────────────────────────────────────
def today() -> str:
    return time.strftime("%Y-%m-%d")


def day_offsets(days: int) -> list[str]:
    now = time.time()
    return [time.strftime("%Y-%m-%d", time.localtime(now - 86400 * i)) for i in range(days + 1)]


def window_start(days: int = WINDOW_DAYS) -> str:
    return time.strftime("%Y-%m-%d", time.localtime(time.time() - 86400 * days))


# ── the plans: the ledger read live, never a copy ──────────────────────────────────────────────────
PLAN_TITLE = re.compile(r"^#\s+(.*\S)\s*$", re.M)
CHANGE_LINE = re.compile(r"^[-*]\s+\*\*(\d{4}-\d{2}-\d{2})([^*]*)\*\*\s*[—:-]+\s*(.+)$")
# the ledger index has TWO shapes on one shelf, and both are the index: an older table row and a
# newer bullet row. A reader that knows only one of them silently loses half the ledger's status —
# measured 2026-11-09: 24 rows read, and "no index row" printed for the 90 newest plans.
INDEX_ROW = re.compile(r"^\|\s*(\d+)\s*\|\s*(.*?)\s*\|\s*`([^`]+)`\s*\|\s*(.*?)\s*\|\s*$")
INDEX_BULLET = re.compile(r"^-\s+\*\*Plan\s+(\d+)\*\*\s*[—:-]+\s*\[([^\]]*)\]\(([^)]*)\)\s*·\s*(.*)$")


def plans_shelf() -> str:
    """The shelf, asked of the gate that already knows it (`plan-audit.sh --json`)."""
    out = run(["bash", door("bin", "gates", "plan-audit.sh"), "--json"], timeout=180)
    try:
        data = json.loads(out or "{}")
        shelf = str(data.get("shelf") or "")
        if shelf and os.path.isdir(shelf):
            return shelf
    except Exception:
        pass
    return ""


def plans_read(window_from: str) -> dict:
    """Every plan's number, title, index status, and the CHANGE LOG lines inside the window."""
    shelf = plans_shelf()
    if not shelf:
        return {"ok": False, "why": "the ledger shelf was not found (bin/gates/plan-audit.sh)", "plans": {},
                "shelf": ""}
    index: dict[str, str] = {}
    readme = os.path.join(shelf, "README.md")
    try:
        for line in read_text(readme).splitlines():
            row = INDEX_ROW.match(line.strip())
            if row:
                number, title, _file, status = row.groups()
                # the SAME number can hold two rows on this shelf (a known, recorded collision);
                # the LAST row wins here and the briefing prints the raw status, never a guess.
                index[number] = (title.strip(), status.strip())
                continue
            bullet = INDEX_BULLET.match(line.strip())
            if bullet:
                number, title, _file, status = bullet.groups()
                index.setdefault(number, (title.strip(), status.strip()))
    except Exception:
        pass
    plans: dict[str, dict] = {}
    try:
        names = sorted(os.listdir(shelf))
    except Exception:
        names = []
    for name in names:
        if not name.endswith(".md") or name == "README.md":
            continue
        path = os.path.join(shelf, name)
        text = read_text(path)
        if not text:
            continue
        number = (re.match(r"^(\d+)", name) or [None, ""])[1]
        title = ""
        m = PLAN_TITLE.search(text[:4000])
        if m:
            title = m.group(1)
        title = re.sub(r"^Plan\s+\d+\s*[\u2014\u2013:-]+\s*", "", title).strip()
        if not title and number in index:
            title = index[number][0]
        if not title:
            title = name[:-3].split("-", 1)[-1].replace("-", " ")
        lines = []
        for line in text.splitlines():
            cm = CHANGE_LINE.match(line.strip())
            if cm and cm.group(1) >= window_from:
                lines.append({"date": cm.group(1), "what": tail_text(cm.group(3), 300),
                              "raw": line.strip()})
        if not lines and not title:
            continue
        plans[number] = {"number": number, "file": name, "title": title,
                         "status": index.get(number, ("", ""))[1],
                         "change_log": lines, "text": text}
    return {"ok": True, "why": "", "shelf": shelf, "plans": plans}


def plan_is_open(status: str) -> bool:
    """A KEYWORD test over the index row, and the briefing says so — the row is printed raw.

    The index status is prose written by many hands ("open — P0 forgeable now", "PR #568 merged
    2026-11-07", "twelve SOLVED … seven OPEN"). A keyword cannot be right about every one, so the
    test is deliberately narrow: a row that says it merged/landed/closed is NOT open; anything else
    is reported as open WITH its own words beside it, for a human to overrule in one glance.
    """
    low = (status or "").lower()
    if any(w in low for w in ("merged", "landed", "closed", "done —", "complete")):
        return False
    return True


def readable_line(line: str) -> str:
    """A traceable line a person can read — never the raw JSON of a TOON row.

    A plan records its decisions in TOON tables as often as in prose, so the line that names a PR is
    sometimes `"S8","Rödd could not reach the session…","bin/voice/rodd-arm.sh who·tell·hear — …"`.
    The fields are the truth; the punctuation is noise. This keeps the first two fields joined by a
    dash and says nothing that the row does not say.
    """
    s = line.strip().strip(",")
    fields = re.findall(r'"([^"]*)"', s)
    if len(fields) >= 2:
        return tail_text(f"{fields[0]} — {fields[1]}", 200)
    return tail_text(s, 200)


def pr_cross_reference(plans: dict) -> dict[str, list[tuple[str, str, str]]]:
    """PR number → [(plan number, plan title, the line that names it)]. Every line traceable."""
    found: dict[str, list[tuple[str, str, str]]] = {}
    pr_re = re.compile(r"#(\d{2,4})\b")
    for number, plan in plans.items():
        for line in plan["text"].splitlines():
            for m in pr_re.finditer(line):
                pr = m.group(1)
                if len(pr) < 3:
                    continue
                found.setdefault(pr, [])
                if number and all(other[0] != number for other in found[pr]):
                    found[pr].append((number, plan["title"], readable_line(line)))
    return found


# ── the errands: the liveness door, which is the record of who is alive ───────────────────────────
def state_dir() -> str:
    lib = os.path.join(ROOT, "bin", "vault", "hoard-lib.sh")
    out = run(["bash", "-c",
               f'. "{lib}" >/dev/null 2>&1; r=""; hoard_state_dir r 2>/dev/null; printf "%s" "$r"']).strip()
    return out if out and os.path.isdir(out) else ""


def errands_read(window_from: str) -> dict:
    out = run(["bash", door("bin", "agents", "eindri-liveness.sh"), "list"], timeout=240)
    rows = []
    for line in out.splitlines():
        if not line.strip().startswith('"'):
            continue
        parts = [f.strip('"') for f in line.strip().split('","')]
        if len(parts) < 4:
            continue
        rows.append({"id": parts[0], "verdict": parts[1], "pane": parts[2], "evidence": parts[3]})
    shelf = state_dir()
    alive = [r for r in rows if r["verdict"] == "ALIVE"]
    unreadable = [r for r in rows if r["verdict"] == "UNKNOWN"]
    dead = []
    for row in rows:
        ev = row["evidence"].lower()
        if "terminal: failed" not in ev:
            continue
        when = ""
        if shelf:
            try:
                when = time.strftime("%Y-%m-%d", time.localtime(
                    os.path.getmtime(os.path.join(shelf, row["id"] + ".status"))))
            except Exception:
                when = ""
        if when and when < window_from:
            continue
        dead.append(dict(row, date=when))
    return {"ok": bool(rows), "why": "" if rows else "bin/agents/eindri-liveness.sh list answered no rows",
            "alive": alive, "unreadable": unreadable, "dead": dead, "total": len(rows)}


# ── the pull requests: what shipped, and what waits for his hand ──────────────────────────────────
def prs_read(window_from: str) -> dict:
    fields = "number,title,mergedAt,headRefName,url"
    merged_raw = run(["gh", "pr", "list", "--state", "merged", "--limit", "300", "--json", fields],
                     timeout=180)
    open_raw = run(["gh", "pr", "list", "--state", "open", "--limit", "40",
                    "--json", "number,title,createdAt,headRefName,url"], timeout=120)
    merged, opened, why = [], [], ""
    try:
        for row in json.loads(merged_raw or "[]"):
            when = str(row.get("mergedAt") or "")[:10]
            if when and when >= window_from:
                merged.append({"number": str(row.get("number")), "title": str(row.get("title") or ""),
                               "date": when, "branch": str(row.get("headRefName") or ""),
                               "url": str(row.get("url") or "")})
    except Exception:
        why = "gh answered nothing usable for the merged list"
    try:
        for row in json.loads(open_raw or "[]"):
            opened.append({"number": str(row.get("number")), "title": str(row.get("title") or ""),
                           "date": str(row.get("createdAt") or "")[:10],
                           "branch": str(row.get("headRefName") or "")})
    except Exception:
        why = (why + "; " if why else "") + "gh answered nothing usable for the open list"
    if not merged and not opened and not why:
        why = "no merged or open pull requests answered"
    merged.sort(key=lambda r: (r["date"], r["number"]), reverse=True)
    return {"ok": bool(merged or opened) or not why, "why": why if not (merged or opened) else "",
            "merged": merged, "open": opened}


# ── the decisions: the house's own daily log, by its door ────────────────────────────────────────
def decisions_read(window_from: str, plans: dict, prs: dict) -> dict:
    days_raw = run(["bash", door("bin", "records", "daily-log.sh"), "list"], timeout=60)
    days = sorted({m.group(0) for m in re.finditer(r"\d{4}-\d{2}-\d{2}", days_raw)}, reverse=True)
    entries = []
    for day in [d for d in days if d >= window_from][:WINDOW_DAYS]:
        text = run(["bash", door("bin", "records", "daily-log.sh"), "show", day], timeout=60)
        for line in text.splitlines():
            s = line.strip()
            if not s.startswith("- "):
                continue
            body = re.sub(r"^-\s+\d{1,2}:\d{2}\s*", "", s)
            if len(body) < 40:
                continue                       # a heading or a stub, not a decision
            entries.append({"date": day, "text": tail_text(body, 400)})
    plan_decisions = []
    for number, plan in plans.items():
        for row in plan["change_log"]:
            plan_decisions.append({"date": row["date"], "plan": number, "title": plan["title"],
                                   "text": row["what"]})
    plan_decisions.sort(key=lambda r: (r["date"], r["plan"]), reverse=True)
    return {"ok": bool(entries or plan_decisions),
            "why": "" if (entries or plan_decisions) else "no daily log entries and no plan change logs in the window",
            "daily": entries[:24], "plan": plan_decisions[:40], "days": [d for d in days if d >= window_from][:WINDOW_DAYS]}


# ── the record: the runes ledger, its path asked of the state door ───────────────────────────────
def runes_read(window_from: str, limit: int = 14) -> dict:
    path = run(["bash", door("bin", "records", "ymir-state.sh"), "runes", "path"], timeout=60).strip()
    if not path or not os.path.isfile(path):
        return {"ok": False, "why": "the runes ledger path could not be resolved", "rows": []}
    rows = []
    try:
        with open(path, encoding="utf-8", errors="ignore") as fh:
            for line in fh:
                line = line.strip()
                if not line.startswith("{"):
                    continue
                try:
                    entry = json.loads(line)
                except Exception:
                    continue
                when = str(entry.get("timestamp") or "")[:10]
                if when and when >= window_from:
                    rows.append({"date": when, "actor": str(entry.get("actor") or "?"),
                                 "event": str(entry.get("event") or ""),
                                 "message": tail_text(str(entry.get("message") or ""), 160)})
    except Exception:
        pass
    return {"ok": bool(rows), "why": "" if rows else "no runes rows inside the window",
            "rows": rows[-limit:], "path": path}


# ── the briefing itself ───────────────────────────────────────────────────────────────────────────
def briefing_dir() -> str:
    return os.path.join(home(), "hodd", "memory", "assistant", "briefing")


def briefing_path(day: str) -> str:
    return os.path.join(briefing_dir(), f"{day}.md")


def render(day: str, stamp: str, window_from: str, plans: dict, errands: dict, prs: dict,
           decisions: dict, runes: dict) -> tuple[str, dict]:
    """One dated text. Every line names a record a reader can go and ask; nothing is invented."""
    shelf = plans.get("shelf", "")
    cross = pr_cross_reference(plans.get("plans") or {})
    open_plans, touched = [], []
    for number, plan in sorted((plans.get("plans") or {}).items(), key=lambda kv: kv[0], reverse=True):
        if plan["change_log"]:
            touched.append(plan)
        if plan["status"] and plan_is_open(plan["status"]):
            open_plans.append(plan)

    out: list[str] = []
    out.append(f"# Briefing — {day}")
    out.append("")
    out.append(f"stamp: {stamp} · window: {window_from} → {day} · tag: `{TAG}`")
    out.append(f"plans: `{shelf or 'unreadable'}` · errands: `bin/agents/eindri-liveness.sh` · "
               f"pull requests: `gh` · decisions: `hodd/memory/daily/` + the plans' change logs · "
               f"the record: `{runes.get('path') or 'unreadable'}`")
    out.append("")

    out.append("## What is in flight")
    if errands.get("ok"):
        if errands["alive"]:
            out.append(f"- {len(errands['alive'])} errand(s) alive: " + ", ".join(
                f"`{r['id']}` ({r['pane']})" for r in errands["alive"][:12]))
        else:
            out.append("- no errand is alive")
        if errands["unreadable"]:
            out.append(f"- {len(errands['unreadable'])} pane(s) could not be read — UNKNOWN, not dead: "
                       + ", ".join(f"`{r['id']}`" for r in errands["unreadable"][:8]))
        if errands["dead"]:
            out.append(f"- {len(errands['dead'])} errand(s) DIED in the window: " + ", ".join(
                f"`{r['id']}`" + (f" ({r['date']})" if r.get("date") else "") for r in errands["dead"][:10]))
    else:
        out.append(f"- the errand record did not answer: {errands.get('why') or 'no reason given'}")
    if prs.get("open"):
        out.append(f"- {len(prs['open'])} pull request(s) open, waiting for his hand: " + ", ".join(
            f"#{r['number']} {tail_text(r['title'], 70)}" for r in prs["open"][:8]))
    elif not prs.get("why"):
        out.append("- no pull request is open")
    out.append("")

    out.append("## What shipped this week")
    if prs.get("merged"):
        for row in prs["merged"][:20]:
            # THE TRACEABLE PART COMES FIRST: the plan that decided it, and the decision in its own
            # words. A reader (and a recall) that stops after one clause must already have the plan,
            # the decision and the date — the PR's title is the last thing on the line, not the first.
            behind = cross.get(row["number"]) or []
            head = f"- #{row['number']}"
            if behind:
                number, _title, line = behind[0]
                head += f" · plan {number} — «{tail_text(line, 160)}»"
            out.append(f"{head} · merged {row['date']} · {tail_text(row['title'], 110)}")
        if len(prs["merged"]) > 20:
            out.append(f"- …and {len(prs['merged']) - 20} more merged inside the window")
    else:
        out.append(f"- nothing merged in the window{(' — ' + prs['why']) if prs.get('why') else ''}")
    out.append("")

    out.append("## Plans touched this week")
    if touched:
        for plan in touched[:24]:
            last = plan["change_log"][0] if plan["change_log"] else {"date": "", "what": ""}
            status = plan["status"] or "no index row"
            out.append(f"- {plan['number'] or '?'} · {tail_text(plan['title'] or plan['file'], 90)} — "
                       f"{last['date']}: {tail_text(last['what'], 200)} [index: {tail_text(status, 90)}]")
    else:
        out.append("- no plan's change log moved inside the window")
    if open_plans:
        out.append("")
        out.append(f"### Still open by its index row ({len(open_plans)})")
        for plan in open_plans[:20]:
            out.append(f"- {plan['number'] or '?'} · {tail_text(plan['title'] or plan['file'], 90)} — "
                       f"{tail_text(plan['status'], 120)}")
    out.append("")

    out.append("## Decisions")
    plan_dec = decisions.get("plan") or []
    daily = decisions.get("daily") or []
    if plan_dec:
        for row in plan_dec[:20]:
            out.append(f"- {row['date']} · plan {row['plan'] or '?'} · {row['text']}")
    for row in daily[:12]:
        out.append(f"- {row['date']} · daily log · {tail_text(row['text'], 300)}")
    if not plan_dec and not daily:
        out.append(f"- no decision was recorded in the window{(' — ' + decisions['why']) if decisions.get('why') else ''}")
    out.append("")

    out.append("## What waits on the Allfather")
    waiting = []
    if prs.get("open"):
        waiting.append(f"{len(prs['open'])} open pull request(s) — his hand seals every merge "
                       "(" + ", ".join(f"#{r['number']}" for r in prs["open"][:8]) + ")")
    asks = run(["bash", os.path.join(HERE, "asks.sh"), "list", "--open"], timeout=60)
    n_asks = len([l for l in asks.splitlines() if l.strip().startswith('"ask-')])
    if n_asks:
        waiting.append(f"{n_asks} question(s) Skírnir could not answer, waiting for him")
    # A plan is waiting on HIM when its own row says so. "his word" was the first test and it was
    # noise: nearly every row on this shelf opens with his word, so it listed the whole ledger
    # (measured 2026-11-09 — seven plans "waiting", six of them not). The test is therefore about
    # the OPERATOR being the blocker, and the row is printed raw beside it.
    # ...and it reads only the OPENING of the row, where a status actually states a status: plan 224's
    # row says "a blocked PR" forty words in, describing work already done, and a whole-row test read
    # that as a plan blocked on him (measured 2026-11-09).
    blocked = [p for p in open_plans if re.search(
        r"waiting on|waits on|blocked|NOT DONE|not done|needs his|his hand|his decision|"
        r"for the operator|owed to his|seal", (p["status"] or "")[:140], re.I)]
    for plan in blocked[:6]:
        waiting.append(f"plan {plan['number']} waits: {tail_text(plan['status'], 130)}")
    out += ([f"- {w}" for w in waiting] or ["- nothing is waiting on him"])
    out.append("")

    out.append("## The record — recent runes")
    if runes.get("ok"):
        for row in runes["rows"]:
            out.append(f"- {row['date']} · {row['actor']} · {row['event']}: {row['message']}")
    else:
        out.append(f"- {runes.get('why') or 'the ledger did not answer'}")
    out.append("")

    out.append("## How this was measured")
    out.append(f"- plans: {len(plans.get('plans') or {})} plan files read; `open` is a KEYWORD test over "
               f"the index row, and the row is printed beside it so a human can overrule it in a glance")
    out.append(f"- errands: {errands.get('total', 0)} rows from the liveness door; a terminal `failed` "
               f"inside the window counts as dead")
    out.append(f"- pull requests: `gh pr list` merged (last {WINDOW_DAYS} days) and open")
    out.append(f"- decisions: {len(daily)} daily entries and {len(plan_dec)} change-log lines")
    out.append("- `what waits on him` is a KEYWORD test over the FIRST 140 CHARACTERS of the index row "
               "(the opening, where a row states its status), never over the whole sentence")
    out.append("")

    counts = {"open_plans": len(open_plans), "touched": len(touched), "alive": len(errands.get("alive") or []),
              "dead": len(errands.get("dead") or []), "merged": len(prs.get("merged") or []),
              "open_prs": len(prs.get("open") or []),
              "decisions": len(plan_dec) + len(daily), "waiting": len(waiting)}
    return "\n".join(out), counts


def well_observe(day: str, text: str) -> tuple[bool, str]:
    """The briefing goes into the ONE well, under a STABLE tag, as a decision record.

    The well's gate drops anything that answers none of its three questions; a briefing is a decision
    record with rationale, so it is presented as one (`--shape decision`) — never a dump.
    """
    summary = (f"Briefing {day} — the house's state for the week to {day}.\n\n" + text)
    body = summary if len(summary) <= 7000 else summary[:6990] + "\n…"
    out = run(["bash", door("bin", "records", "mimir.sh"), "observe", body,
               "--tags", f"{TAG},briefing:{day},domain:skirnir", "--source", "skirnir",
               "--task", "assistant-briefing", "--privacy", "internal",
               "--shape", "decision", "--salience", "0.8"], timeout=180)
    stored = '"true"' in out or re.search(r"^\s*\"?true\"?", out or "", re.M) is not None
    if not stored:
        print(f"assistant-brief: the well did not store it — {tail_text(out.strip(), 200)}", file=sys.stderr)
    return stored, tail_text(out.strip().replace("\n", " "), 200)


# ── the four verbs ────────────────────────────────────────────────────────────────────────────────
def only_owner(tier: str) -> None:
    """THE BOUND (plan 227 §S1.5.4): a briefing is the house's internal state and never leaves."""
    if tier == "owner":
        return
    print('assistant-brief: refused — the briefing is the house\'s internal state, and it does not '
          'leave for a collaborator, a known contact or a stranger. Ask me about your own project.')
    raise SystemExit(3)


def verb_refresh(tier: str) -> int:
    only_owner(tier)
    day, stamp, window_from = today(), time.strftime("%Y-%m-%dT%H:%M:%S%z"), window_start()
    plans = plans_read(window_from)
    errands = errands_read(window_from)
    prs = prs_read(window_from)
    decisions = decisions_read(window_from, plans.get("plans") or {}, prs)
    runes = runes_read(window_from)
    text, counts = render(day, stamp, window_from, plans, errands, prs, decisions, runes)

    os.makedirs(briefing_dir(), exist_ok=True)
    path = briefing_path(day)
    write(path, f"<!-- briefing refresh {stamp} -->\n\n{text}\n")
    stored, well_note = well_observe(day, text)
    refreshes = count_refreshes(path)
    line = (f"My database is refreshed: briefing {day} (refresh {refreshes} today) — "
            f"{counts['merged']} merged, {counts['decisions']} decision(s), {counts['alive']} errand(s) alive, "
            f"{counts['waiting']} thing(s) waiting on you")
    print("briefing[1]{verb,date,path,refreshes,merged,decisions,alive,dead,open_prs,waiting,well,line}:")
    print(f'  "refresh","{day}","{os.path.relpath(path, home())}",{refreshes},{counts["merged"]},'
          f'{counts["decisions"]},{counts["alive"]},{counts["dead"]},{counts["open_prs"]},'
          f'{counts["waiting"]},"{"stored" if stored else "not-stored"}","{line}"')
    if not stored:
        print(f"# well: {well_note}", file=sys.stderr)
    return 0


def write(path: str, text: str) -> None:
    """APPEND, never rewrite (Rule 06): a second refresh the same day is a new dated section."""
    exists = os.path.isfile(path) and os.path.getsize(path) > 0
    with open(path, "a", encoding="utf-8") as fh:
        if exists:
            fh.write("\n")
        fh.write(text)


def count_refreshes(path: str) -> int:
    return read_text(path).count("<!-- briefing refresh")


def newest_briefing() -> tuple[str, str, float]:
    """(date, path, mtime) of the newest briefing, or ("", "", 0)."""
    shelf = briefing_dir()
    try:
        names = sorted(n for n in os.listdir(shelf) if re.match(r"^\d{4}-\d{2}-\d{2}\.md$", n))
    except Exception:
        return "", "", 0.0
    if not names:
        return "", "", 0.0
    path = os.path.join(shelf, names[-1])
    try:
        return names[-1][:10], path, os.path.getmtime(path)
    except Exception:
        return names[-1][:10], path, 0.0


def verb_show(tier: str, day: str = "") -> int:
    only_owner(tier)
    if not day:
        day, path, _ = newest_briefing()
        if not day:
            print("assistant-brief: no briefing is filed yet — run `assistant-brief.sh refresh`")
            return 1
    else:
        path = briefing_path(day)
    if not os.path.isfile(path):
        print(f"assistant-brief: there is no briefing for {day} — "
              f"`assistant-brief.sh status` says what I do hold")
        return 1
    sys.stdout.write(read_text(path))
    return 0


def well_recall(question: str, tag: str = "", k: int = 3) -> list[dict]:
    args = ["bash", door("bin", "records", "mimir.sh"), "recall", question, "--k", str(k)]
    if tag:
        args += ["--tag", tag]
    out = run(args, timeout=180)
    rows = []
    for line in out.splitlines():
        s = line.strip()
        m = re.match(r'^([0-9.]+),"(.*?)","(.*?)","(.*)"$', s)
        if m:
            rows.append({"score": float(m.group(1)), "source": m.group(2),
                         "store": m.group(3), "title": m.group(4)})
    return rows


def briefing_lines(day: str) -> list[str]:
    path = briefing_path(day)
    return read_text(path).splitlines()


DECISION_ROW = re.compile(r"plan \d+")


def rank_lines(lines: list[str], words: set[str]) -> list[tuple[float, str]]:
    """Which line of a briefing ANSWERS the question — not which one merely shares a word.

    A briefing line comes in three shapes and they are not equally answerable: a DECISION row
    (`2026-11-09 · plan 224 · …`), a SHIPPED row (`- #599 … merged … · plan 224 — «…»`), and the
    long "plans touched" row that carries a whole plan's change log and its index row. All three
    match the same words, and on 2026-11-09 the long one won and was read out — the answer was a
    paragraph where a sentence was owed. So a row that NAMES a plan and reads short is preferred,
    and a row over 320 characters is pushed down: it is the context, not the answer.
    """
    scored = []
    for line in lines:
        s = line.strip()
        if not s or s.startswith("<!--") or s.startswith("#"):
            continue
        low = s.lower()
        hit = sum(1 for w in words if w in low)
        if not hit:
            continue
        score = hit / max(1, len(words))
        if DECISION_ROW.search(s):
            score += 0.5
        if s.startswith("- #"):
            score += 0.4
        if len(s) > 320:
            score -= 0.35
        if re.match(r"^- \d{3} · ", s) or "[index:" in s:
            # the "plans touched this week" row: it carries a whole change log and the index row,
            # so it is the CONTEXT behind an answer and never the answer itself
            score -= 0.5
        scored.append((score, s))
    scored.sort(key=lambda r: r[0], reverse=True)
    seen, unique = set(), []
    for score, s in scored:
        key = s[:70]
        if key in seen:
            continue
        seen.add(key)
        unique.append((score, s))
    return unique


def verb_recall(tier: str, question: str) -> int:
    only_owner(tier)
    stop = set("the a an and or of in on at to for with by is are was were be it its this that "
               "what which who how do does did we you our about".split())
    words = {w for w in re.findall(r"[a-z0-9][a-z0-9_-]{2,}", question.lower()) if w not in stop}
    hits = well_recall(question, TAG, 3)
    days: list[str] = []
    for row in hits:
        m = re.search(r"\b(\d{4}-\d{2}-\d{2})\b", row["title"])
        if m and m.group(1) not in days:
            days.append(m.group(1))
    found: list[tuple[str, str]] = []
    for day in days[:2]:
        for score, line in rank_lines(briefing_lines(day), words)[:4]:
            found.append((day, line))
    if not found and os.path.isdir(briefing_dir()):
        # the well has not indexed this yet, or the words changed: the shelf is the same content
        for day, _path, _m in reversed([(n[:10], os.path.join(briefing_dir(), n), 0.0)
                                        for n in sorted(os.listdir(briefing_dir()))
                                        if re.match(r"^\d{4}-\d{2}-\d{2}\.md$", n)]):
            for score, line in rank_lines(briefing_lines(day), words)[:3]:
                found.append((day, line))
            if found:
                break
    if not found:
        wider = well_recall(question, "", 5)
        if wider:
            print(f"briefing_recall[{len(wider)}]{{date,line}}:")
            for row in wider:
                m = re.search(r"\b(\d{4}-\d{2}-\d{2})\b", row["title"])
                print(f'  "{m.group(1) if m else "no-date"}","{tail_text(row["title"], 200)}"')
            return 0
        print('briefing_recall[0]{date,line}:')
        print('  "none","no briefing and no well episode covers that"')
        return 1
    print(f"briefing_recall[{len(found)}]{{date,line}}:")
    for day, line in found:
        clean = re.sub(r'^[-*]\s*', "", line).replace('"', "'").strip()
        print(f'  "{day}","{tail_text(clean, 240)}"')
    return 0


def verb_status(tier: str) -> int:
    only_owner(tier)
    day, path, mtime = newest_briefing()
    age_hours = (time.time() - mtime) / 3600 if mtime else 0.0
    stale = "no" if (day and age_hours <= STALE_HOURS) else "yes"
    refreshes = count_refreshes(path) if day else 0
    try:
        days = len([n for n in os.listdir(briefing_dir())
                    if re.match(r"^\d{4}-\d{2}-\d{2}\.md$", n)])
    except Exception:
        days = 0
    health = run(["bash", door("bin", "records", "mimir.sh"), "health"], timeout=60)
    # the well's own door says `"WARM",<n>,"online","true"`; ask IT, never a guess of our own
    low = health.lower()
    well = ("bridge" if '"online"' in low or "\"warm\"" in low or "warm" in low
            else ("offline" if health.strip() else "unknown"))
    if not day:
        line = ("My database has no briefing yet — nothing has been compiled, so I would be answering "
                "from the plans and the well alone. Say 'update your database' and I will build one.")
    elif stale == "yes":
        line = (f"My newest briefing is {day} — that is {age_hours:.0f} hours old, so it is STALE: "
                f"anything I say about this week may be out of date. Say 'update your database'.")
    else:
        line = (f"My newest briefing is {day}, refreshed {age_hours:.0f} hours ago, and it is current "
                f"({refreshes} refresh(es) filed that day; {days} day(s) on the shelf).")
    print("briefing_status[1]{newest,age_hours,refreshes,days,stale,well,line}:")
    print(f'  "{day or "none"}",{age_hours:.0f},{refreshes},{days},"{stale}","{well}","{line}"')
    return 0


def main(argv: list[str]) -> int:
    verb = argv[1] if len(argv) > 1 else ""
    tier = "owner"
    rest: list[str] = []
    args = argv[2:]
    i = 0
    while i < len(args):
        if args[i] == "--tier" and i + 1 < len(args):
            tier = args[i + 1]
            i += 2
            continue
        rest.append(args[i])
        i += 1
    if verb in ("-v", "-V", "--version"):
        print(VERSION)
        return 0
    if verb == "refresh":
        return verb_refresh(tier)
    if verb == "show":
        return verb_show(tier, rest[0] if rest else "")
    if verb == "recall":
        if not rest:
            print('assistant-brief: recall needs a question\nhelp: assistant-brief.sh recall "<question>"',
                  file=sys.stderr)
            return 2
        return verb_recall(tier, " ".join(rest))
    if verb == "status":
        return verb_status(tier)
    print("assistant-brief.sh [refresh | show [date] | recall <question> | status] [--tier owner]")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
