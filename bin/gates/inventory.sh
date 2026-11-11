#!/usr/bin/env bash
# inventory.sh — the honest index of the two shelves nobody can read.
#
# WHY (2026-10-02): the Allfather asked *"do we have a readme in the bin folder and backend
# folder over what every file are doing?"* — one existed, and it was worthless:
#
#   files in bin/            389
#   entries in bin/README.md 105     ← 284 files with no entry at all
#   entries ending mid-sentence  6     ← truncated headers
#   a generator                    none  ← it was hand-written once
#   a checker                      none  ← so it silently rotted
#
# This writes BOTH inventories from the files themselves.
#
# BUILT, NOT VERSIONED (plan 243 part A, 2026-11-11). The Allfather: *"the index systems are
# idiotic. we are having so much merge problems."* These files left git: every branch used to
# rewrite them at the same sorted position, so every two open PRs conflicted, and main's own
# copies drifted (12 of 35 were stale at 3f263f69, which refused pushes for drift nobody
# caused). They are now built where they are read — by install, by update, by the session
# start (cached), and on demand — and `--check` judges the SOURCE, never a committed copy:
# every tracked door must be one the index can SEE (a row for it) and DESCRIBE (a header).
#
# Per file it reports, all measured rather than judged:
#   does        the file's own header, first COMPLETE sentence
#   kind        door · lib · tool · provenance(fm-*) · module
#   verdict     tested · wired · internal · orphan        (liveness, strongest first)
#   disposition keep · migrate → src/ymir_runtime/<mod> · retire · provenance
#   called-by   the doors that invoke it
#
#   bin/gates/inventory.sh            # write bin/README.md, bin/INDEX.md, bin/<folder>/INDEX.md,
#                                     #   .agents/backend/README.md — and nothing else
#   bin/gates/inventory.sh --check    # judge the SOURCES: a door no index can see, or one
#                                     #   with no header to index it, is refused
set -uo pipefail

# Walk UP until we find the repo, rather than assuming one level. `bin/gates/capabilities.sh` and
# `bin/gates/capabilities.sh` BOTH have to work, and the difference is depth — a fixed `..`
# made the nested copy resolve ROOT to `bin/`, so it looked for `bin/*.sh` inside `bin/`,
# found nothing, and rendered a 2-row register over a 400-door house. Nesting must not be able
# to blind the index. (2026-10-04)
_root() {
  local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ "$d" != "/" ]; do
    [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
}
ROOT="$(_root)"
MODE="${1:-write}"

python3 - "$ROOT" "$MODE" <<'PY'
import os, re, subprocess, sys, json
from pathlib import Path

ROOT, MODE = Path(sys.argv[1]), sys.argv[2]
BIN = ROOT / "bin"
BACKEND = ROOT / ".agents" / "backend"
SRC = ROOT / "src" / "ymir_runtime"

def read(p, n=200000):
    try: return p.read_text(errors="ignore")[:n]
    except Exception: return ""

def first_sentence(text, limit=140):
    """The file's own header, first COMPLETE sentence (never a truncated line)."""
    lines = text.splitlines()
    for i, ln in enumerate(lines[:40]):
        s = ln.strip()
        if not s or s.startswith("#!") or s.startswith("set "):
            continue
        s = re.sub(r"^#+\s*", "", s).strip()
        s = re.sub(r"\s+", " ", s)
        if len(s) < 3:
            continue
        m = re.match(r"^(.{10,}?[.!?])(\s|$)", s)
        s = m.group(1) if m else s
        return (s[:limit - 1].rstrip() + "…") if len(s) > limit else s
    return "(no header)"

# ---- corpus: everything that can prove a file is alive -----------------------
# TWO bugs lived here (2026-10-02), and CI caught the second:
#
#   1. The roots were `agents` and `pi` — DIRECTORIES THAT DO NOT EXIST. The real shelves
#      are `.agents` (723 tracked files) and `.pi` (57), so the single largest body of
#      proof-of-alive evidence in the house was silently excluded from every verdict.
#   2. A `find`/`os.walk` corpus includes gitIGNORED files, so a machine with local state
#      (`.agents/state/`, `.agents/skills-local/`, `.opencode/node_modules/`) renders a
#      DIFFERENT index than a fresh checkout. CI then reads the committed index, finds it
#      stale, and fails — correctly — for a difference no reviewer can see in the diff.
#
# So the corpus is now `git ls-files`: TRACKED files only. A generated index must be
# reproducible from a clean checkout by construction, or its `--check` is a lottery.
TEXTY = (".sh", ".md", ".ts", ".tsx", ".py", ".yaml", ".yml", ".json", ".toml", ".mjs", ".js")
# Index modes are portable; os.access(X_OK) reports ordinary files executable on
# Windows/DrvFS. NUL-delimited stage records preserve whitespace in tracked paths.
index = subprocess.run(["git", "ls-files", "--stage", "-z"], cwd=ROOT,
                       capture_output=True, check=True).stdout
tracked_modes = {}
for record in index.split(b"\0"):
    if not record:
        continue
    metadata, filename = record.split(b"\t", 1)
    mode, _object, stage = metadata.split()
    if stage == b"0":
        tracked_modes[os.fsdecode(filename)] = mode
tracked = list(tracked_modes)
tracked_set = set(tracked)
corpus_paths = [ROOT / p for p in tracked if p.endswith(TEXTY)]
corpus = []
for p in corpus_paths:
    corpus.append(read(p))
for f in ("AGENTS.md", "README.md", "opencode.json", "package.json"):
    corpus.append(read(ROOT / f))
CORPUS = "\n".join(corpus)

# A test is a test wherever it lives. This used to read ONLY `.agents/tests/`, so 73 doors
# that `src/ymir_runtime/tests/` and the `.agents/backend/fm-*.test.sh` suites really do
# exercise were reported untested — which is how a second register could claim 64 of them
# were undecided while the first said they were fine.
TEST_ROOTS = (".agents/tests", "src", "tools", ".agents/backend", "apps", "packages")
TESTS = "\n".join(
    read(p)
    for root in TEST_ROOTS
    for p in (ROOT / root).rglob("*")
    if p.is_file() and (".test." in p.name or "/tests/" in p.as_posix() or p.name.endswith("_test.py"))
) or ""

PY_MODULES = {p.stem for p in SRC.rglob("*.py")} if SRC.exists() else set()
PY_MODULE_PATHS = {p.stem: p.relative_to(ROOT).as_posix() for p in SRC.rglob("*.py")} if SRC.exists() else {}

def counterpart(stem):
    """A python module with the same name, if the runtime already owns this."""
    s = re.sub(r"^(fm|brokk|ymir|agent)-", "", stem)
    s = re.sub(r"-(lib|sh)$", "", s).replace("-", "_")
    for cand in (stem.replace("-", "_"), s):
        if cand in PY_MODULES:
            return PY_MODULE_PATHS.get(cand)
    return None

# The doors that may call a door: TRACKED bin files only, computed ONCE.
# This was `BIN.rglob("*")` INSIDE analyse() — a filesystem walk per file (quadratic)
# that also counted untracked scripts, so a seat's `called-by` totals ran higher than a
# clean checkout's and the committed index could never match CI.
# A VIEW IS NOT A CALLER (2026-10-23). This scan included `bin/README.md` — the file it
# renders — so every door gained one caller the moment the index listed it, and the next
# render counted one more. Measured: render 1 changed 97 lines, render 2 changed 26, and
# only a third render matched. A markdown page that NAMES a door does not CALL it, so no
# README.md is a caller: the register stays derived AND reproducible, and `--check` stops
# being the lottery this file warns about (`bin/gates/guards/inventory-guard.sh` proves it).
BIN_TRACKED = (
    [p for p in sorted(BIN.rglob("*"), key=lambda p: p.relative_to(ROOT).as_posix())
     if p.is_file() and p.name != "README.md" and p.relative_to(ROOT).as_posix() in tracked_set]
    if BIN.exists() else []
)


def analyse(path: Path, shelf: str):
    name = path.name
    # README.md is the inventory's OWN output: emitting its line count makes the
    # file change every generation, so --check could never pass. A dash is
    # honest ('this is the index itself') and idempotent.
    self_indexed = name in ('README.md', 'INDEX.md')
    stem = re.sub(r"\.(sh|py|bash)$", "", name)
    text = read(path)
    is_exec = tracked_modes.get(path.relative_to(ROOT).as_posix()) == b"100755"

    # callers: which other doors invoke it
    called_by = []
    # RECURSIVE: bin/ now has SYSTEM FOLDERS, and a root-only scan indexes 148 of 398 doors and
    # calls it current — the same blindness that hid four doors in the first move.
    # The index is its OWN input if it is read here: every door's name appears in `README.md`, so each
    # generation added one to every `called-by` count and `--check` could NEVER pass (measured
    # 2026-10-23: two consecutive runs differed in 48 lines — `2 → 3`, `3 → 4`). A generator that reads
    # its own output is not a generator, it is a feedback loop. Skip every index file by name.
    for other in BIN_TRACKED:
        if other == path or other.name in ("README.md", "CAPABILITIES.md", "INDEX.md"):
            continue
        if name in read(other, 200000): called_by.append(other.name)
    outside = name in CORPUS
    tested = name in TESTS

    # A NAME is not a verdict. This shelf was `if name.startswith("fm-"): provenance`,
    # which overrode every piece of evidence: 174 files were filed as inert vendored
    # reference when 162 of them are exercised by a test and 11 more are called by a door,
    # and NOT ONE was unreferenced. Evidence first, provenance last — provenance then means
    # what it says: inert, and only because nothing exercises it.
    if tested:
        verdict, disp = "tested", "keep"
    elif called_by:
        verdict, disp = "wired", "keep"
    elif name.startswith("fm-"):
        verdict = "provenance"
        disp = "provenance"
    elif tested:
        verdict, disp = "tested", "keep"
    elif outside:
        verdict, disp = "wired", "keep"
    elif called_by:
        verdict, disp = "internal", "keep"
    else:
        verdict, disp = "orphan", "retire"

    cp = counterpart(stem)
    if disp == "keep" and cp and shelf == "bin":
        disp = f"migrate → {cp}"

    kind = "provenance" if name.startswith("fm-") else (
        "lib" if "-lib" in name else "tool" if is_exec else "data")
    return dict(file=name, path=path.relative_to(ROOT).as_posix(), does=first_sentence(text), kind=kind, verdict=verdict,
                disposition=disp, callers=len(called_by),
                lines=("-" if self_indexed else text.count("\n") + 1))

def table(rows, title_cols):
    out = [f'{title_cols}[{len(rows)}]{{file,does,kind,verdict,disposition,callers,lines}}:']
    for r in sorted(rows, key=lambda x: x["file"]):
        esc = lambda s: str(s).replace('"', "'").replace("\n", " ").strip()
        out.append('  "%s","%s","%s","%s","%s",%s,%s' % (
            esc(r["file"]), esc(r["does"]), esc(r["kind"]), esc(r["verdict"]),
            esc(r["disposition"]), r["callers"], r["lines"]))
    return "\n".join(out)

def tally(rows, key):
    d = {}
    for r in rows: d[r[key]] = d.get(r[key], 0) + 1
    return ", ".join(f"{k}={v}" for k, v in sorted(d.items(), key=lambda kv: -kv[1]))

shelves = {}
# TRACKED files only, as the header above promises. This walked the filesystem
# (`rglob`), so untracked live state — bin/state/cron.log, .session-start-complete —
# was counted, its "called-by" totals moved as the machine ran, and the committed
# index could not match a clean checkout: `--check` was the lottery this file warns
# about. A generated index must be a function of the tree, not of the seat.
tracked_set = set(tracked)
for shelf, d in (("bin", BIN), (".agents/backend", BACKEND)):
    if d.exists():
        shelves[shelf] = [
            analyse(p, shelf)
            for p in sorted(d.rglob("*"), key=lambda p: p.relative_to(ROOT).as_posix())
            if p.is_file() and p.name != "INDEX.md"
            and not any(part.startswith(".") for part in p.relative_to(d).parts)
            and p.relative_to(ROOT).as_posix() in tracked_set
        ]

fail = False

# ── THE REGISTER IS A TREE, NOT A MONUMENT (plan 211, 2026-11-06) ──────────────
# Measured: every branch that added one script rewrote all 786 lines of bin/README.md at
# the same sorted position, so five of six open PRs were CONFLICTING with main at once.
# A hand that touches one folder must touch ONE file. So: a folder's doors live in
# bin/<folder>/INDEX.md, the root-level doors in bin/INDEX.md, and bin/README.md becomes a
# front door of FOLDERS ONLY — it changes when a folder appears, disappears or is renamed,
# which is rare, instead of every time a door is born.
FOLDER_PURPOSE = {}
_purpose_file = ROOT / "bin/gates/registers/folders.tsv"
if _purpose_file.exists():
    for line in _purpose_file.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) >= 2:
            FOLDER_PURPOSE[parts[0].strip()] = parts[1].strip()

HEADER = (
    "**Generated by `bin/gates/inventory.sh`. Do not hand-edit; do not commit it.** This file is\n"
    "BUILT, never versioned (plan 243 part A, 2026-11-11) — it is ignored by git and rebuilt by an\n"
    "install, an update, the session start (cached) and on demand, so no branch ever conflicts on it\n"
    "and no stale copy on main can refuse a push for drift the pusher did not cause. The ward\n"
    "judges the SOURCES (`bin/gates/inventory.sh --check`), never a committed copy.\n\n"
    "**Read the columns.** `verdict` is measured, not judged: `tested` = a test\n"
    "exercises it · `wired` = a skill, doc or gate names it · `internal` = only other\n"
    "doors call it · `orphan` = nothing outside `bin/` names it · `provenance` = a\n"
    "vendored `fm-*` script kept byte-comparable to upstream on purpose.\n"
    "`disposition` says what happens to it: `keep`, `migrate → src/…` where the\n"
    "Python runtime already has the module, `retire` for orphans, `provenance`.\n\n"
    "## CHANGE LOG\n\n"
    "Every run rewrites this file from the tree; there is no hand-kept content here.\n"
    "The tree replaced a single register on 2026-11-06 (plan 211) so that a change in one\n"
    "folder rewrites one file instead of colliding on every branch.\n"
)

WAIVER = ("<!-- allow-superseded-path: a generated index must name the folder or the script "
          "it indexes, by construction -->\n")

def folder_of(rel):
    parts = rel.split("/")
    # bin/x.sh -> "root"; bin/<folder>/... -> that folder
    if len(parts) == 2:
        return "root"
    return parts[1]

written = []
for shelf, rows in shelves.items():
    if shelf == "bin":
        groups = {}
        for r in rows:
            groups.setdefault(folder_of(r["path"]), []).append(r)

        # 1 · one fragment per folder (and one for the root-level doors)
        for key in sorted(groups):
            frag_rows = groups[key]
            rel = "bin/INDEX.md" if key == "root" else f"bin/{key}/INDEX.md"
            target = ROOT / rel
            g = [WAIVER]
            if key == "root":
                g.append("# `bin/` — the root-level doors\n")
            else:
                purpose = FOLDER_PURPOSE.get(key, "")
                g.append(f"# `bin/{key}/` — {purpose or 'the doors of this folder'}\n")
            g.append(HEADER)
            g.append(table(frag_rows, "bin"))
            g.append("")
            g.append(f"**Tally.** verdict: {tally(frag_rows,'verdict')}")
            g.append("")
            g.append(f"**Tally.** disposition: {tally(frag_rows,'disposition')}")
            body = "\n".join(g) + "\n"
            written.append((target, body, len(frag_rows)))

        # 2 · the FRONT DOOR: folders only. No per-door row ever lands here again.
        front = [WAIVER]
        front.append("# `bin/` — every file, what it does, and whether it is alive\n")
        front.append(HEADER)
        front.append("**This page is a TREE.** Each folder keeps its own index, generated in the same\n")
        front.append("run, so a change in one folder rewrites one file — the collision this file used to\n")
        front.append("cause on every branch is designed out (plan 211).\n")
        front.append("")
        # NO COUNTS ON THIS PAGE (2026-11-06). It used to print a per-folder file count, so
        # adding ONE door anywhere rewrote this file on every branch — the collision the tree
        # was meant to end. A count belongs where the rows are: each folder's own index keeps
        # its tally, and this page only lists the folders. Adding a door now touches one
        # fragment; adding a FOLDER is the only thing that touches this page.
        front.append("Counts live in each folder's own index; this page lists the folders.\n")
        front.append("")
        front.append(f"folders[{len(groups) + 1}]{{folder,what,index}}:")
        for key in sorted(groups):
            rel = "bin/INDEX.md" if key == "root" else f"bin/{key}/INDEX.md"
            purpose = "the root-level doors" if key == "root" else FOLDER_PURPOSE.get(key, "(no purpose recorded)")
            esc = lambda s: str(s).replace('"', "'")
            front.append(f'  "{key}","{esc(purpose)}","{rel}"')
        front.append('  "TOTAL","every door in the shelf","—"')
        front.append("")
        front.append("A folder with no row in `bin/gates/registers/folders.tsv` is not an error — it\n")
        front.append("renders `(no purpose recorded)`, and adding the line there is the one place the\n")
        front.append("purpose is kept.\n")
        written.append((ROOT / "bin/README.md", "\n".join(front) + "\n", len(rows)))
    else:
        target = ROOT / ".agents/backend/README.md"
        gen = []
        gen.append("# `.agents/backend/` — the backend layer, file by file\n")
        gen.append("**Generated by `bin/gates/inventory.sh`. Do not hand-edit.**\n")
        gen.append("**What this folder is.** Two things that share one job — *make work happen")
        gen.append("and report it truthfully*:\n")
        gen.append("1. **The vendored firstmate runtime** (`fm-*`) — the validated upstream Ymir")
        gen.append("   ported its dispatch from. It is the reference implementation of")
        gen.append("   spawn → send → peek → watch → teardown, and it stays byte-comparable to")
        gen.append("   upstream so a port can be checked against it. **Provenance, not Ymir's own.**")
        gen.append("2. **The model bridges** — Ymir's own files. They are why this index exists:\n")
        gen.append(table(rows, "backend"))
        gen.append("")
        gen.append(f"**Tally.** verdict: {tally(rows,'verdict')}")
        written.append((target, "\n".join(gen) + "\n", len(rows)))

# 3 · WRITE IT, or JUDGE THE SOURCE (plan 243 part A, 2026-11-11).
#
# `--check` used to diff the rendered pages against the COMMITTED copies. Those copies are
# generated files, and generated files are no longer versioned, so there is nothing to compare
# — and comparing was the disease: one stale copy on main and every push in the house was
# refused for drift the pusher did not cause.
#
# What a gate can honestly judge is the SOURCE, and it is computed from `git ls-files` — never
# from a copy — so a pull request is judged only on the tree it carries:
#   · a tracked door no index can SEE     -> an empty row, or a shelf the walk cannot reach
#   · a door with no header to DESCRIBE   -> the index cannot say what it does
#   · a row for a file git does not track -> the register would name something no clone has
if MODE != "--check":
    for target, body, count in written:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(body, encoding="utf-8", newline="\n")
    for target, _body, count in written:
        print(f"wrote {target.relative_to(ROOT)} — {count} files")
    print("outputs[1]{files,doors}:")
    print('  "%d","%d"' % (len(written), len(shelves.get("bin", []))))
    sys.exit(0)

def shelf_paths(shelf_dir):
    """Every tracked file a shelf's index must name, shelf-relative, dot-dirs excluded."""
    prefix = shelf_dir + "/"
    return {p[len(prefix):] for p in tracked
            if p.startswith(prefix)
            and not any(part.startswith(".") for part in p[len(prefix):].split("/"))
            # An INDEX.md is a SHELF'S OWN INDEX at any depth, not a door: naming it in the
            # register it belongs to is circular. Measured 2026-11-11: the vendored collab kit's
            # docs/templates/INDEX.md was the one file no row could honestly name.
            and not p.endswith("/INDEX.md") and p[len(prefix):] != "INDEX.md"}

findings = []
for shelf, shelf_dir in (("bin", "bin"), (".agents/backend", ".agents/backend")):
    rows = shelves.get(shelf, [])
    prefix = shelf_dir + "/"
    # a row's own `path` is shelf-relative for bin/ and repo-relative for the backend shelf;
    # normalise so one comparison reads one way.
    rendered = {(r["path"][len(prefix):] if r["path"].startswith(prefix) else r["path"]) for r in rows}
    expected = shelf_paths(shelf_dir)
    for p in sorted(expected - rendered):
        findings.append(("a door no index can see", f"{shelf_dir}/{p}",
                         "tracked, but the register renders no row for it (a bad checkout, a dot-directory, or an analysis that skipped it)"))
    for p in sorted(rendered - expected):
        findings.append(("a row for a file git does not track", f"{shelf_dir}/{p}",
                         "the register would name something no clone has — the row is stale from a previous tree"))
    for r in rows:
        if not str(r.get("does") or "").strip():
            findings.append(("a door with an empty header", f"{shelf_dir}/{r['path']}",
                             "the index has nothing to say about it"))

if not written:
    findings.append(("the register rendered nothing", "bin", "a generator that emits no file is not a register"))

if findings:
    print(f"inventory --check: {len(findings)} source finding(s) — this is the TREE, not a stale copy", file=sys.stderr)
    print("inventory_source[%d]{finding,path,detail}:" % len(findings), file=sys.stderr)
    for f, p, d in findings:
        print('  "%s","%s","%s"' % (f, p, d.replace('"', "'")), file=sys.stderr)
    sys.exit(1)

print(f"inventory --check: sources clean — {len(written)} index file(s) will be built from "
      f"{len(shelves.get('bin', []))} bin doors + {len(shelves.get('.agents/backend', []))} backend files")
sys.exit(0)
PY
rc=$?
[ "$MODE" = "--check" ] && exit $rc
exit 0