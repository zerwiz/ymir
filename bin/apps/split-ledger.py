#!/usr/bin/env python3
"""split-ledger.py — the proof that an app's move out of Ymir lost nothing (the split's plan 02).

The Allfather, 2026-11-18: "make great splitting plans for all this. we can not lose anything".
"Lost" has six meanings, and this checks them by script, never by eye:

  files     every file the app has in Ymir is in its own repo, byte for byte (git blob ids)
  history   every commit that touched the app in Ymir is in its repo (author · date · subject)
  records   its fix notes, feature pages and catalogue rows still stand in Ymir (RULES/06)
  features  every feature page that names it is listed, to be exercised from the installed app
  state     its data: files, hashes, sqlite row counts and jsonl lines, the same before and after
  ties      no Ymir code still names `apps/<dir>` once the app has left (except the resolver's own tables)

Verbs:
  split-ledger.py inventory <app> [--ref REF] [--out DIR]
      the before-set from Ymir's own git: <app>.manifest.tsv (path · bytes · blob · sha256),
      <app>.history.tsv, <app>.records.tsv, <app>.features.tsv, <app>.ties.tsv
  split-ledger.py verify <app> --repo PATH [--app-ref REF] [--ref REF] [--moved FILE] [--after-removal]
      the app repo checked against the before-set; a TOON verdict, exit 1 on any loss
  split-ledger.py state <app> --snapshot FILE [--path P ...]
  split-ledger.py state --compare BEFORE AFTER
      the app's data counted and hashed, and two counts compared

Stdlib only. It reads; the only things it writes are its own ledger files.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sqlite3
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# The folder each app has in Ymir's tree, where it is not the app's own name.
DIRS = {"smidja": ["smidja-factory", "smidja"]}
# Where each of those folders sits INSIDE the app's own repo, when not at its root.
REPO_PREFIX = {("smidja", "smidja"): "engine/"}
# The files whose job is to name every app: they keep `apps/<dir>` on purpose (decision: kept).
RESOLVER_FILES = {"bin/apps/app-path.sh", "bin/apps/apps.py", "bin/apps/split-ledger.py",
                  "bin/desktop/app-lib.sh", "config/app-repos.yaml", ".agents/config/app-repos.yaml"}
CODE_EXT = {".sh", ".py", ".ts", ".tsx", ".js", ".mjs", ".cjs", ".json", ".yaml", ".yml", ".toml",
            ".service", ".desktop", ".ini", ".conf", ""}


def git(*args: str, repo: Path = ROOT, binary: bool = False):
    out = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=not binary)
    if out.returncode != 0:
        raise SystemExit(f"error: git {' '.join(args[:3])} failed in {repo}: "
                         f"{(out.stderr if not binary else out.stderr.decode(errors='replace')).strip()[-300:]}")
    return out.stdout


def dirs_of(app: str) -> list[str]:
    return DIRS.get(app, [app])


def tree_rows(ref: str, prefix: str, repo: Path = ROOT) -> list[tuple[str, int, str]]:
    """(path relative to prefix, bytes, blob id) for every file under prefix at ref."""
    rows = []
    out = git("ls-tree", "-r", "-l", "--full-tree", ref, "--", prefix.rstrip("/") + "/" if prefix else ".", repo=repo)
    for line in out.splitlines():
        meta, path = line.split("\t", 1)
        mode, kind, blob, size = meta.split()
        if kind != "blob":
            continue
        rel = path[len(prefix.rstrip("/")) + 1:] if prefix else path
        rows.append((rel, int(size) if size != "-" else 0, blob))
    return rows


def sha256_of_blobs(blobs: list[str], repo: Path = ROOT) -> dict[str, str]:
    """sha256 of each blob's content, through one `git cat-file --batch`."""
    if not blobs:
        return {}
    proc = subprocess.run(["git", "-C", str(repo), "cat-file", "--batch"], input="\n".join(blobs).encode() + b"\n",
                          capture_output=True)
    data, out, i = proc.stdout, {}, 0
    for blob in blobs:
        nl = data.index(b"\n", i)
        header = data[i:nl].split()
        size = int(header[2])
        body = data[nl + 1: nl + 1 + size]
        out[blob] = hashlib.sha256(body).hexdigest()
        i = nl + 1 + size + 1
    return out


def history(ref: str, path: str, repo: Path = ROOT) -> list[tuple[str, str, str]]:
    """(author email · author date · subject) per commit touching path — what filter-repo keeps."""
    out = git("log", "--format=%ae%x1f%aI%x1f%s", ref, "--", path, repo=repo)
    return [tuple(l.split("\x1f", 2)) for l in out.splitlines() if l]  # type: ignore[misc]


def write_tsv(path: Path, header: list[str], rows) -> None:
    path.write_text("\t".join(header) + "\n" + "".join("\t".join(str(c) for c in r) + "\n" for r in rows))


def read_tsv(path: Path) -> list[dict]:
    lines = path.read_text().splitlines()
    head = lines[0].split("\t")
    return [dict(zip(head, l.split("\t"))) for l in lines[1:] if l]


def names_of(app: str) -> list[str]:
    extra = {"odrerir": ["óðrerir"], "sessrumnir": ["sessrúmnir"], "smidja": ["smíðja"], "rodd": ["rödd"],
             "hlidskjalf": ["hliðskjálf"]}
    return [app, *extra.get(app, [])]


def ymir_files(ref: str) -> list[str]:
    return git("ls-tree", "-r", "--name-only", ref).splitlines()


# ── inventory ────────────────────────────────────────────────────────────────

def inventory(app: str, ref: str, out: Path) -> dict:
    out.mkdir(parents=True, exist_ok=True)
    sha = git("rev-parse", "--short=12", ref).strip()
    manifest, hist = [], []
    for d in dirs_of(app):
        rows = tree_rows(ref, f"apps/{d}")
        shas = sha256_of_blobs([b for _, _, b in rows])
        manifest += [(f"apps/{d}/{p}", n, b, shas.get(b, "")) for p, n, b in rows]
        hist += [(d, *h) for h in history(ref, f"apps/{d}")]
    write_tsv(out / f"{app}.manifest.tsv", ["path", "bytes", "blob", "sha256"], manifest)
    write_tsv(out / f"{app}.history.tsv", ["dir", "author", "date", "subject"], hist)
    files = ymir_files(ref)
    pats = [n.lower() for n in names_of(app)]
    records = [(f,) for f in files if f.startswith(("docs/fixes/", "docs/features/"))
               and (any(f"/{p}/" in f.lower() or p in Path(f).name.lower() for p in pats))]
    write_tsv(out / f"{app}.records.tsv", ["path"], records)
    feats = []
    for f in files:
        if f.startswith("docs/features/") and f.endswith(".md") and "/_catalogue/" not in f:
            text = git("show", f"{ref}:{f}").lower()
            if any(p in text for p in pats):
                feats.append((f,))
    write_tsv(out / f"{app}.features.tsv", ["page"], feats)
    ties = code_ties(app, ref)
    write_tsv(out / f"{app}.ties.tsv", ["path", "line", "decision"], ties)
    summary = {"app": app, "ref": sha, "files": len(manifest), "bytes": sum(int(r[1]) for r in manifest),
               "commits": len(hist), "records": len(records), "features": len(feats), "code_ties": len(ties)}
    (out / f"{app}.inventory.json").write_text(json.dumps(summary, indent=1))
    return summary


def code_ties(app: str, ref: str | None) -> list[tuple[str, int, str]]:
    """Code lines outside the app that name its folder: each must be cut, resolved or kept."""
    pats = [re.compile(re.escape(f"apps/{d}") + r"(?![\w-])") for d in dirs_of(app)]
    rows = []
    if ref:
        files = ymir_files(ref)
        read = lambda f: git("show", f"{ref}:{f}")  # noqa: E731
    else:
        # The working tree as git knows it: tracked files, as they stand now. An untracked scratch file is
        # nobody's tie.
        files = [f for f in git("ls-files").splitlines() if (ROOT / f).is_file()]
        read = lambda f: (ROOT / f).read_text(errors="replace")  # noqa: E731
    for f in files:
        if f.startswith(("apps/", "docs/", "RULES/")) or f.endswith(".md"):
            continue
        if Path(f).suffix not in CODE_EXT:
            continue
        try:
            text = read(f)
        except (SystemExit, OSError, UnicodeDecodeError):
            continue
        for i, line in enumerate(text.splitlines(), 1):
            if any(p.search(line) for p in pats) and not line.strip().startswith(("#", "//", "*")):
                rows.append((f, i, "kept" if f in RESOLVER_FILES else "owed"))
    return rows


# ── verify ───────────────────────────────────────────────────────────────────

def verify(app: str, repo: Path, app_ref: str, ref: str, moved: Path | None, after_removal: bool) -> tuple[bool, list]:
    verdict = []
    ok = True

    def add(check: str, passed: bool | None, detail: str):
        nonlocal ok
        if passed is False:
            ok = False
        verdict.append((check, "pass" if passed else ("note" if passed is None else "FAIL"), detail))

    # 1 · files — the app repo's root is the app's folder
    expected = []
    for d in dirs_of(app):
        pre = REPO_PREFIX.get((app, d), "")
        expected += [(pre + p, b) for p, _, b in tree_rows(ref, f"apps/{d}")]
    have = {p: b for p, _, b in tree_rows(app_ref, "", repo=repo)}
    changed = {}
    if moved and moved.is_file():
        changed = {}
        for r in read_tsv(moved):
            path = r["path"]
            for d in dirs_of(app):
                if path.startswith(f"apps/{d}/"):
                    path = REPO_PREFIX.get((app, d), "") + path[len(f"apps/{d}/"):]
            changed[path] = r
    missing = [p for p, b in expected if p not in have and p not in changed]
    differ = [p for p, b in expected if p in have and have[p] != b and p not in changed]
    add("files", not missing and not differ,
        f"{len(expected)} files; missing {len(missing)}{(' e.g. ' + ', '.join(missing[:3])) if missing else ''}; "
        f"changed without a moved.tsv reason {len(differ)}{(' e.g. ' + ', '.join(differ[:3])) if differ else ''}; "
        f"declared changes {len(changed)}")
    # 2 · history
    want = set()
    for d in dirs_of(app):
        want |= set(history(ref, f"apps/{d}"))
    got = set(history(app_ref, ".", repo=repo))
    lost = sorted(want - got)
    add("history", not lost, f"{len(want)} commits touched the app in Ymir; {len(lost)} not in the app repo"
        + (f" e.g. {lost[0][1][:10]} {lost[0][2][:60]}" if lost else ""))
    # 3 · records stay in Ymir
    pats = [n.lower() for n in names_of(app)]
    before = {f for f in ymir_files(ref) if f.startswith("docs/fixes/")
              and any(f"/{p}/" in f.lower() or p in Path(f).name.lower() for p in pats)}
    now = {f for f in before if (ROOT / f).exists()}
    add("records", before == now, f"{len(before)} fix notes in Ymir; {len(before - now)} gone")
    # 4 · features — listed for the acceptance run on the installed app
    feats = [f for f in ymir_files(ref) if f.startswith("docs/features/") and f.endswith(".md")
             and "/_catalogue/" not in f and any(p in (ROOT / f).read_text(errors="replace").lower() for p in pats
                                                 if (ROOT / f).exists())]
    add("features", None, f"{len(feats)} feature pages name it — each is exercised from the installed app")
    # 5 · state — its own verb; noted here
    add("state", None, "proved by `split-ledger.py state --compare before after` around the migration")
    # 6 · ties
    ties = code_ties(app, None)
    # A line may stay on purpose: config/split/<app>.kept.tsv names the file and why (every tie gets a
    # decision — cut, resolved or kept — and a kept one is written down, never assumed).
    kept_file = ROOT / "config" / "split" / f"{app}.kept.tsv"
    kept = {r["path"] for r in read_tsv(kept_file)} if kept_file.is_file() else set()
    owed = [t for t in ties if t[2] == "owed" and t[0] not in kept]
    if after_removal:
        add("ties", not owed, f"{len(owed)} code lines still name apps/{dirs_of(app)[0]}"
            + (f" e.g. {owed[0][0]}:{owed[0][1]}" if owed else ""))
    else:
        add("ties", None, f"{len(owed)} code lines name apps/{dirs_of(app)[0]} — each goes through the resolver before removal")
    return ok, verdict


# ── state ────────────────────────────────────────────────────────────────────

def snapshot(paths: list[Path]) -> dict:
    out: dict = {}
    for base in paths:
        if not base.exists():
            out[str(base)] = {"absent": True}
            continue
        files = [base] if base.is_file() else sorted(p for p in base.rglob("*") if p.is_file())
        for p in files:
            rec: dict = {"bytes": p.stat().st_size}
            if p.suffix in (".db", ".sqlite", ".sqlite3"):
                try:
                    with sqlite3.connect(f"file:{p}?mode=ro", uri=True) as c:
                        rec["tables"] = {t: c.execute(f'select count(*) from "{t}"').fetchone()[0]
                                         for (t,) in c.execute("select name from sqlite_master where type='table'")}
                except sqlite3.DatabaseError:
                    rec["tables"] = "unreadable"
            elif p.suffix == ".jsonl":
                with open(p, "rb") as fh:
                    rec["lines"] = sum(1 for _ in fh)
            else:
                h = hashlib.sha256()
                with open(p, "rb") as fh:
                    for b in iter(lambda: fh.read(1 << 20), b""):
                        h.update(b)
                rec["sha256"] = h.hexdigest()
            out[str(p.relative_to(base) if base.is_dir() else p.name)] = rec
    return out


def compare(before: dict, after: dict) -> list[str]:
    """What the after-snapshot lost or shrank. Growth is allowed (an append-only file grows)."""
    lost = []
    for k, b in before.items():
        a = after.get(k)
        if a is None:
            lost.append(f"{k}: gone")
            continue
        if "tables" in b and isinstance(b["tables"], dict):
            for t, n in b["tables"].items():
                if (a.get("tables") or {}).get(t, -1) < n:
                    lost.append(f"{k}: table {t} {n} -> {(a.get('tables') or {}).get(t)}")
        elif "lines" in b:
            if a.get("lines", -1) < b["lines"]:
                lost.append(f"{k}: {b['lines']} lines -> {a.get('lines')}")
        elif "sha256" in b and a.get("sha256") != b["sha256"]:
            lost.append(f"{k}: content changed")
    return lost


# ── the door ─────────────────────────────────────────────────────────────────

def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(prog="split-ledger.py", description=__doc__.split("\n\n")[0])
    sub = ap.add_subparsers(dest="verb", required=True)
    i = sub.add_parser("inventory"); i.add_argument("app"); i.add_argument("--ref", default="HEAD")
    i.add_argument("--out", default=str(ROOT / "state" / "split-ledger"))
    v = sub.add_parser("verify"); v.add_argument("app"); v.add_argument("--repo", required=True)
    v.add_argument("--app-ref", default="HEAD"); v.add_argument("--ref", default="HEAD")
    v.add_argument("--moved"); v.add_argument("--after-removal", action="store_true")
    s = sub.add_parser("state"); s.add_argument("app", nargs="?"); s.add_argument("--snapshot")
    s.add_argument("--path", action="append", default=[]); s.add_argument("--compare", nargs=2)
    a = ap.parse_args(argv)
    if a.verb == "inventory":
        r = inventory(a.app, a.ref, Path(a.out))
        print("inventory[1]{" + ",".join(r) + "}:\n  " + ",".join(json.dumps(str(x)) for x in r.values()))
        return 0
    if a.verb == "verify":
        ok, rows = verify(a.app, Path(a.repo), a.app_ref, a.ref, Path(a.moved) if a.moved else None, a.after_removal)
        print(f"split_verify[{len(rows)}]{{check,verdict,detail}}:")
        for r in rows:
            print("  " + ",".join(json.dumps(x, ensure_ascii=False) for x in r))
        print(f"verdict: {'nothing lost' if ok else 'LOSS — this slice stops here'}")
        return 0 if ok else 1
    if a.compare:
        before, after = (json.loads(Path(p).read_text()) for p in a.compare)
        lost = compare(before, after)
        print(f"state_compare[{len(lost)}]{{loss}}:")
        for l in lost:
            print(f'  "{l}"')
        print("verdict: " + ("the same (or grown)" if not lost else "LOSS"))
        return 1 if lost else 0
    if not (a.app and a.snapshot):
        ap.error("state needs <app> --snapshot FILE, or --compare BEFORE AFTER")
    state_home = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state")
    config_home = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    paths = [Path(p).expanduser() for p in a.path] or [state_home / a.app, config_home / a.app]
    snap = snapshot(paths)
    Path(a.snapshot).write_text(json.dumps(snap, indent=1))
    print(f"state[1]{{app,entries,file}}:\n  \"{a.app}\",\"{len(snap)}\",\"{a.snapshot}\"")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
