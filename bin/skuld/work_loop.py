#!/usr/bin/env python3
"""work_loop.py — the work loop: keeps every seat's coders fed, so finished work is followed by the next piece.

Skuld owns what is owed. This door asks, on each cycle and for THIS machine only: how many coders may stand here
(the fleet runbook), how many do, and what is the next piece of work. It tops the seat up to its limit, taking
work in this order:

    (a) a judge's NEEDS-REWORK on an open PR whose author is this machine, or which no machine claims
        -> a coder errand on that PR's branch;
    (b) an open PR with no judge for its current head -> a judge. That is the review loop's job
        (bin/forge/review-watch.sh --keeper): this door CALLS it once per cycle and never seats a second one;
    (c) the next `Todo` card of each project that has a `board:` block in the registry, highest priority and
        oldest first, never a card labelled `decision` (those are the operator's) or `hold`, never a plan's
        container card -> a coder errand whose brief is made from the card and its plan file.

Coders run the harness and model the home names (default: claude, sonnet); judges stay with their own role row and
are never counted against coders. Brakes, all read before each spawn: a project with `loop: off` in its registry row
is skipped; a card or PR labelled `hold` is skipped; the machine's load must be under the ceiling; the seal hold
(state/.seal-hold) stops MERGING and does not stop this door, which only works. Every dispatch is a Rune
(`work-loop.dispatch`, which the night report reads) and one line in the ledger state/work-loop/dispatch.jsonl;
the card moves to In Progress with the errand linked.

Nothing here knows a machine, a project or a board by name: limits, the ceiling, the harness and the places all come
from the home (config/work-loop.yaml and hodd/identity/projects.yaml). With no config the limit is ONE coder.

Exit codes: 0 ran (work or nothing owed) · 2 usage · 3 an input could not be read (named) · 4 refused (no arm).
"""
import argparse
import json
import os
import re
import socket
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "bin", "boards"))

TERMINAL = ("done", "failed", "accepted", "returned", "closed", "resolved")
PRIORITY = {"urgent": 0, "high": 1, "medium": 2, "low": 3, "none": 4, None: 4, "": 4}
SKIP_LABELS = {"decision", "hold"}
DEFAULTS = {"default_limit": 1, "load_ceiling": 16.0, "harness": "claude", "model": "sonnet",
            "rework_cap": 3, "card_cap": 2, "max_per_cycle": 2}


class Refusal(Exception):
    pass


# ── the home, the registry, the config ───────────────────────────────────────────────────────────

def home_root():
    h = os.environ.get("YMIR_HOME")
    if not h:
        raise Refusal("YMIR_HOME is not set — run through bin/skuld/work-loop.sh")
    return h


def state_dir(home):
    return os.environ.get("YMIR_WORK_LOOP_STATE") or os.path.join(home, "state")


def load_yaml(path):
    try:
        import yaml
    except ImportError:
        raise Refusal("PyYAML is not installed — the registry cannot be read")
    try:
        with open(path, encoding="utf-8") as f:
            return yaml.safe_load(f) or {}
    except FileNotFoundError:
        return {}
    except Exception as e:
        raise Refusal(f"{path} could not be read: {e}")


def registry_rows(home):
    reg = os.path.join(home, "hodd", "identity", "projects.yaml")
    if not os.path.isfile(reg):
        raise Refusal(f"no registry at {reg}")
    data = load_yaml(reg)
    rows = data.get("projects", data) if isinstance(data, dict) else data
    if isinstance(rows, dict):
        rows = [dict(id=k, **(v or {})) for k, v in rows.items()]
    return [r for r in (rows or []) if isinstance(r, dict)]


def host_short():
    return os.environ.get("YMIR_WORK_LOOP_HOST") or socket.gethostname().split(".")[0]


def host_roles(home, host):
    try:
        with open(os.path.join(home, "hodd", "data", "fleet.json")) as f:
            fleet = json.load(f)
    except (OSError, ValueError):
        return []
    return list(((fleet.get("hosts") or {}).get(host) or {}).get("roles") or [])


def config(home, host):
    """The loop's settings for this machine: defaults, then config/work-loop.yaml. `limit` is read by host name,
    then by role, then default_limit."""
    c = dict(DEFAULTS)
    raw = load_yaml(os.path.join(home, "config", "work-loop.yaml"))
    for k in DEFAULTS:
        if k in raw:
            c[k] = raw[k]
    limits = raw.get("limits") or {}
    limit = limits.get(host)
    if limit is None:
        for r in host_roles(home, host):
            if r in limits:
                limit = limits[r]
                break
    if os.environ.get("YMIR_WORK_LOOP_LIMIT", "").isdigit():
        limit = int(os.environ["YMIR_WORK_LOOP_LIMIT"])
    c["limit"] = int(c["default_limit"] if limit is None else limit)
    c["load_ceiling"] = float(os.environ.get("YMIR_WORK_LOOP_CEILING") or c["load_ceiling"])
    return c


# ── what is running here ─────────────────────────────────────────────────────────────────────────

def meta_of(path):
    out = {}
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                if "=" in line:
                    k, v = line.rstrip("\n").split("=", 1)
                    out[k] = v
    except OSError:
        pass
    return out


def last_state(status_path):
    try:
        with open(status_path, encoding="utf-8", errors="replace") as f:
            lines = [l for l in f.read().splitlines() if l.strip()]
    except OSError:
        return None
    return lines[-1].split(":", 1)[0].strip() if lines else None


def live_errands(state):
    """Every errand of this machine that is not over: {id: {kind, branch, role}}. A coder is `kind=ship`; a judge
    is a scout and is never counted against the coders. A record with no status line is live for 30 minutes."""
    out = {}
    try:
        names = sorted(os.listdir(state))
    except OSError:
        return out
    now = time.time()
    for n in names:
        if not n.endswith(".meta"):
            continue
        eid = n[:-5]
        m = meta_of(os.path.join(state, n))
        if m.get("seat_state") == "done" or os.path.exists(os.path.join(state, eid + ".seat-closed")):
            continue
        st = last_state(os.path.join(state, eid + ".status"))
        if st in TERMINAL:
            continue
        if st is None:
            try:
                if now - float(m.get("launched") or 0) > 1800:
                    continue
            except ValueError:
                continue
        out[eid] = {"kind": m.get("kind", "ship"), "role": m.get("role", ""), "state": st or "starting"}
    return out


def coders(live):
    return {k: v for k, v in live.items() if v["kind"] != "scout"}


def load_now():
    try:
        return os.getloadavg()[0]
    except OSError:
        return 0.0


# ── the ledger: every dispatch, and the claims ───────────────────────────────────────────────────

class Ledger:
    def __init__(self, state):
        self.dir = os.path.join(state, "work-loop")
        self.path = os.path.join(self.dir, "dispatch.jsonl")

    def rows(self):
        out = []
        try:
            with open(self.path, encoding="utf-8") as f:
                for line in f:
                    try:
                        out.append(json.loads(line))
                    except ValueError:
                        pass
        except OSError:
            pass
        return out

    def attempts(self, key):
        return sum(1 for r in self.rows() if r.get("key") == key and r.get("verdict") in ("dispatched", "failed"))

    def claimed(self, key, live):
        """True while an errand this key was handed to is still live."""
        for r in self.rows():
            if r.get("key") == key and r.get("verdict") == "dispatched" and r.get("errand") in live:
                return True
        return False

    def append(self, row):
        os.makedirs(self.dir, exist_ok=True)
        row = dict(row, at=time.strftime("%Y-%m-%dT%H:%M:%S%z"))
        with open(self.path, "a", encoding="utf-8") as f:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")


# ── the work: (a) a rework, (c) a card ───────────────────────────────────────────────────────────

class Gh:
    """`gh`, or a stand-in for it in the tests."""

    def pr(self, repo, n):
        out = subprocess.run(["gh", "pr", "view", str(n), "-R", repo, "--json",
                              "state,headRefName,headRefOid,body,labels,isDraft"],
                             capture_output=True, text=True, timeout=60)
        if out.returncode != 0:
            return None
        try:
            return json.loads(out.stdout)
        except ValueError:
            return None


def kv(path):
    out = {}
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                if "=" in line:
                    k, v = line.split("=", 1)
                    out[k.strip()] = v.strip()
    except OSError:
        pass
    return out


def repo_projects(rows):
    """owner/repo (lower case) -> registry row, for every project that names a git repository and is not `loop: off`."""
    out = {}
    for r in rows:
        g = r.get("git") or {}
        if g.get("owner") and g.get("repo"):
            out[f"{g['owner']}/{g['repo']}".lower()] = r
    return out


def loop_off(row):
    v = row.get("loop")
    return str(v).strip().lower() in ("off", "false", "no", "0")


def rework_candidates(state, rows, live, gh, me):
    """A judge's NEEDS-REWORK on an open PR, for the head the judge saw, where the author is this machine (the PR's
    `Arm:` line) or no machine is named, and no coder here already holds it."""
    reviewed = os.path.join(state, ".reviewed")
    projects = repo_projects(rows)
    out = []
    try:
        names = sorted(os.listdir(reviewed))
    except OSError:
        return out
    for n in names:
        if not n.endswith(".judged"):
            continue
        rid = n[:-len(".judged")]
        side = kv(os.path.join(reviewed, n))
        repo, pr, head = side.get("repo"), side.get("pr"), side.get("head")
        if not (repo and pr and head):
            continue
        acted = os.path.join(reviewed, f"{rid}.{head}.acted")
        try:
            with open(acted, encoding="utf-8", errors="replace") as f:
                body = f.read()
        except OSError:
            continue
        if not body.startswith("needs-rework:"):
            continue
        row = projects.get(repo.lower())
        if row is None or loop_off(row):
            continue
        info = gh.pr(repo, pr)
        if not info or info.get("state") != "OPEN" or info.get("headRefOid") != head:
            continue  # merged, closed, or the branch moved on: that verdict is about a head nobody will merge
        if {l.get("name") for l in info.get("labels") or []} & SKIP_LABELS:
            continue
        arm = re.search(r"^\s*Arm:\s*(?:[^@\s]+@)?([A-Za-z0-9._-]+)\s*$", info.get("body") or "", re.M)
        if arm and arm.group(1).split(".")[0] != me:
            continue  # another machine's PR: that machine's loop takes it
        branch = info.get("headRefName") or ""
        if branch.startswith("eindri/") and branch[len("eindri/"):] in live:
            continue  # its own worker is still standing
        out.append({"kind": "rework", "key": f"pr:{repo}#{pr}", "repo": repo, "pr": pr, "head": head,
                    "branch": branch, "items": body[len("needs-rework:"):].strip(), "row": row})
    return out


def card_candidates(boards, rows, ledger, live, cap, mark_loop=True):
    """The `Todo` cards of every project with a `board:` block, best first. `boards` maps project id -> adapter."""
    out = []
    for row in rows:
        b = row.get("board")
        if not isinstance(b, dict) or loop_off(row):
            continue
        pid = str(row.get("id"))
        board = boards.get(pid)
        if board is None:
            continue
        try:
            cards = board.list_all()
        except Exception as e:  # a board that cannot be read is named, never read as empty
            out.append({"kind": "unreadable", "project": pid, "why": str(e)[:160]})
            continue
        for c in cards:
            if c.get("group") != "unstarted":
                continue
            labels = {str(x).lower() for x in (c.get("labels") or [])}
            if labels & SKIP_LABELS:
                continue
            if "plan" in labels and not c.get("parent"):
                continue  # the plan's own container card; its steps are the work
            key = f"card:{pid}:{c['card']}"
            if ledger.claimed(key, live) or ledger.attempts(key) >= cap:
                continue
            out.append({"kind": "card", "key": key, "project": pid, "row": row, "card": c})
    cards = [x for x in out if x["kind"] == "card"]
    cards.sort(key=lambda x: (PRIORITY.get(str(x["card"].get("priority") or "").lower(), 4),
                              x["card"].get("created") or x["card"].get("stamp") or "~", str(x["card"]["card"])))
    return cards + [x for x in out if x["kind"] == "unreadable"]


# ── the brief ────────────────────────────────────────────────────────────────────────────────────

def plan_file(home, row, card, board):
    """The plan file a card belongs to, by number from its title, its labels or its parent's title; else None."""
    nums = []
    for text in [card.get("title", "")] + [str(x) for x in card.get("labels") or []]:
        nums += re.findall(r"(?:^|\b)(?:plan[ -]?)?(\d{2,4})\b", text, re.I)
    parent = card.get("parent")
    if parent and board is not None:
        try:
            nums += re.findall(r"^(\d{2,4}) ·", board.get_card(parent).get("title", ""))
        except Exception:
            pass
    try:
        import plan_sync
        ledger = plan_sync.ledger_dir(home, row)
        ledger = ledger[1] if isinstance(ledger, tuple) else ledger
    except Exception:
        return None
    for n in nums:
        try:
            for f in sorted(os.listdir(ledger)):
                if f.startswith(f"{n}-") and f.endswith(".md"):
                    return os.path.join(ledger, f)
        except OSError:
            return None
    return None


def card_task(home, work, board):
    c, row = work["card"], work["row"]
    try:
        full = board.get_card(c["card"]) if board else c
    except Exception:
        full = c
    desc = (full.get("description") or "")[:6000]
    pf = plan_file(home, row, c, board)
    lines = [f"Take card {c['card']} of the board of project `{work['project']}`: {c['title']}", "",
             "The card, as the board holds it:", "", desc or "(the card has no description)", ""]
    if pf:
        lines += [f"Its plan file, read it before you write anything: `{pf}`", ""]
    lines += ["Deliver it as the brief's delivery contract says: your branch, tests, one fix note, a pull request. "
              "When the work is done say so in your terminal report and name the card, so the board can follow."]
    return "\n".join(lines)


def rework_task(work):
    return "\n".join([
        f"The judge asked for rework on PR #{work['pr']} of `{work['repo']}`, head `{work['head'][:12]}`.", "",
        f"The items to fix: {work['items']}", "",
        f"Work ON THAT BRANCH: `git fetch origin {work['branch']} && git checkout -B {work['branch']} origin/{work['branch']}`. "
        "Fix exactly those items, with a test where behaviour changed, commit, and push to that SAME branch. "
        "Do not open a new pull request and do not rename the branch: the judge reviews the new head and an approval on a green head merges it."])


# ── spawning ─────────────────────────────────────────────────────────────────────────────────────

class Spawner:
    """The real road: erindi-brief.sh writes the brief, einherjar-spawn.sh seats the coder."""

    def __init__(self, root, home, harness, model):
        self.root, self.home, self.harness, self.model = root, home, harness, model

    def project_dir(self, pid):
        out = subprocess.run(["bash", os.path.join(self.root, "bin/agents/project-target.sh"), "resolve", pid],
                             capture_output=True, text=True, timeout=60)
        for line in out.stdout.splitlines():
            k, _, v = line.partition("\t")
            if k == "path" and v:
                return v
        raise Refusal(f"project {pid} has no clone on this machine: {out.stderr.strip()[:160]}")

    def brief_path(self, eid):
        return os.path.join(self.home, "hodd", "data", eid, "brief.md")

    def spawn(self, eid, pid, task):
        pdir = self.project_dir(pid)
        env = dict(os.environ, BROKK_HOME=self.root)
        r = subprocess.run(["bash", os.path.join(self.root, "bin/agents/erindi-brief.sh"), eid, pid,
                            "--mode", "direct-PR"], capture_output=True, text=True, timeout=120, env=env)
        if r.returncode != 0:
            raise Refusal(f"the brief for {eid} was not written: {(r.stderr or r.stdout).strip()[-200:]}")
        bp = self.brief_path(eid)
        with open(bp, encoding="utf-8") as f:
            text = f.read()
        if "{TASK}" in text:
            text = text.replace("{TASK}", task, 1)
        else:
            text = re.sub(r"(# Task\n).*?(\n# )", lambda m: m.group(1) + task + "\n" + m.group(2), text, 1, re.S)
        with open(bp, "w", encoding="utf-8") as f:
            f.write(text)
        s = subprocess.run(["bash", os.path.join(self.root, "bin/agents/einherjar-spawn.sh"), eid, pdir,
                            "--mode", "direct-PR", "--harness", self.harness, "--model", self.model],
                           capture_output=True, text=True, timeout=300, env=env)
        if s.returncode != 0:
            raise Refusal(f"the spawn of {eid} was refused: {(s.stderr or s.stdout).strip()[-240:]}")
        return bp


def rune(root, home, msg):
    door = os.path.join(root, "bin/records/runes-append.sh")
    if os.path.isfile(door):
        subprocess.run(["bash", door, "work-loop", "work-loop.dispatch", "--message", msg],
                       capture_output=True, timeout=60, env=dict(os.environ, YMIR_HOME=home))


def slug(text, n=24):
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")[:n].strip("-") or "work"


def errand_id(work):
    if work["kind"] == "rework":
        return f"rework-pr{work['pr']}-{work['head'][:7]}"
    c = work["card"]
    return f"card-{slug(work['project'], 10)}-{slug(str(c['card']), 14)}-{slug(c['title'], 18)}"


# ── the cycle ────────────────────────────────────────────────────────────────────────────────────

def cycle(args, env=None):
    """One pass. `env` lets tests stand in for the world: {gh, boards, spawner, live, load, arm, keeper}."""
    env = env or {}
    home = home_root()
    state = state_dir(home)
    host = host_short()
    cfg = config(home, host)
    report = {"host": host, "limit": cfg["limit"], "dispatched": [], "skipped": [], "notes": []}
    rows = registry_rows(home)
    ledger = Ledger(state)
    live_all = env["live"]() if "live" in env else live_errands(state)
    mine = coders(live_all)
    report["coders"] = len(mine)
    free = cfg["limit"] - len(mine)

    arm = env["arm"]() if "arm" in env else arm_held(ROOT)
    if not arm and not args.dry_run:
        report["notes"].append("no arm is held on this machine: the loop reads and reports, it spawns nothing")
        args.dry_run = True
    if os.path.exists(os.path.join(state, ".seal-hold")):
        report["notes"].append("the seal hold is up: merging is stopped, working goes on")

    # (b) the judges are the review loop's: one call, never a second judge
    if not args.no_review and not args.dry_run:
        k = env["keeper"]() if "keeper" in env else call_keeper(ROOT)
        report["notes"].append(f"review loop: {k}")

    if free <= 0:
        report["notes"].append(f"{len(mine)} coder(s) here, the limit is {cfg['limit']}: nothing to top up")
        return report

    gh = env.get("gh") or Gh()
    work = rework_candidates(state, rows, live_all, gh, host)
    boards = env["boards"] if "boards" in env else build_boards(home, rows, report)
    work += card_candidates(boards, rows, ledger, live_all, int(cfg["card_cap"]))
    spawner = env.get("spawner") or Spawner(ROOT, home, str(cfg["harness"]), str(cfg["model"]))
    budget = min(free, int(cfg["max_per_cycle"]) if not args.all else free)

    for w in work:
        if w["kind"] == "unreadable":
            report["skipped"].append({"project": w["project"], "why": "its board could not be read: " + w["why"]})
            continue
        if len(report["dispatched"]) >= budget:
            break
        if w["kind"] == "rework" and ledger.attempts(w["key"]) >= int(cfg["rework_cap"]):
            report["skipped"].append({"key": w["key"], "why": "the rework cap is reached: the helm decides"})
            continue
        if w["kind"] == "rework" and ledger.claimed(w["key"], live_all):
            continue
        load = env["load"]() if "load" in env else load_now()
        if load >= cfg["load_ceiling"]:
            report["notes"].append(f"load {load:.1f} is at the ceiling {cfg['load_ceiling']}: no more spawns this cycle")
            break
        eid = errand_id(w)
        pid = str(w["row"].get("id"))
        task = rework_task(w) if w["kind"] == "rework" else card_task(home, w, boards.get(pid))
        row = {"key": w["key"], "errand": eid, "project": pid, "kind": w["kind"], "host": host}
        if args.dry_run:
            report["dispatched"].append(dict(row, verdict="would-dispatch"))
            continue
        try:
            brief = spawner.spawn(eid, pid, task)
        except Exception as e:
            ledger.append(dict(row, verdict="failed", why=str(e)[:200]))
            report["skipped"].append({"key": w["key"], "why": str(e)[:160]})
            continue
        if w["kind"] == "card":
            try:  # In Progress, with the errand linked (plan 335 phase 4)
                b = boards[pid]
                b.update_card(w["card"]["card"], group="started")
                b.add_link(w["card"]["card"], "file://" + brief, f"errand {eid}")
            except Exception as e:
                report["notes"].append(f"the card {w['card']['card']} could not be moved: {str(e)[:120]}")
        ledger.append(dict(row, verdict="dispatched", brief=brief))
        rune(ROOT, home, f"dispatched {eid} ({w['kind']}) for {w['key']} on {host}")
        report["dispatched"].append(dict(row, verdict="dispatched"))
        live_all[eid] = {"kind": "ship", "role": "", "state": "starting"}
    if not work:
        report["notes"].append("nothing is owed: no rework, and no Todo card on any board that takes part")
    return report


def build_boards(home, rows, report):
    from board_adapter_mcp import McpBoard, resolve_token
    boards = {}
    for r in rows:
        b = r.get("board")
        if not isinstance(b, dict) or loop_off(r) or b.get("adapter") != "mcp":
            continue
        m = b.get("mcp") or {}
        try:
            boards[str(r["id"])] = McpBoard(b["place"], m["url"], resolve_token(m.get("token_from"), home, ROOT))
        except Exception as e:
            report["skipped"].append({"project": str(r.get("id")), "why": f"its board adapter did not start: {str(e)[:140]}"})
    return boards


def arm_held(root):
    r = subprocess.run(["bash", os.path.join(root, "bin/voice/rodd-arm.sh"), "who"], capture_output=True, text=True, timeout=30)
    return r.returncode == 0


def call_keeper(root):
    door = os.path.join(root, "bin/forge/review-watch.sh")
    if not os.path.isfile(door):
        return "the keeper is not on this tree"
    r = subprocess.run(["bash", door, "--keeper"], capture_output=True, text=True, timeout=600)
    last = (r.stdout.strip().splitlines() or [""])[-1][:160]
    return f"exit {r.returncode} {last}"


def render(rep, as_json):
    if as_json:
        return json.dumps(rep, ensure_ascii=False)
    out = [f"work-loop[1]{{host,limit,coders,dispatched,skipped}}:",
           f'  "{rep["host"]}","{rep["limit"]}","{rep.get("coders", 0)}","{len(rep["dispatched"])}","{len(rep["skipped"])}"']
    if rep["dispatched"]:
        out.append("dispatched[%d]{verdict,kind,errand,key}:" % len(rep["dispatched"]))
        out += [f'  "{d["verdict"]}","{d["kind"]}","{d["errand"]}","{d["key"]}"' for d in rep["dispatched"]]
    if rep["skipped"]:
        out.append("skipped[%d]{what,why}:" % len(rep["skipped"]))
        out += [f'  "{s.get("key") or s.get("project")}","{s["why"]}"' for s in rep["skipped"]]
    out += [f'note: {n}' for n in rep["notes"]]
    return "\n".join(out)


def main(argv=None):
    ap = argparse.ArgumentParser(prog="work-loop.sh", description=__doc__.split("\n\n")[0])
    ap.add_argument("verb", nargs="?", default="cycle", choices=["cycle", "status"])
    ap.add_argument("--dry-run", action="store_true", help="read and say what would go out; spawn and write nothing")
    ap.add_argument("--no-review", action="store_true", help="do not call the review loop this cycle")
    ap.add_argument("--all", action="store_true", help="fill every free slot this cycle, not the per-cycle cap")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    try:
        if args.verb == "status":
            home = home_root()
            host = host_short()
            cfg = config(home, host)
            live = coders(live_errands(state_dir(home)))
            print(render({"host": host, "limit": cfg["limit"], "coders": len(live), "dispatched": [], "skipped": [],
                          "notes": [f"live coders: {', '.join(sorted(live)) or 'none'}", f"load {load_now():.1f} of {cfg['load_ceiling']}"]},
                         args.json))
            return 0
        rep = cycle(args)
    except Refusal as e:
        print(f"error: {e}", file=sys.stderr)
        return 3
    print(render(rep, args.json))
    return 0


if __name__ == "__main__":
    sys.exit(main())
