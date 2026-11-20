#!/usr/bin/env python3
"""kit.py — the collaboration kit's one command. Every subcommand reads project.yaml; none needs a package.

  kit.py config get <key>                    a value from project.yaml (lists one per line)
  kit.py worktree new <id> [--base B] [--owner O] [--purpose P] [--expires-days N]
  kit.py worktree list [--sizes]             every worktree, its state and why
  kit.py worktree done <id> [--salvage]      close one; refuses to lose work
  kit.py worktree gc [--apply] [--keep ID]…  close every worktree whose work is safe (salvage first)
  kit.py worktree salvage [--apply] [ID]     save a dead worker's work to the remote
  kit.py prune [--apply] [--class a,b] [--keep X]…   every leftover class (a report without --apply)
  kit.py doctor                              at session start: refuses new work over a budget
  kit.py check-host [--repo P]… [--strict] [--sizes]   the read-only machine report
  kit.py summary [--days 7]                  what the kit did, from the ledger
  kit.py timer [--install]                   the daily prune as a systemd user timer (printed unless --install)
  kit.py merge <pr> [--squash|--rebase]      merge a pull request, then close its worktree and branch
  kit.py road <old> <new>                    0 when a range carries only documents (the direct road)
  kit.py hooks install|uninstall|check       seat the hooks without taking the repository's own
  kit.py lang msg <file> | lang staged       the project tongue in commits; client tongues in client paths
  kit.py containers build|retain|<engine args>   the container door (see RULES/23)
  kit.py work start <id> | stop <id> [-m M] | track <id> --pid/--port/--db | sweep [--dry-run]
  kit.py stack status [app] | on <app>|--all-dev | off <app>|--all-dev [--piece NAME]
  kit.py deploy --release R [--dry-run] [--rollback]

Common flags: --repo <path> (default: the repository the command runs in), --json (one JSON object per line).
Exit: 0 ok · 1 refused or over a limit · 2 usage.
"""
from __future__ import annotations

import argparse
import getpass
import json
import os
import subprocess
import sys
import time
from pathlib import Path

sys.dont_write_bytecode = True  # a repository is never left with a __pycache__ the kit made
sys.path.insert(0, str(Path(__file__).resolve().parent))
from kitlib import config as C  # noqa: E402
from kitlib import containers as ct  # noqa: E402
from kitlib import deploy, host, hooks, languages, leftovers, stack, work, worktrees as wt  # noqa: E402


def _root(args) -> Path:
    return C.toplevel(args.repo) if getattr(args, "repo", None) else C.toplevel()


def cmd_config(args):
    cfg = C.load(_root(args))
    v = cfg.get_path(args.key)
    if v is None:
        return 1
    if isinstance(v, list):
        for x in v:
            print(json.dumps(x) if isinstance(x, (dict, list)) else x)
    elif isinstance(v, dict):
        print(json.dumps(v, sort_keys=True))
    else:
        print(v)
    return 0


def cmd_worktree(args):
    root = _root(args)
    cfg = C.load(root)
    if args.action == "new":
        return wt.new(cfg, root, args.id, args.base, args.owner or os.environ.get("KIT_OWNER") or getpass.getuser(),
                      args.purpose or "", args.expires_days, no_close=args.no_close)
    if args.action == "list":
        C.emit(wt.list_rows(cfg, root, args.sizes), args.json,
               ["id", "branch", "state", "why", "owner", "expires", "path"] + (["mb"] if args.sizes else []))
        return 0
    if args.action == "done":
        return wt.done(cfg, root, args.id, args.salvage)
    if args.action in ("gc", "salvage"):
        only = {args.id} if args.id else None
        rows = wt.run_gc(cfg, C.main_tree(str(root)), args.apply, set(args.keep or []), only=only)
        if args.action == "salvage":
            rows = [r for r in rows if r["verdict"] == "salvage"]
        C.emit(rows, args.json, ["verdict", "id", "reason", "done", "path"])
        n = {v: sum(1 for r in rows if r["verdict"] == v) for v in ("remove", "salvage", "keep")}
        mode = "applied" if args.apply else "report only — add --apply to act"
        print(f"# {n['remove']} to close, {n['salvage']} to salvage, {n['keep']} kept ({mode})", file=sys.stderr)
        return 0
    return 2


def cmd_prune(args):
    root = _root(args)
    cfg = C.load(root)
    classes = args.cls.split(",") if args.cls else leftovers.CLASSES
    rows = leftovers.run(cfg, root, classes, args.apply, set(args.keep or []), merged_only=args.merged_only)
    if args.quiet:
        rows = [r for r in rows if r["done"]]
    C.emit(rows, args.json, ["class", "verdict", "target", "reason", "done"])
    go = sum(1 for r in rows if r["verdict"] in ("remove", "salvage"))
    mode = "applied" if args.apply else "report only — add --apply to act"
    if not args.quiet:
        print(f"# {go} leftover(s) of {len(rows)} judged ({mode})", file=sys.stderr)
    return 0


def cmd_doctor(args):
    root = _root(args)
    rc, lines = host.doctor(C.load(root), root)
    print("\n".join(lines))
    return rc


def cmd_check_host(args):
    repos = [str(C.toplevel(r)) for r in (args.repo_list or [])]
    if not repos:
        m = C.machine()
        repos = [os.path.expanduser(r) for r in (m.get("repos") or []) if os.path.isdir(os.path.expanduser(r))]
    if not repos:
        try:
            repos = [str(C.toplevel())]
        except SystemExit:
            repos = []
    rows = host.check_host(repos, args.sizes)
    C.emit(rows, args.json, ["status", "area", "subject", "value", "limit"])
    over = [r for r in rows if r["status"] == "OVER"]
    print(f"# {len(over)} line(s) over a limit", file=sys.stderr)
    return 1 if (args.strict and over) else 0


def cmd_summary(args):
    print("\n".join(host.summary(_root(args), args.days)))
    return 0


def cmd_timer(args):
    units = host.timer_units(_root(args))
    if not args.install:
        for name, text in units.items():
            print(f"# ~/.config/systemd/user/{name}\n{text}")
        print("# install: kit.py timer --install   (then: systemctl --user enable --now <name>.timer)")
        return 0
    d = Path(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")) / "systemd" / "user"
    d.mkdir(parents=True, exist_ok=True)
    for name, text in units.items():
        (d / name).write_text(text)
        print(f"wrote\t{d / name}")
    timer = [n for n in units if n.endswith(".timer")][0]
    r = subprocess.run(["systemctl", "--user", "enable", "--now", timer], text=True, capture_output=True)
    print(f"enabled\t{timer}" if r.returncode == 0 else f"not enabled: {r.stderr.strip()}")
    return r.returncode


def cmd_merge(args):
    root = C.main_tree(str(_root(args)))
    cfg = C.load(root)
    info = subprocess.run(["gh", "pr", "view", str(args.pr), "--json", "headRefName,state"], cwd=str(root),
                          text=True, capture_output=True)
    if info.returncode != 0:
        print(f"refused: gh pr view {args.pr}: {info.stderr.strip()}")
        return 1
    head = json.loads(info.stdout)["headRefName"]
    if json.loads(info.stdout)["state"] != "MERGED":
        r = subprocess.run(["gh", "pr", "merge", str(args.pr), f"--{args.how}"], cwd=str(root))
        if r.returncode != 0:
            return r.returncode
    C.git("fetch", "-q", "--prune", "origin", cwd=str(root))
    for t in wt.listing(root):
        if t.branch == head:
            wid = wt.read_record(t.path).get("id") or os.path.basename(t.path)
            return wt.done(cfg, root, wid, False)
    print(f"merged\t#{args.pr}\t{head}\t(no worktree to close)")
    return 0


def cmd_road(args):
    """Which road a range takes: exit 0 when every file is a document or a handoff, 1 (naming the code) else."""
    root = _root(args)
    r = C.git("diff", "--name-only", args.old, args.new, cwd=str(root))
    if r.returncode != 0:
        print(f"road: cannot read the range: {r.stderr.strip()}")
        return 1
    files = [f for f in r.stdout.splitlines() if f.strip()]
    code = [f for f in files if not _is_document(root, f)]
    if not files:
        return 1
    if code:
        print("code (a pull request is the road): " + ", ".join(code[:10]) + (" …" if len(code) > 10 else ""))
        return 1
    print(f"documents only ({len(files)} file(s)): the direct road")
    return 0


DOC_DIRS = ("docs/", "handoff/", "plans/", "RULES/", "areas/")
DOC_EXT = (".md", ".txt", ".png", ".svg", ".jpg", ".jpeg", ".gif", ".webp", ".pdf")
CODE_DIRS = ("src/", "lib/", "apps/", "app/", "server/", "web/", "ui/", "scripts/", "bin/", ".githooks/",
             ".github/", "config/", "test/", "tests/", "deploy/", "priv/", "assets/")


def _globs(root: Path, name: str) -> list[str]:
    f = root / name
    return [l.strip() for l in f.read_text().splitlines() if l.strip() and not l.startswith("#")] if f.is_file() else []


def _is_document(root: Path, f: str) -> bool:
    import fnmatch
    if any(fnmatch.fnmatch(f, g) for g in _globs(root, ".code-paths")):
        return False
    if any(fnmatch.fnmatch(f, g) for g in _globs(root, ".docs-paths")):
        return True
    if f.startswith(DOC_DIRS):
        return f.endswith(DOC_EXT) or (f.startswith("areas/") and f.endswith((".yaml", ".yml")))
    return f.endswith(".md") and not f.startswith(CODE_DIRS)


def cmd_hooks(args):
    root = _root(args)
    cfg = C.load(root)
    if args.action == "install":
        print("\n".join(hooks.install(cfg, root)))
        return 0
    if args.action == "uninstall":
        print("\n".join(hooks.uninstall(root)))
        return 0
    rc, lines = hooks.check(cfg, root)
    print("\n".join(lines))
    return rc


def cmd_lang(args):
    root = _root(args)
    cfg = C.load(root)
    if args.action == "msg":
        text = Path(args.file).read_text(encoding="utf-8", errors="replace")
        found = languages.check_message(cfg, text)
        for f in found:
            print(f"commit-msg refused: {f}", file=sys.stderr)
        if found:
            print(f"help: write the message in '{cfg['languages']['project']}' (RULES/22)", file=sys.stderr)
        return 1 if found else 0
    items = languages.staged_lines(root) if args.action == "staged" else [
        (p, n, line) for p in args.paths for n, line in enumerate(Path(root, p).read_text(errors="replace").splitlines(), 1)]
    findings, faults = languages.check_lines(cfg, root, items)
    for f in findings + faults:
        print(f"language: {f}", file=sys.stderr)
    refuse = cfg["languages"].get("files") == "refuse"
    if findings and not refuse:
        print("language: reported, not refused (languages.files: report)", file=sys.stderr)
    return 1 if ((findings and refuse) or faults) else 0


def cmd_containers(args, rest):
    root = _root(args)
    cfg = C.load(root)
    if rest and rest[0] == "build":
        p = argparse.ArgumentParser(prog="containers build")
        p.add_argument("--tag", required=True)
        p.add_argument("--purpose", required=True)
        p.add_argument("--release", required=True)
        p.add_argument("context", nargs="?", default=".")
        a, extra = p.parse_known_args(rest[1:])
        return ct.build(cfg, root, a.tag, a.purpose, a.release, a.context, [x for x in extra if x != "--"])
    if rest and rest[0] == "retain":
        apply = "--apply" in rest
        rows = leftovers.run(cfg, root, ["images", "volumes", "stopped_containers"], apply, set())
        C.emit(rows, args.json, ["class", "verdict", "target", "reason", "done"])
        return 0
    return ct.door(cfg, rest)


def cmd_work(args):
    root = _root(args)
    cfg = C.load(root)
    if args.action == "start":
        return work.start(cfg, root, args.id, args.base, args.owner or os.environ.get("KIT_OWNER") or getpass.getuser(),
                          args.purpose or "", args.expires_days)
    if args.action == "stop":
        return work.stop(cfg, root, args.id, args.message, args.no_checks)
    if args.action == "track":
        return work.track(cfg, root, args.id, args.pid, args.port, args.db, args.what or "")
    return work.sweep(cfg, root, args.dry_run)


def cmd_stack(args):
    if args.action == "status":
        rows = stack.status(args.app)
        C.emit(rows, args.json, ["app", "role", "running", "piece", "mem", "cpu", "since", "owner"])
        return 0
    if not args.app and not args.all_dev:
        print("name an app, or --all-dev")
        return 2
    rc, lines = stack.switch(args.action, args.app, args.all_dev, args.piece)
    print("\n".join(lines))
    return rc


def cmd_deploy(args):
    root = _root(args)
    return deploy.run(C.load(root), root, args.release or time.strftime("%Y%m%d-%H%M"), args.dry_run, args.rollback)


def main(argv=None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    p = argparse.ArgumentParser(prog="kit.py", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--repo")
    p.add_argument("--json", action="store_true")
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("config"); s.add_argument("verb", choices=["get"]); s.add_argument("key")
    s = sub.add_parser("worktree")
    s.add_argument("action", choices=["new", "list", "done", "gc", "salvage"])
    s.add_argument("id", nargs="?")
    s.add_argument("--base"); s.add_argument("--owner"); s.add_argument("--purpose")
    s.add_argument("--expires-days", type=float); s.add_argument("--no-close", action="store_true")
    s.add_argument("--sizes", action="store_true"); s.add_argument("--salvage", action="store_true")
    s.add_argument("--apply", action="store_true"); s.add_argument("--keep", action="append")
    s = sub.add_parser("prune")
    s.add_argument("--apply", action="store_true"); s.add_argument("--class", dest="cls")
    s.add_argument("--keep", action="append"); s.add_argument("--merged-only", action="store_true")
    s.add_argument("--quiet", action="store_true")
    sub.add_parser("doctor")
    s = sub.add_parser("check-host")
    s.add_argument("--repo", dest="repo_list", action="append"); s.add_argument("--strict", action="store_true")
    s.add_argument("--sizes", action="store_true")
    s = sub.add_parser("summary"); s.add_argument("--days", type=int, default=7)
    s = sub.add_parser("timer"); s.add_argument("--install", action="store_true")
    s = sub.add_parser("merge"); s.add_argument("pr")
    g = s.add_mutually_exclusive_group()
    g.add_argument("--squash", dest="how", action="store_const", const="squash")
    g.add_argument("--rebase", dest="how", action="store_const", const="rebase")
    s.set_defaults(how="merge")
    s = sub.add_parser("road"); s.add_argument("old"); s.add_argument("new")
    s = sub.add_parser("hooks"); s.add_argument("action", choices=["install", "uninstall", "check"])
    s = sub.add_parser("lang"); s.add_argument("action", choices=["msg", "staged", "files"])
    s.add_argument("file", nargs="?"); s.add_argument("paths", nargs="*")
    sub.add_parser("containers", add_help=False)
    s = sub.add_parser("work"); s.add_argument("action", choices=["start", "stop", "track", "sweep"])
    s.add_argument("id", nargs="?"); s.add_argument("--base"); s.add_argument("--owner"); s.add_argument("--purpose")
    s.add_argument("--expires-days", type=float); s.add_argument("-m", "--message"); s.add_argument("--no-checks", action="store_true")
    s.add_argument("--pid", type=int); s.add_argument("--port", type=int); s.add_argument("--db"); s.add_argument("--what")
    s.add_argument("--dry-run", action="store_true")
    s = sub.add_parser("stack"); s.add_argument("action", choices=["status", "on", "off"]); s.add_argument("app", nargs="?")
    s.add_argument("--all-dev", action="store_true"); s.add_argument("--piece")
    s = sub.add_parser("deploy"); s.add_argument("--release"); s.add_argument("--dry-run", action="store_true")
    s.add_argument("--rollback", action="store_true")

    if "containers" in argv:
        i = argv.index("containers")
        args = p.parse_args(argv[: i + 1])
        return cmd_containers(args, argv[i + 1:])
    args = p.parse_args(argv)
    if args.cmd == "lang" and args.action == "files" and args.file:
        args.paths = [args.file] + args.paths
    if args.cmd == "work" and args.action != "sweep" and not args.id:
        p.error(f"work {args.action} needs an id")
    if args.cmd in ("worktree",) and args.action in ("new", "done") and not args.id:
        p.error(f"worktree {args.action} needs an id")
    return {"config": cmd_config, "worktree": cmd_worktree, "prune": cmd_prune, "doctor": cmd_doctor,
            "check-host": cmd_check_host, "summary": cmd_summary, "timer": cmd_timer, "merge": cmd_merge,
            "hooks": cmd_hooks, "lang": cmd_lang, "road": cmd_road,
            "work": cmd_work, "stack": cmd_stack, "deploy": cmd_deploy}[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
