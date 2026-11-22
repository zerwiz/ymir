#!/usr/bin/env python3
"""trouble.py — the house says it is in trouble before it is asked (plan 339.5, 339.6, 341.4).

One reading per machine, of the nine things that failed silently on 2026-11-20 — and nothing else:

    disk       a watched path above TROUBLE_DISK_PCT (85) used, or growing faster than
               TROUBLE_DISK_GROWTH_GIB (20) GiB a day; Garmr's own disk row (house.py) where it exists
    guardian   housewatch failed or its timer not active, or the hound's heartbeat older than
               TROUBLE_HOUND_MAX_S (600) seconds
    pin        the pinned runtime more than TROUBLE_PIN_BEHIND (10) commits behind main for more
               than TROUBLE_PIN_HOURS (2) hours
    unpushed   an errand branch (eindri/*) holding commits that are on no remote, the oldest older
               than TROUBLE_UNPUSHED_S (3600) seconds
    questions  an errand question unanswered for more than TROUBLE_QUESTION_S (3600) seconds
    errands    an errand dead (its pane holds no agent), falsely done (done with nothing committed
               since launch) or stalled (working, idle agent, silent TROUBLE_STALL_S (1800) seconds)
    hyprland   Hyprland reports config errors (plan 341.4: `hypr.sh config check` where it exists)
    tells      a tell in the arm's queue unanswered for more than TROUBLE_TELL_S (3600) seconds
    loops      the same commit subject more than twice on one branch in an hour — Níðhöggr's
               `commits` verb judges it, and the panel only carries his verdict; and Níðhöggr's own
               clock (plan 350 B4): his last run (<state>/nidhogg/last-run.json) older than
               TROUBLE_NIDHOGG_S (3600) seconds is red, because a loop-breaker that stopped is silent
    receipts   a Veil report the arm holder has not answered RECEIVED within TROUBLE_RECEIPT_S (600)
               seconds (plan 350 B, the arm contract: bin/agents/veil.sh pending), with the count

Verbs (bin/ward/trouble.sh is the door; it resolves the home and passes it in):

    read [--json] [--only a,b]      this machine's reading; exit 1 when any signal is red
    check [--notify] [--only a,b]   read, keep the reading, and push ONE notice per turn to red;
                                    a turn is marked said only when send.sh decided `send`, so a
                                    failed or duplicate notice is tried again on the next check
    fleet [--json]                  a row per machine in fleet.json, each read ON that machine

It is read-only on the machine. What it writes: <state>/trouble/<host>.json (the last reading, what a
hall renders), <state>/trouble/<host>.disk.jsonl (disk samples for the growth rate) and
<state>/trouble/<host>.since.json (when a slow signal first went bad) and
<state>/trouble/<host>.announced.json (each red turn: when it began and whether it was said).
A signal that cannot be measured here is SKIP with its reason, never a guess and never a red.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import socket
import subprocess
import sys
import time
from pathlib import Path

GIB = 1024 ** 3
SIGNALS = ("disk", "guardian", "pin", "unpushed", "questions", "errands", "hyprland", "tells", "loops", "receipts")
ENDED = ("done:", "resolved:", "failed:")
IDLE = {"idle", "done", "waiting", "unknown"}


def env_int(name: str, default: int) -> int:
    try:
        return int(float(os.environ.get(name, "") or default))
    except ValueError:
        return default


def run(argv: list[str], timeout: int = 20, cwd: str | None = None, env: dict | None = None, stdin: str | None = None):
    try:
        return subprocess.run(argv, capture_output=True, text=True, timeout=timeout, cwd=cwd, env=env, input=stdin)
    except Exception as exc:  # a door that cannot answer is not an answer
        return subprocess.CompletedProcess(argv, 127, "", str(exc))


def git(repo: str, *args: str, timeout: int = 20) -> tuple[int, str]:
    done = run(["git", "-C", repo, *args], timeout=timeout)
    return done.returncode, (done.stdout or "").strip()


def row(signal: str, state: str, note: str, **facts) -> dict:
    return {"signal": signal, "state": state, "note": note, **facts}


class Ctx:
    def __init__(self, root: str, home: str, state: str):
        self.root, self.home, self.state = root, home, Path(state)
        self.host = os.environ.get("TROUBLE_HOST") or socket.gethostname().split(".")[0]
        self.now = time.time()
        self.dir = self.state / "trouble"
        self.dir.mkdir(parents=True, exist_ok=True)
        self._metas: list[tuple[str, dict, Path]] | None = None

    def metas(self) -> list[tuple[str, dict, Path]]:
        """Every errand record touched inside the horizon: (id, meta, status path)."""
        if self._metas is not None:
            return self._metas
        horizon = env_int("TROUBLE_ERRAND_HORIZON_S", 86400)
        found = []
        try:
            entries = sorted(self.state.glob("*.meta"))
        except OSError:
            entries = []
        for meta_file in entries:
            seat = meta_file.name[:-5]
            status = self.state / f"{seat}.status"
            try:
                newest = max(meta_file.stat().st_mtime, status.stat().st_mtime if status.exists() else 0)
            except OSError:
                continue
            if self.now - newest > horizon:
                continue
            meta = {}
            for line in meta_file.read_text(encoding="utf-8", errors="replace").splitlines():
                key, sep, value = line.partition("=")
                if sep:
                    meta[key.strip()] = value.strip()
            found.append((seat, meta, status))
        self._metas = found
        return found

    def repos(self) -> list[str]:
        """The repositories errands work in: every `project=` a recent errand names, plus TROUBLE_REPOS."""
        seen: list[str] = []
        extra = [p for p in os.environ.get("TROUBLE_REPOS", "").split(":") if p]
        for path in extra + [m.get("project", "") for _, m, _ in self.metas()]:
            path = os.path.expanduser(path)
            if path and os.path.isdir(path) and path not in seen:
                seen.append(path)
        return seen

    def since(self, key: str, bad: bool) -> float:
        """When `key` first went bad (kept across checks); forgotten the moment it is good again."""
        path = self.dir / f"{self.host}.since.json"
        try:
            memo = json.loads(path.read_text())
        except (OSError, ValueError):
            memo = {}
        if bad:
            memo.setdefault(key, self.now)
        else:
            memo.pop(key, None)
        try:
            path.write_text(json.dumps(memo, sort_keys=True))
        except OSError:
            pass
        return memo.get(key, self.now)


# ── the signals ──────────────────────────────────────────────────────────────────────────────────

def sig_disk(c: Ctx) -> dict:
    line_pct = env_int("TROUBLE_DISK_PCT", 85)
    line_growth = env_int("TROUBLE_DISK_GROWTH_GIB", 20)
    paths = [p for p in os.environ.get("TROUBLE_DISK_PATHS", "/").split(":") if p]
    samples_path = c.dir / f"{c.host}.disk.jsonl"
    try:
        samples = [json.loads(x) for x in samples_path.read_text().splitlines() if x.strip()]
    except (OSError, ValueError):
        samples = []
    bad, notes, worst = [], [], 0.0
    fresh = []
    for path in paths:
        try:
            st = os.statvfs(path)
        except OSError:
            notes.append(f"{path} unreadable")
            continue
        size = st.f_blocks * st.f_frsize
        used = size - st.f_bavail * st.f_frsize
        if not size:
            continue
        pct = round(100.0 * used / size, 1)
        worst = max(worst, pct)
        fresh.append({"t": c.now, "path": path, "used": used})
        if pct > line_pct:
            bad.append(f"{path} is {pct}% used ({round((size - used) / GIB, 1)} GiB free)")
        # the growth rate: from the oldest sample of the last day, once at least an hour has passed
        old = [s for s in samples if s.get("path") == path and c.now - s.get("t", 0) <= 86400]
        if old:
            first = min(old, key=lambda s: s["t"])
            span = c.now - first["t"]
            if span >= 3600:
                per_day = (used - first["used"]) / GIB * 86400 / span
                if per_day > line_growth:
                    bad.append(f"{path} is growing {round(per_day, 1)} GiB a day")
                else:
                    notes.append(f"{path} {pct}% · {round(per_day, 1)} GiB/day")
            else:
                notes.append(f"{path} {pct}%")
        else:
            notes.append(f"{path} {pct}%")
    keep = [s for s in samples if c.now - s.get("t", 0) <= 2 * 86400] + fresh
    try:
        samples_path.write_text("".join(json.dumps(s) + "\n" for s in keep[-2000:]))
    except OSError:
        pass
    # Garmr's own reading (plan 337), where his disk probe is installed: his FAIL is the house's red too.
    house = Path(c.root) / "bin/ward/garmr/house.py"
    if house.exists() and os.environ.get("TROUBLE_NO_GARMR") != "1":
        out = run([sys.executable, str(house), "--summary"], timeout=60).stdout or ""
        m = re.search(r'"disk","(\w+)","([^"]*)"', out)
        if m and m.group(1) == "FAIL":
            bad.append(f"Garmr: {m.group(2)}")
    if bad:
        return row("disk", "RED", "; ".join(bad), used_pct=worst)
    if not fresh:
        return row("disk", "SKIP", "no watched path could be read")
    return row("disk", "ok", "; ".join(notes), used_pct=worst)


def _unit(unit: str) -> dict:
    out = run(["systemctl", "--user", "show", unit, "-p", "LoadState,ActiveState,Result"], timeout=10).stdout
    return dict(x.split("=", 1) for x in (out or "").splitlines() if "=" in x)


def sig_guardian(c: Ctx) -> dict:
    bad, notes = [], []
    if shutil.which("systemctl"):
        svc, timer = _unit("housewatch.service"), _unit("housewatch.timer")
        if svc.get("LoadState") != "loaded":
            bad.append("housewatch is not installed")
        elif svc.get("ActiveState") == "failed":
            bad.append(f"housewatch failed ({svc.get('Result', '?')})")
        elif timer.get("ActiveState") != "active":
            bad.append(f"housewatch's timer is {timer.get('ActiveState', 'absent')}")
        else:
            notes.append("housewatch on its timer")
    else:
        notes.append("no systemd here: housewatch not judged")
    beat = None
    for candidate in (os.environ.get("TROUBLE_HOUND_HEARTBEAT", ""), "/var/log/ymir/garmr/state/hound.heartbeat",
                      str(Path(os.environ.get("GARMR_STATE_DIR", "") or c.state / "garmr") / "hound.heartbeat")):
        if candidate and os.path.isfile(candidate):
            beat = candidate
            break
    if beat:
        age = int(c.now - os.path.getmtime(beat))
        line = env_int("TROUBLE_HOUND_MAX_S", 600)
        if age > line:
            bad.append(f"the hound's heartbeat is {age // 60} min old")
        else:
            notes.append(f"hound {age}s")
    else:
        notes.append("no hound heartbeat on this machine")
    if bad:
        return row("guardian", "RED", "; ".join(bad))
    return row("guardian", "ok", "; ".join(notes))


def sig_pin(c: Ctx) -> dict:
    pin = os.path.expanduser(os.environ.get("YMIR_RUNTIME_DIR", "") or "~/ymir-runtime")
    rc, sha = git(pin, "rev-parse", "HEAD")
    if rc != 0 or not sha:
        return row("pin", "SKIP", f"no pinned runtime at {pin}")
    branch = os.environ.get("YMIR_RUNTIME_BRANCH", "main")
    counts = []
    for repo in [pin] + c.repos():
        rc, n = git(repo, "rev-list", "--count", f"{sha}..origin/{branch}")
        if rc == 0 and n.isdigit():
            counts.append(int(n))
    if not counts:
        return row("pin", "SKIP", f"origin/{branch} is unknown beside the pin")
    behind = max(counts)  # the freshest origin any checkout on this machine has seen
    line, hours = env_int("TROUBLE_PIN_BEHIND", 10), env_int("TROUBLE_PIN_HOURS", 2)
    first = c.since("pin", behind > line)
    held = c.now - first
    if behind > line and held > hours * 3600:
        return row("pin", "RED", f"the pin {sha[:9]} is {behind} commits behind {branch} for {held / 3600:.1f} h",
                   behind=behind)
    if behind > line:
        return row("pin", "ok", f"{behind} behind, for {int(held // 60)} min (red after {hours} h)", behind=behind)
    return row("pin", "ok", f"{sha[:9]}, {behind} behind", behind=behind)


def sig_unpushed(c: Ctx) -> dict:
    line = env_int("TROUBLE_UNPUSHED_S", 3600)
    stuck, total = [], 0
    for repo in c.repos():
        rc, refs = git(repo, "for-each-ref", "--format=%(refname:short)", "refs/heads/eindri/")
        for branch in refs.splitlines():
            # commits on NO remote at all: a gathered branch is safe once its gather is pushed
            rc, out = git(repo, "log", "--format=%ct", branch, "--not", "--remotes")
            stamps = [int(x) for x in out.split() if x.isdigit()]
            if not stamps:
                continue
            total += 1
            age = c.now - min(stamps)
            if age > line:
                stuck.append((age, branch, len(stamps)))
    if not stuck:
        return row("unpushed", "ok", f"{total} errand branch(es) with local commits, none older than {line // 60} min")
    stuck.sort(reverse=True)
    names = ", ".join(f"{b} ({n}, {int(a // 3600)} h)" for a, b, n in stuck[:4])
    more = f" and {len(stuck) - 4} more" if len(stuck) > 4 else ""
    return row("unpushed", "RED", f"{len(stuck)} errand branch(es) hold work on no remote: {names}{more}",
               count=len(stuck))


def _answered(c: Ctx, seat: str, asked: float) -> bool:
    """A question is answered when a word went to that errand after it, or the errand has ended since."""
    status = c.state / f"{seat}.status"
    try:
        if status.stat().st_mtime > asked:
            lines = [x.strip() for x in status.read_text(errors="replace").splitlines() if x.strip()]
            if lines and lines[-1].lower().startswith(ENDED):
                return True
    except OSError:
        pass
    meta = next((m for s, m, _ in c.metas() if s == seat), {})
    pane = meta.get("seat_pane", "")
    log = Path(os.environ.get("YMIR_MSG_LOG_DIR", "") or c.state / "fleet") / "messages.jsonl"
    if not log.exists():
        return False
    try:
        with open(log, "rb") as handle:
            handle.seek(max(0, log.stat().st_size - 2_000_000))
            tail = handle.read().decode("utf-8", "replace").splitlines()
    except OSError:
        return False
    for line in tail:
        try:
            rec = json.loads(line)
        except ValueError:
            continue
        to = str(rec.get("to", ""))
        if to == seat or (pane and pane in (to, str(rec.get("pane", "")))):
            try:
                if float(rec.get("epoch") or 0) > asked:
                    return True
            except (TypeError, ValueError):
                continue
    return False


def sig_questions(c: Ctx) -> dict:
    shelf = Path(os.environ.get("TROUBLE_QUESTIONS_DIR", "") or c.state / "eindri-questions")
    if not shelf.is_dir():
        return row("questions", "ok", "no question shelf here")
    line = env_int("TROUBLE_QUESTION_S", 3600)
    waiting = []
    for f in sorted(shelf.glob("*.md")):
        asked = f.stat().st_mtime
        if c.now - asked <= line or _answered(c, f.stem, asked):
            continue
        waiting.append((c.now - asked, f.stem))
    if not waiting:
        return row("questions", "ok", f"none unanswered past {line // 60} min")
    waiting.sort()
    names = ", ".join(f"{s} ({int(a // 3600)} h)" for a, s in waiting[:5])
    more = f" and {len(waiting) - 5} more" if len(waiting) > 5 else ""
    return row("questions", "RED", f"{len(waiting)} unanswered: {names}{more}", count=len(waiting))


def _herdr_panes() -> dict[str, str] | None:
    if not shutil.which("herdr"):
        return None
    done = run(["herdr", "agent", "list"], timeout=10)
    try:
        data = json.loads(done.stdout or "")
    except ValueError:
        return None
    agents = (data.get("result", data) if isinstance(data, dict) else {}).get("agents")
    if not isinstance(agents, list):
        return None
    return {str(a.get("pane_id")): str(a.get("agent_status") or "unknown") for a in agents if isinstance(a, dict)}


def _done_record(seat: str, meta: dict) -> str | None:
    """'' when a done: stands on a commit made since launch, a fault phrase when not, None when unjudgeable."""
    repo = meta.get("worktree", "")
    if not (repo and os.path.isdir(repo)):
        repo = meta.get("project", "")
    if not (repo and os.path.isdir(repo)):
        return None
    branch = f"eindri/{seat}"
    if git(repo, "rev-parse", "--verify", "-q", f"refs/heads/{branch}")[0] != 0:
        wt = meta.get("worktree", "")
        branch = git(wt, "branch", "--show-current")[1] if wt and os.path.isdir(wt) else ""
        if not branch:
            return None  # a merged and deleted branch proves nothing either way
    launched = meta.get("launched", "")
    if not launched.isdigit():
        return None
    rc, out = git(repo, "log", "-1", "--format=%H", f"--since=@{launched}", branch)
    if rc != 0:
        return None
    return "" if out else "nothing committed since launch"


def sig_errands(c: Ctx) -> dict:
    stall = env_int("TROUBLE_STALL_S", 1800)
    done_horizon = env_int("TROUBLE_DONE_HORIZON_S", 6 * 3600)
    panes: dict | None = None
    asked = False
    faults = []
    for seat, meta, status in c.metas():
        try:
            lines = [x.strip() for x in status.read_text(errors="replace").splitlines() if x.strip()]
        except OSError:
            continue
        if not lines:
            continue
        last, head = lines[-1], lines[-1].lower()
        if head.startswith("done:"):
            # a worker's own claim, while the helm may still believe it: the helm's sweep closing an old
            # errand ("terminal act recorded by the helm") is bookkeeping, not a report to be judged
            if "recorded by the helm" in head or c.now - status.stat().st_mtime > done_horizon:
                continue
            verdict = _done_record(seat, meta)
            if verdict:
                faults.append(f"{seat} false-done ({verdict})")
            continue
        if head.startswith(ENDED):
            continue
        pane = meta.get("seat_pane", "") or (meta.get("window", "") if meta.get("backend") == "herdr" else "")
        if not pane:
            continue
        if not asked:
            panes, asked = _herdr_panes(), True
        if panes is None:
            continue  # a silent herdr judges no worker
        if pane not in panes:
            faults.append(f"{seat} dead (no agent in {pane})")
        elif head.startswith("working:") and panes.get(pane, "") in IDLE:
            quiet = c.now - max(status.stat().st_mtime, 0)
            if quiet > stall:
                faults.append(f"{seat} stalled ({int(quiet // 60)} min silent)")
    if faults:
        return row("errands", "RED", "; ".join(faults[:5]) + (f" and {len(faults) - 5} more" if len(faults) > 5 else ""),
                   count=len(faults))
    if asked and panes is None:
        return row("errands", "ok", f"{len(c.metas())} recent errand(s); herdr did not answer, so none judged dead")
    return row("errands", "ok", f"{len(c.metas())} recent errand(s), none dead, falsely done or stalled")


def _hypr_env() -> dict | None:
    env = dict(os.environ)
    if env.get("HYPRLAND_INSTANCE_SIGNATURE"):
        return env
    runtime = Path(env.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")) / "hypr"
    try:
        live = sorted((p for p in runtime.iterdir() if (p / ".socket.sock").exists()),
                      key=lambda p: p.stat().st_mtime, reverse=True)
    except OSError:
        return None
    if not live:
        return None
    env["HYPRLAND_INSTANCE_SIGNATURE"] = live[0].name  # a timer has no session env; the socket names it
    return env


def sig_hyprland(c: Ctx) -> dict:
    if not shutil.which(os.environ.get("YMIR_HYPRCTL", "hyprctl")):
        return row("hyprland", "SKIP", "no Hyprland on this machine")
    env = _hypr_env()
    if env is None:
        return row("hyprland", "SKIP", "Hyprland is not running")
    door = Path(c.root) / "bin/desktop/hypr.sh"
    if door.exists():  # plan 341.3: the one door knows the dialect and parses the house's own files
        done = run(["bash", str(door), "config", "check"], timeout=30, env=env)
        if done.returncode == 1:
            first = next((x.strip() for x in (done.stdout or "").splitlines()[1:] if x.strip()), "")
            return row("hyprland", "RED", f"config error: {first[:200]}")
        if done.returncode == 0:
            return row("hyprland", "ok", "hypr.sh config check is clean")
    out = run([os.environ.get("YMIR_HYPRCTL", "hyprctl"), "configerrors"], timeout=10, env=env)
    errors = [x for x in (out.stdout or "").splitlines() if x.strip()]
    if out.returncode != 0:
        return row("hyprland", "SKIP", "hyprctl did not answer")
    if errors:
        return row("hyprland", "RED", f"config error: {errors[0][:200]}" + (f" (+{len(errors) - 1})" if len(errors) > 1 else ""))
    return row("hyprland", "ok", "hyprctl configerrors is empty")


def sig_tells(c: Ctx) -> dict:
    queue = Path(os.environ.get("TROUBLE_WAKE_QUEUE", "") or c.state / ".wake-queue")
    if not queue.exists():
        return row("tells", "ok", "no wake queue on this machine")
    line = env_int("TROUBLE_TELL_S", 3600)
    old = []
    for raw in queue.read_text(errors="replace").splitlines():
        parts = raw.split("\t")
        if len(parts) < 5 or parts[2] != "signal" or not parts[0].isdigit():
            continue
        age = c.now - int(parts[0])
        if age > line:
            sender = parts[4].split(" to the arm holder:", 1)[0][:40]
            old.append((age, sender))
    if not old:
        return row("tells", "ok", f"no tell waiting past {line // 60} min")
    old.sort(reverse=True)
    senders = ", ".join(sorted({s for _, s in old})[:4])
    return row("tells", "RED", f"{len(old)} tell(s) unanswered, the oldest {int(old[0][0] // 3600)} h (from {senders})",
               count=len(old))


def _nidhogg_clock(c: Ctx) -> dict | None:
    """Níðhöggr's own clock: red when his last run is older than the line; None when he runs nowhere here."""
    stamp = c.state / "nidhogg" / "last-run.json"
    if not stamp.exists():
        return None
    line = env_int("TROUBLE_NIDHOGG_S", 3600)
    try:
        ts = int(json.loads(stamp.read_text()).get("ts", 0))
    except (OSError, ValueError):
        ts = 0
    if c.now - ts > line:
        return row("loops", "RED", f"Níðhöggr has not run for {int((c.now - ts) // 60)} min (his line is {line // 60} min)"
                   " — his clock stopped; run bin/time/nornir-job-nidhogg.sh", count=1)
    return None


def sig_receipts(c: Ctx) -> dict:
    ledger = Path(os.environ.get("TROUBLE_VEIL_LEDGER", "") or c.state / "veil" / "ledger.jsonl")
    if not ledger.exists():
        return row("receipts", "ok", "no Veil report on this machine yet")
    line = env_int("TROUBLE_RECEIPT_S", 600)
    sent: dict[str, dict] = {}
    answered: set[str] = set()
    for raw in ledger.read_text(errors="replace").splitlines():
        try:
            ev = json.loads(raw)
        except ValueError:
            continue
        if ev.get("event") == "sent" and ev.get("kind") != "steer":
            sent[ev.get("id", "")] = ev
        elif ev.get("event") in ("received", "accepted", "rework"):
            answered.add(ev.get("id", ""))
    old = sorted((c.now - int(ev.get("ts", c.now)), ev.get("from", "?")) for i, ev in sent.items()
                 if i not in answered and c.now - int(ev.get("ts", c.now)) > line)
    if not old:
        return row("receipts", "ok", f"every Veil report was RECEIVED within {line // 60} min")
    old.reverse()
    senders = ", ".join(sorted({s for _, s in old})[:4])
    return row("receipts", "RED", f"{len(old)} report(s) with no RECEIVED from the arm holder, the oldest "
               f"{int(old[0][0] // 60)} min (from {senders}) — bin/agents/veil.sh pending", count=len(old))


def sig_loops(c: Ctx) -> dict:
    clock = _nidhogg_clock(c)
    if clock:
        return clock
    door = Path(c.root) / "bin/gates/nidhogg.sh"
    if not door.exists():
        return row("loops", "SKIP", "Níðhöggr is not in this tree")
    args = ["bash", str(door), "commits", "--json"]
    for repo in c.repos():
        args += ["--repo", repo]
    if len(args) == 4:
        return row("loops", "ok", "no errand repository to read")
    done = run(args, timeout=120)
    try:
        loops = json.loads(done.stdout or "{}").get("loops") or []
    except ValueError:
        return row("loops", "SKIP", "Níðhöggr did not answer")
    if not loops:
        return row("loops", "ok", "no commit repeated more than twice on a branch this hour")
    worst = loops[0]
    on = worst.get("branches") or [worst["branch"]]
    where = ", ".join(on[:3]) + (f" and {len(on) - 3} more" if len(on) > 3 else "")
    return row("loops", "RED", f"'{worst['subject']}' was committed {worst['count']} times in an hour (on {where})"
               + (f"; {len(loops) - 1} more loop(s)" if len(loops) > 1 else "") + " — Níðhöggr names it",
               count=len(loops), branch=worst["branch"])


PROBES = {"disk": sig_disk, "guardian": sig_guardian, "pin": sig_pin, "unpushed": sig_unpushed,
          "questions": sig_questions, "errands": sig_errands, "hyprland": sig_hyprland, "tells": sig_tells,
          "loops": sig_loops, "receipts": sig_receipts}


def reading(c: Ctx, only: list[str]) -> dict:
    rows = []
    for name in only:
        try:
            rows.append(PROBES[name](c))
        except Exception as exc:  # one blind probe must not blind the panel
            rows.append(row(name, "SKIP", f"the probe failed: {type(exc).__name__}: {exc}"[:200]))
    return {"host": c.host, "at": int(c.now), "red": sum(r["state"] == "RED" for r in rows), "rows": rows}


# ── the notice: one line and its buttons, only on the turn to red ────────────────────────────────

BUTTONS = {
    "disk": ["🧹 Show what fills the disk|On {host}, run bin/ward/garmr/house.py --summary and list the ten largest folders under the home, then tell me what fills the disk"],
    "guardian": ["🩺 Restart the house watch|On {host}, run systemctl --user restart housewatch.service and garmr-hound if its heartbeat is old, then show bin/time/housewatch.sh --dry-run"],
    "pin": ["⬆️ Bring the pin to main|On {host}, run bin/engine/pin-refresh.sh --auto-tree and report the pin's new sha"],
    "unpushed": ["📦 Gather the waiting branches|On {host}, list the eindri branches with commits on no remote (bin/ward/trouble.sh read --only unpushed) and gather the finished ones with bin/forge/gather.sh --finished"],
    "questions": ["❓ Show the open questions|On {host}, show every unanswered file in the home's state/eindri-questions/ with its errand and age"],
    "errands": ["🔎 Show the troubled errands|On {host}, run bin/ward/trouble.sh read --only errands and show each errand's last status line and pane"],
    "hyprland": ["🪟 Show the Hyprland error|On {host}, run hyprctl configerrors and name the file and line that broke"],
    "tells": ["📨 Drain the arm's tells|On {host}, have the arm holder drain its wake queue (saga-session-start.sh --section wake) and answer the oldest tells"],
    "receipts": ["📬 Answer the waiting reports|On {host}, run bin/agents/veil.sh pending and answer each with bin/agents/veil.sh received <id>"],
    "loops": ["🐍 Show the looping branch|On {host}, run bin/gates/nidhogg.sh commits and show which writer repeats the commit, then stop that writer"],
}


def _sent(done) -> bool:
    """True only when send.sh decided `send` and exited 0. A refusal, a delivery nobody heard (exit 1), a
    `duplicate` or a `silenced` is NOT a notice the operator received, so the turn stays owed."""
    decision = ""
    lines = (done.stdout or "").splitlines()
    for i, x in enumerate(lines):
        if x.startswith("notify[") and i + 1 < len(lines):
            decision = lines[i + 1].strip().split(",")[0].strip().strip('"')
            break
    return done.returncode == 0 and decision == "send"


def notify(c: Ctx, owed: list[dict], turns: dict, dry: bool) -> tuple[list[str], list[str]]:
    """Say each owed turn to red. Returns (what send.sh answered, the signals now announced).

    The key is per TURN to red (`t<epoch the signal turned red>`), never per hour: a red that goes green
    and red again inside one hour is a new turn and news again, and a retry of the same turn carries the
    same key. The `t` prefix keeps send.sh from folding the epoch away as a stamp."""
    sent, announced = [], []
    door = os.environ.get("TROUBLE_SEND", "") or str(Path(c.root) / "bin/notify/send.sh")  # a test seam
    most = env_int("TROUBLE_NOTICE_MAX", 2)
    batches = [([r["signal"]], r) for r in owed]
    if len(owed) > most:
        # many at once (a first check, a machine back from the dark) is ONE line, never a burst
        names = ", ".join(r["signal"] for r in owed)
        newest = max(int(turns[r["signal"]]["turn"]) for r in owed)
        batches = [([r["signal"] for r in owed],
                    {"signal": "several", "note": f"{len(owed)} signals turned red: {names}", "turn": newest})]
    for signals, r in batches:
        turn = int(r.get("turn") or turns[r["signal"]]["turn"])
        line = f"{c.host} is in trouble — {r['signal']}: {r['note']}"[:400]
        args = ["bash", door, "--source", "ward", "--severity", "HIGH", "--message", line,
                "--key", f"trouble:{c.host}:{r['signal']}:t{turn}" + (":dry" if dry else "")]
        for spec in BUTTONS.get(r["signal"], []):
            args += ["--button", spec.format(host=c.host)]
        args += ["--button", f"📋 Show every trouble row|Run bin/ward/trouble.sh fleet and show every machine's trouble rows, red first"]
        if dry:
            args.append("--dry-run")
        done = run(args, timeout=60)
        decision = next((x.strip() for x in (done.stdout or "").splitlines()[1:2]), "")
        ok = (not dry) and _sent(done)
        if ok:
            announced += signals
        sent.append(f"{r['signal']}: send.sh exit {done.returncode} {decision}".strip()
                    + ("" if ok or dry else " (not delivered: retried on the next check)"))
    return sent, announced


def check(c: Ctx, only: list[str], do_notify: bool, dry: bool) -> dict:
    last_path = c.dir / f"{c.host}.json"
    # what was SAID is kept apart from what was READ: a reading is stored whatever happens, a turn is
    # marked announced only when send.sh decided `send` — so a failed or duplicate notice is retried
    turns_path = c.dir / f"{c.host}.announced.json"
    try:
        last = {r["signal"]: r["state"] for r in json.loads(last_path.read_text()).get("rows", [])}
    except (OSError, ValueError):
        last = {}
    try:
        turns = json.loads(turns_path.read_text())
        if not isinstance(turns, dict):
            turns = {}
    except (OSError, ValueError):
        turns = {}
    now = reading(c, only)
    turned = []
    for r in now["rows"]:
        sig = r["signal"]
        if r["state"] != "RED":
            turns.pop(sig, None)  # the turn is over; the next red is a new one
            continue
        if sig not in turns or last.get(sig) != "RED":
            turns[sig] = {"turn": int(c.now), "announced": False, "tries": 0}
            turned.append(sig)
    owed = [r for r in now["rows"] if r["state"] == "RED" and not turns.get(r["signal"], {}).get("announced")]
    now["turned_red"] = turned
    now["owed"] = [r["signal"] for r in owed]
    now["notices"] = []
    if do_notify and owed:
        now["notices"], announced = notify(c, owed, turns, dry)
        for r in owed:
            t = turns[r["signal"]]
            t["tries"] = int(t.get("tries", 0)) + (0 if dry else 1)
            if r["signal"] in announced:
                t["announced"], t["said_at"] = True, int(c.now)
    # a partial check (--only) keeps the other rows of the last reading, so it cannot erase them
    if only != list(SIGNALS) and last_path.exists():
        try:
            prior = json.loads(last_path.read_text())
            kept = [r for r in prior.get("rows", []) if r["signal"] not in only]
            now["rows"] = kept + now["rows"]
            now["red"] = sum(r["state"] == "RED" for r in now["rows"])
        except (OSError, ValueError):
            pass
    for path, body in ((last_path, now), (turns_path, turns)):
        tmp = path.with_suffix(f".tmp.{os.getpid()}")
        tmp.write_text(json.dumps(body, sort_keys=True))
        tmp.replace(path)
    return now


# ── the fleet: each row answers from its own machine ─────────────────────────────────────────────

def fleet(c: Ctx) -> list[dict]:
    reg = Path(c.home) / "hodd/data/fleet.json"
    try:
        hosts = (json.loads(reg.read_text()).get("hosts") or {})
    except (OSError, ValueError):
        return [{"host": c.host, "error": f"no fleet registry at {reg}"}]
    # plan 339.6: every machine in fleet.json owes the panel, a hand included; TROUBLE_ROLES only narrows
    owed = {x for x in os.environ.get("TROUBLE_ROLES", "").split(",") if x}
    out = []
    for name, h in hosts.items():
        roles = set(h.get("roles") or [])
        if owed and not roles & owed:
            continue
        if name == c.host:
            out.append(reading(c, list(SIGNALS)))
            continue
        if h.get("state") == "dark" or not (h.get("user") and h.get("tailnet")):
            out.append({"host": name, "error": f"not asked ({h.get('state') or 'no road'})"})
            continue
        road = f"{h['user']}@{h['tailnet']}"
        done = run(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=6", road, "bash -l -s"],
                   timeout=120, stdin=_remote_script())
        try:
            out.append(json.loads((done.stdout or "").strip().splitlines()[-1]))
        except (ValueError, IndexError):
            why = (done.stderr or "").strip().splitlines()[-1:] or [f"exit {done.returncode}"]
            out.append({"host": name, "error": f"no answer: {why[0][:120]}"})
    return out


def _remote_script() -> str:
    """What a far machine runs: its own panel from its pin; until a release carries one, THIS reader,
    handed over in the script, with that machine's own resolver naming its home. Either way the row
    is measured there, never here."""
    source = Path(__file__).read_text(encoding="utf-8")
    return (
        'd="${YMIR_RUNTIME_DIR:-$HOME/ymir-runtime}"; [ -f "$d/bin/vault/hoard-lib.sh" ] || d="$HOME/ymir"\n'
        'if [ -f "$d/bin/ward/trouble.sh" ]; then exec bash "$d/bin/ward/trouble.sh" read --json; fi\n'
        '. "$d/bin/vault/hoard-lib.sh" || { echo "no Ymir home resolver on this machine" >&2; exit 4; }\n'
        'H=""; ymir_home_root H; S=""; hoard_state_dir S 2>/dev/null; [ -n "$S" ] || S="$H/state"\n'
        'for e in "$H/config/runtime.env" "$H/config/trouble.env"; do [ -r "$e" ] && { set -a; . "$e"; set +a; }; done\n'
        'exec python3 - "$d" "$H" "$S" read --json <<\'TROUBLE_PY\'\n' + source + "\nTROUBLE_PY\n"
    )


# ── the faces ────────────────────────────────────────────────────────────────────────────────────

def toon(r: dict) -> str:
    rows = r.get("rows", [])
    lines = [f"trouble[{len(rows)}]{{host,signal,state,note}}:"]
    for x in rows:
        note = str(x["note"]).replace('"', "'")
        lines.append(f'  "{r["host"]}","{x["signal"]}","{x["state"]}","{note}"')
    return "\n".join(lines)


def sentence(r: dict) -> str:
    red = [x for x in r.get("rows", []) if x["state"] == "RED"]
    if not red:
        return f"{r['host']}: no trouble."
    return f"{r['host']}: {len(red)} in trouble — " + "; ".join(f"{x['signal']} ({x['note']})" for x in red)


def main(argv: list[str]) -> int:
    root, home, state = argv[1], argv[2], argv[3]
    args = argv[4:]
    verb = args.pop(0) if args and not args[0].startswith("-") else "read"
    as_json = "--json" in args
    only = list(SIGNALS)
    if "--only" in args:
        i = args.index("--only")
        only = [s for s in (args[i + 1] if i + 1 < len(args) else "").split(",") if s]
        unknown = [s for s in only if s not in PROBES]
        if unknown or not only:
            print(f"error: unknown signal {','.join(unknown) or '(none)'}\nhelp: {','.join(SIGNALS)}", file=sys.stderr)
            return 2
    c = Ctx(root, home, state)
    if verb == "read":
        r = reading(c, only)
        print(json.dumps(r) if as_json else toon(r) + "\n" + sentence(r))
        return 1 if r["red"] else 0
    if verb == "check":
        r = check(c, only, "--notify" in args, "--dry-run" in args)
        if as_json:
            print(json.dumps(r))
        else:
            print(toon(r) + "\n" + sentence(r))
            if r["owed"]:
                print(f"owed a notice: {', '.join(r['owed'])}" + (f" · turned red now: {', '.join(r['turned_red'])}" if r["turned_red"] else "")
                      + (f" · {'; '.join(r['notices'])}" if r["notices"] else " · (no notice: --notify not given)"))
        return 1 if r["red"] else 0
    if verb == "fleet":
        rs = fleet(c)
        if as_json:
            print(json.dumps(rs))
            return 0
        print("trouble-fleet{host,signal,state,note}:")
        for r in rs:
            if "error" in r:
                print(f'  "{r["host"]}","-","SKIP","{r["error"]}"')
                continue
            for x in sorted(r["rows"], key=lambda x: x["state"] != "RED"):
                print(f'  "{r["host"]}","{x["signal"]}","{x["state"]}","{str(x["note"]).replace(chr(34), chr(39))}"')
        for r in rs:
            print(sentence(r) if "error" not in r else f"{r['host']}: {r['error']}")
        return 1 if any(r.get("red") for r in rs) else 0
    print(f"error: unknown verb {verb}\nhelp: read | check | fleet", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
