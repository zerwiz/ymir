#!/usr/bin/env python3
"""worktree-reap.py — the road that made a worktree is the road that reaps it (plan 339.4).

THE FAULT (measured 2026-11-20): every errand road cuts a worktree and none removes it. The
disk filled to 100 %, and the largest single cost was 121 worker worktrees under an exterior
hands folder — 168 GiB, all made in four days, none reaped. `.yggdrasil/` under the repo held
dozens more whose errands had closed long before.

THE LAW this door keeps:

  * every road that creates a worktree RECORDS it here — its path, repository, branch, owner,
    errand and road (`record`);
  * an errand that closed `done:` loses its worktree once its work is held elsewhere — merged
    into the default branch, parked on `refs/parked/<errand>`, or pushed to a remote branch;
  * an errand that closed `failed:` keeps its worktree for 7 days (from the moment it closed),
    then loses it;
  * BRANCHES ARE NEVER DELETED. Only `git worktree remove` runs, never with --force. A tree
    with uncommitted changes is never removed — it is NAMED. A detached tree whose HEAD no
    ref holds is never removed either: removing it would orphan the commits;
  * a tree an agent stands in is never touched;
  * exterior roads (a worker system outside this repository) are covered by CONFIGURATION,
    a list of roots in the home (`config/worktree-roots.yaml`), never by a second reaper.

Usage:
  worktree-reap.py record --path P --errand E [--repo R] [--branch B] [--owner O] [--road R]
  worktree-reap.py sweep              # DRY RUN: what it WOULD reap, and why each tree stays
  worktree-reap.py sweep --apply      # remove what the dry run proved reapable
  worktree-reap.py sweep --quiet      # only the reap rows and the dirty names (seat-reap.sh --sweep)
  worktree-reap.py list               # the ledger as recorded
  worktree-reap.py roots              # the roots it walks, and where each came from

Env:
  YMIR_WORKTREE_LEDGER   the ledger dir (default $XDG_STATE_HOME/ymir/worktrees)
  YMIR_WORKTREE_ROOTS    the roots config (default $YMIR_HOME/config/worktree-roots.yaml)
  YMIR_HOME              the private home (else resolved by bin/vault/hoard-lib.sh)
  BROKK_STATE_OVERRIDE   one more shelf where `<errand>.status` may live
  YMIR_WORKTREE_REAP=off the sweep reports and removes nothing (the kill switch)
  YMIR_WORKTREE_NOW      epoch override (tests)
  YMIR_WORKTREE_REPO     the repository whose .yggdrasil is walked (default: this checkout's; tests fence it)
  YMIR_WORKTREE_AGENT_PROBE=off  never ask herdr whether an agent stands in a tree (tests)

Exit: 0 ok · 1 a fault · 2 usage.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import time
from pathlib import Path

VERSION = "1.0.0"
HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
FAILED_KEEP_DAYS = 7


# ── small doors ─────────────────────────────────────────────────────────────
def now() -> float:
    v = os.environ.get("YMIR_WORKTREE_NOW", "")
    return float(v) if v else time.time()


def home() -> Path:
    """The private home, through the one resolver (bin/vault/hoard-lib.sh ymir_home_root) — never guessed."""
    env = os.environ.get("YMIR_HOME")
    if env:
        return Path(env).expanduser()
    lib = ROOT / "bin" / "vault" / "hoard-lib.sh"
    if lib.exists():
        try:
            out = subprocess.run(["bash", "-c", f'. "{lib}" >/dev/null 2>&1; ymir_home_root H >/dev/null 2>&1; printf %s "$H"'],
                                 capture_output=True, text=True, timeout=10).stdout.strip()
            if out:
                return Path(out)
        except Exception:  # noqa: BLE001
            pass
    raise SystemExit("no home: set YMIR_HOME or run bin/engine/ymir-install.sh (the resolver found none)")


def ledger_dir() -> Path:
    v = os.environ.get("YMIR_WORKTREE_LEDGER")
    if v:
        return Path(v).expanduser()
    base = os.environ.get("XDG_STATE_HOME") or str(Path.home() / ".local" / "state")
    return Path(base) / "ymir" / "worktrees"


def git(*args: str, cwd: str | Path | None = None, timeout: float = 30) -> tuple[int, str]:
    try:
        r = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return 1, str(exc)
    return r.returncode, (r.stdout or "").strip()


def key_of(path: str) -> str:
    return hashlib.sha1(path.encode()).hexdigest()[:16]


def q(s: object) -> str:
    return '"' + str(s).replace('"', "'").replace("\n", " ") + '"'


def this_repo() -> Path | None:
    """The repository whose .yggdrasil is always walked. YMIR_WORKTREE_REPO fences it (tests)."""
    v = os.environ.get("YMIR_WORKTREE_REPO")
    return Path(v).expanduser() if v else common_repo(ROOT)


def common_repo(path: Path) -> Path | None:
    """The main checkout a linked worktree belongs to (the dir holding the common .git)."""
    rc, out = git("rev-parse", "--path-format=absolute", "--git-common-dir", cwd=path)
    if rc != 0 or not out:
        return None
    p = Path(out)
    return p.parent if p.name == ".git" else p


# ── the ledger ──────────────────────────────────────────────────────────────
def cmd_record(a: argparse.Namespace) -> int:
    path = Path(a.path).expanduser()
    if not path.is_dir():
        print(f"error: no worktree at {path}\nhelp: record after the worktree is made", file=sys.stderr)
        return 1
    path = path.resolve()
    repo = Path(a.repo).expanduser().resolve() if a.repo else common_repo(path)
    branch = a.branch
    if not branch:
        rc, out = git("symbolic-ref", "--quiet", "--short", "HEAD", cwd=path)
        branch = out if rc == 0 else "(detached)"
    rec = {
        "path": str(path),
        "repo": str(repo or ""),
        "branch": branch,
        "errand": a.errand,
        "owner": a.owner or "",
        "road": a.road or "",
        "created": int(now()),
        "created_iso": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now())),
    }
    d = ledger_dir()
    d.mkdir(parents=True, exist_ok=True)
    f = d / f"{key_of(str(path))}.json"
    if f.exists():  # a re-seat keeps the first birth, takes the newest owner
        try:
            old = json.loads(f.read_text())
            rec["created"], rec["created_iso"] = old.get("created", rec["created"]), old.get("created_iso", rec["created_iso"])
        except (OSError, ValueError):
            pass
    tmp = f.with_suffix(f".tmp{os.getpid()}")
    tmp.write_text(json.dumps(rec, indent=1) + "\n")
    tmp.replace(f)
    print("worktree-record[1]{errand,road,owner,path}:")
    print(f"  {q(a.errand)},{q(rec['road'])},{q(rec['owner'])},{q(path)}")
    return 0


def ledger() -> list[dict]:
    out = []
    d = ledger_dir()
    if not d.is_dir():
        return out
    for f in sorted(d.glob("*.json")):
        try:
            r = json.loads(f.read_text())
            r["_file"] = str(f)
            out.append(r)
        except (OSError, ValueError):
            continue
    return out


# ── the roots: configured (exterior) and implied (<repo>/.yggdrasil) ────────
def roots_config() -> Path:
    v = os.environ.get("YMIR_WORKTREE_ROOTS")
    return Path(v).expanduser() if v else home() / "config" / "worktree-roots.yaml"


def load_roots(recs: list[dict]) -> list[dict]:
    roots: list[dict] = []
    cfg = roots_config()
    if cfg.is_file():
        try:
            import yaml  # noqa: PLC0415 - optional, only when a config exists

            data = yaml.safe_load(cfg.read_text()) or {}
        except Exception as exc:  # noqa: BLE001
            print(f"warning: {cfg} unreadable ({exc}) — exterior roots skipped", file=sys.stderr)
            data = {}
        for r in data.get("roots") or []:
            if not isinstance(r, dict) or not r.get("path"):
                continue
            roots.append({
                "path": str(Path(os.path.expandvars(str(r["path"]))).expanduser()),
                "owner": str(r.get("owner") or ""),
                "rule": str(r.get("rule") or "status"),
                "status_dirs": [str(Path(os.path.expandvars(str(s))).expanduser()) for s in r.get("status_dirs") or []],
                "failed_keep_days": float(r.get("failed_keep_days") or FAILED_KEEP_DAYS),
                "idle_days": float(r.get("idle_days") or 0),
                "from": str(cfg),
            })
    seen = {r["path"] for r in roots}
    repos = {Path(r["repo"]) for r in recs if r.get("repo")}
    main = this_repo()
    if main:
        repos.add(main)
    for repo in sorted(repos):
        p = str(repo / ".yggdrasil")
        if p not in seen and Path(p).is_dir():
            seen.add(p)
            roots.append({"path": p, "owner": "", "rule": "status", "status_dirs": [str(repo / "state")],
                          "failed_keep_days": FAILED_KEEP_DAYS, "idle_days": 0, "from": "implied (the repo's .yggdrasil)"})
    return roots


def status_dirs(extra: list[str]) -> list[Path]:
    cands = [os.environ.get("BROKK_STATE_OVERRIDE", ""), *extra, str(home() / "state")]
    main = this_repo()
    if main:
        cands.append(str(main / "state"))
    cands.append(str(Path.home() / "ymir-runtime" / "state"))
    out: list[Path] = []
    for c in cands:
        if c and Path(c).is_dir() and Path(c) not in out:
            out.append(Path(c))
    return out


def errand_status(errand: str, dirs: list[Path]) -> tuple[str, str, float]:
    """(word, line, closed_at) from the newest `<errand>.status` on any shelf."""
    best: tuple[str, str, float] = ("", "", 0.0)
    for d in dirs:
        f = d / f"{errand}.status"
        try:
            lines = [ln for ln in f.read_text(errors="replace").splitlines() if ln.strip()]
            mt = f.stat().st_mtime
        except OSError:
            continue
        if lines and mt >= best[2]:
            last = lines[-1].strip()
            best = (last.split(":", 1)[0].strip().lower(), last, mt)
    return best


# ── the facts about one tree ────────────────────────────────────────────────
def proc_cwds() -> list[str]:
    out = []
    for p in Path("/proc").glob("[0-9]*"):
        try:
            out.append(os.readlink(p / "cwd"))
        except OSError:
            continue
    return out


def in_use(path: str, cwds: list[str]) -> bool:
    return any(c == path or c.startswith(path + "/") for c in cwds)


# A process inside a tree is not proof an AGENT works there: a finished Eindri exits to a bare
# shell that herdr restores forever (measured 2026-11-10 in bin/forge/housekeeping.sh). One door
# answers "does an agent stand here" — bin/seat/herdr-agents.py. When it cannot answer, every
# process counts as live: assuming dead is the irreversible direction.
AGENTS = ROOT / "bin" / "seat" / "herdr-agents.py"


def agent_probe_ok() -> bool:
    if os.environ.get("YMIR_WORKTREE_AGENT_PROBE") == "off" or not AGENTS.is_file():
        return False
    try:
        return subprocess.run([sys.executable, str(AGENTS), "--json"], capture_output=True, timeout=20).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def agent_here(path: str) -> bool:
    try:
        r = subprocess.run([sys.executable, str(AGENTS), "--find", "--cwd", path], capture_output=True, timeout=20)
    except (OSError, subprocess.TimeoutExpired):
        return True
    return r.returncode == 0


def default_ref(repo: Path) -> str:
    rc, out = git("symbolic-ref", "--quiet", "refs/remotes/origin/HEAD", cwd=repo)
    if rc == 0 and out:
        return out.replace("refs/remotes/", "", 1)
    for cand in ("origin/main", "origin/master", "main", "master"):
        if git("rev-parse", "--verify", "--quiet", cand, cwd=repo)[0] == 0:
            return cand
    return "HEAD"


def landed(path: str, repo: Path, errand: str, head: str) -> str:
    """Where this tree's work is held elsewhere: merged · parked · pushed — or ''."""
    base = default_ref(repo)
    if git("merge-base", "--is-ancestor", head, base, cwd=repo)[0] == 0:
        return "merged"
    rc, cherry = git("cherry", base, head, cwd=repo)
    if rc == 0 and cherry and not any(ln.startswith("+") for ln in cherry.splitlines()):
        return "merged"  # every patch already upstream (rebase / squash of the same patch)
    rc, out = git("for-each-ref", "--format=%(refname)", "--contains", head, "refs/parked", "refs/remotes", cwd=repo)
    refs = [r for r in out.splitlines() if r and not r.endswith("/HEAD")] if rc == 0 else []
    if any(r.startswith("refs/parked/") or "/parked/" in r for r in refs):
        return "parked"
    rc, out = git("ls-remote", "origin", f"refs/parked/{errand}", cwd=repo, timeout=15)
    if rc == 0 and out:
        sha = out.split()[0]
        if git("merge-base", "--is-ancestor", head, sha, cwd=repo)[0] == 0:
            return "parked"
    if refs:
        return "pushed"
    return ""


def held_by_a_ref(repo: Path, head: str) -> bool:
    rc, out = git("for-each-ref", "--format=%(refname)", "--contains", head, "refs/heads", "refs/remotes", "refs/parked", cwd=repo)
    return rc == 0 and bool(out.strip())


def index_age_days(path: str) -> float:
    rc, idx = git("rev-parse", "--path-format=absolute", "--git-path", "index", cwd=path)
    try:
        return (now() - Path(idx).stat().st_mtime) / 86400 if rc == 0 else 0.0
    except OSError:
        return 0.0


PROBE = {"ok": False}


def judge(t: dict, cwds: list[str]) -> tuple[str, str]:
    """(verdict, why). verdict starts with `reap:` or `keep:` or is `forget` (a vanished tree)."""
    path = t["path"]
    if not Path(path).exists():
        return "forget", "the folder is gone — the record and git's own entry are pruned"
    repo = Path(t["repo"]) if t.get("repo") else common_repo(Path(path))
    if repo is None:
        return "keep:unreadable", "git cannot read it"
    t["repo"] = str(repo)
    if Path(path).resolve() == repo.resolve():
        return "keep:main", "the main checkout is never reaped"
    rc, dirty = git("status", "--porcelain", cwd=path)
    if rc != 0:
        return "keep:unreadable", "git status failed"
    if dirty:
        n = len(dirty.splitlines())
        return "keep:dirty", f"{n} uncommitted change(s) — never removed; land or discard them by hand"
    t["bare_shell"] = False
    if in_use(path, cwds):
        if not PROBE["ok"] or agent_here(path):
            return "keep:in-use", "an agent (or a process no door can rule out) stands inside it"
        t["bare_shell"] = True  # judged on; --apply closes the shell first (bin/seat/seat-reap.sh --shell)
    rc, head = git("rev-parse", "HEAD", cwd=path)
    if rc != 0:
        return "keep:unreadable", "no HEAD"
    rule = t.get("rule", "status")
    if rule == "landed":
        where = landed(path, repo, t["errand"], head)
        if where:
            return f"reap:landed-{where}", f"its work is {where}; the branch stays"
        idle = t.get("idle_days") or 0
        if idle and held_by_a_ref(repo, head) and index_age_days(path) >= idle:
            return "reap:idle", f"untouched {index_age_days(path):.0f}d (>= {idle:g}d) and its commits are held by a branch"
        return "keep:unlanded", "its commits are not merged, parked or pushed"
    word, line, closed = errand_status(t["errand"], status_dirs(t.get("status_dirs") or []))
    if not word:
        return "keep:no-record", f"no {t['errand']}.status on any shelf — an open errand is never guessed closed"
    if word not in ("done", "failed"):
        return "keep:open", f"the errand's last word is '{word}'"
    where = landed(path, repo, t["errand"], head)  # asked only of a closed errand (it may ask the remote)
    if word == "done":
        if where:
            return f"reap:done-{where}", f"closed done and its work is {where}; the branch stays"
        return "keep:done-unlanded", "closed done, but its commits are on no remote and not in the default branch — gather or park them"
    if word == "failed":
        keep = float(t.get("failed_keep_days") or FAILED_KEEP_DAYS)
        age = (now() - closed) / 86400
        if age < keep:
            return "keep:failed-held", f"closed failed {age:.1f}d ago — held {keep:g}d ({keep - age:.1f}d left)"
        if not where and not held_by_a_ref(repo, head):
            return "keep:failed-orphan", "detached HEAD no ref holds — removing it would orphan the commits"
        return "reap:failed-expired", f"closed failed {age:.0f}d ago (>= {keep:g}d); the branch stays"
    return "keep:open", f"the errand's last word is '{word}'"


# ── gather every tree to judge ──────────────────────────────────────────────
def trees() -> list[dict]:
    recs = ledger()
    by_path: dict[str, dict] = {}
    for r in recs:
        by_path[r["path"]] = {**r, "recorded": "yes", "rule": "status", "status_dirs": [],
                              "failed_keep_days": FAILED_KEEP_DAYS}
    for root in load_roots(recs):
        rp = Path(root["path"])
        if not rp.is_dir():
            continue
        for sub in sorted(rp.iterdir()):
            if not (sub / ".git").is_file():  # a linked worktree carries a .git FILE
                continue
            p = str(sub.resolve())
            t = by_path.get(p) or {"path": p, "repo": "", "branch": "", "errand": sub.name,
                                   "owner": root["owner"], "road": "", "recorded": "no"}
            t.update({"rule": root["rule"], "status_dirs": root["status_dirs"],
                      "failed_keep_days": root["failed_keep_days"], "idle_days": root["idle_days"]})
            if root["owner"] and not t.get("owner"):
                t["owner"] = root["owner"]
            by_path[p] = t
    for t in by_path.values():
        if not t.get("branch") and Path(t["path"]).exists():
            rc, out = git("symbolic-ref", "--quiet", "--short", "HEAD", cwd=t["path"])
            t["branch"] = out if rc == 0 else "(detached)"
    return sorted(by_path.values(), key=lambda t: t["path"])


def remove(t: dict) -> tuple[bool, str]:
    repo = t["repo"]
    rc, out = git("worktree", "remove", t["path"], cwd=repo, timeout=300)  # never --force
    git("worktree", "prune", cwd=repo)
    if rc != 0:
        return False, out or "git refused"
    return True, ""


def cmd_sweep(a: argparse.Namespace) -> int:
    apply = a.apply and os.environ.get("YMIR_WORKTREE_REAP", "on") != "off"
    cwds = proc_cwds()
    PROBE["ok"] = agent_probe_ok()
    rows = []
    for t in trees():
        v, why = judge(t, cwds)
        if t.get("bare_shell") and v.startswith("reap:"):
            why += " · a bare shell holds it and is closed first"
        rows.append((t, v, why))
    reap = [r for r in rows if r[1].startswith("reap:") or r[1] == "forget"]
    dirty = [r for r in rows if r[1] == "keep:dirty"]
    mode = "apply" if apply else ("dry-run (YMIR_WORKTREE_REAP=off)" if a.apply else "dry-run")
    print("worktree-reap[1]{mode,trees,would_reap,dirty_named,kept}:")
    print(f"  {q(mode)},{len(rows)},{len(reap)},{len(dirty)},{len(rows) - len(reap)}")
    shown = rows if a.all else [r for r in rows if r[1] not in ("keep:no-record", "keep:open")]
    if a.quiet:  # the session sweep: only what is reaped, and the dirty trees named in one line
        shown = [r for r in rows if r[1].startswith("reap:") or r[1] == "forget"]
    print(f"trees[{len(shown)}]{{verdict,errand,road,owner,branch,path,why}}:")
    for t, v, why in shown:
        print(f"  {q(v)},{q(t.get('errand',''))},{q(t.get('road') or ('-' if t.get('recorded') == 'yes' else 'unrecorded'))},"
              f"{q(t.get('owner',''))},{q(t.get('branch',''))},{q(t['path'])},{q(why)}")
    hidden = len(rows) - len(shown)
    if a.quiet:
        if dirty:
            print("dirty (named, never removed): " + ", ".join(t["path"] for t, _v, _w in dirty))
    elif hidden:
        print(f"note: {hidden} open or recordless tree(s) not shown — --all lists them")
    if not apply:
        if a.quiet:
            return 0
        print("nothing was removed. --apply reaps the rows marked reap:/forget; branches are never deleted.")
        return 0
    removed = forgot = refused = 0
    for t, v, why in reap:
        if v == "forget":
            if t.get("repo"):
                git("worktree", "prune", cwd=t["repo"])
            if t.get("_file"):
                Path(t["_file"]).unlink(missing_ok=True)
            forgot += 1
            print(f"  forgot:{q(t['path'])}")
            continue
        again, _ = judge(dict(t), proc_cwds())  # re-ask immediately before touching it
        if not again.startswith("reap:"):
            refused += 1
            print(f"  refused:{q(t['path'])} changed to {again}")
            continue
        if t.get("bare_shell"):
            closer = ROOT / "bin" / "seat" / "seat-reap.sh"
            shut = subprocess.run(["bash", str(closer), "--shell", t["path"]], capture_output=True, timeout=120) \
                if closer.is_file() else None
            if shut is None or shut.returncode != 0 or in_use(t["path"], proc_cwds()):
                refused += 1
                print(f"  refused:{q(t['path'])} a bare shell holds it and would not close (bin/seat/seat-reap.sh --shell)")
                continue
        ok, err = remove(t)
        if ok:
            removed += 1
            if t.get("_file"):
                Path(t["_file"]).unlink(missing_ok=True)
            print(f"  removed:{q(t['path'])} ({v}; branch {t.get('branch','')} kept)")
        else:
            refused += 1
            print(f"  kept:{q(t['path'])} (git refused: {err})")
    print("worktree-reap[1]{removed,forgot,refused}:")
    print(f"  {removed},{forgot},{refused}")
    return 0


def cmd_list(_a: argparse.Namespace) -> int:
    recs = ledger()
    print(f"ledger[{len(recs)}]{{errand,road,owner,branch,created,path}}:")
    for r in recs:
        print(f"  {q(r.get('errand',''))},{q(r.get('road',''))},{q(r.get('owner',''))},{q(r.get('branch',''))},"
              f"{q(r.get('created_iso',''))},{q(r['path'])}")
    print(f"ledger_dir: {ledger_dir()}")
    return 0


def cmd_roots(_a: argparse.Namespace) -> int:
    roots = load_roots(ledger())
    print(f"roots[{len(roots)}]{{path,rule,owner,from}}:")
    for r in roots:
        print(f"  {q(r['path'])},{q(r['rule'])},{q(r['owner'])},{q(r['from'])}")
    print(f"config: {roots_config()}{'' if roots_config().is_file() else ' (absent — only implied roots)'}")
    return 0


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(prog="worktree-reap.py", description=__doc__.split("\n", 1)[0])
    ap.add_argument("-V", "--version", action="version", version=VERSION)
    sub = ap.add_subparsers(dest="cmd")
    r = sub.add_parser("record")
    r.add_argument("--path", required=True)
    r.add_argument("--errand", required=True)
    r.add_argument("--repo")
    r.add_argument("--branch")
    r.add_argument("--owner")
    r.add_argument("--road")
    s = sub.add_parser("sweep")
    s.add_argument("--apply", action="store_true")
    s.add_argument("--all", action="store_true", help="also list open and recordless trees")
    s.add_argument("--quiet", action="store_true", help="only the reaped rows and the dirty names (the session sweep)")
    sub.add_parser("list")
    sub.add_parser("roots")
    a = ap.parse_args(argv)
    if a.cmd == "record":
        return cmd_record(a)
    if a.cmd == "sweep":
        return cmd_sweep(a)
    if a.cmd == "list":
        return cmd_list(a)
    if a.cmd == "roots":
        return cmd_roots(a)
    ap.print_usage(sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
