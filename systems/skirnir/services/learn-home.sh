#!/usr/bin/env bash
# learn-home.sh — give Skírnir the SHAPE of the house: its shelves, its law, its plans.
#
#   systems/skirnir/services/learn-home.sh [--dry-run] [--no-ship]
#
# The Allfather, 2026-10-23: *"why can't I see my full ymir home in Skírnir … he's talking about
# the wrong things."* Both halves were true and both had the same cause: his book held 308 approved
# CLAIMS (95 of them feature rows) and not one fact about the home itself, so a question about the
# home could only match a feature's words — and every feature claim opens "Ymir has a feature: …",
# so "ymir" counted as the subject of all of them.
#
# This door writes the missing half: ONE fact per document the home is made of —
#
#   hodd/docs/INDEX.md            every indexed page (its own one-line description)
#   RULES/*.md                    the house law, by title
#   plans/*.md (the canonical ledger)  every plan, by number · title · status
#   hodd/bin/DOORS.md             the home's own tools, by file
#
# The facts are class `internal`, audience `owner` and `approved_by: document` — NOT the Allfather's
# signature: a document proves its own claim, and a machine must never sign for him. kb-export
# accepts that approver for `internal` only, and refuses it everywhere else.
#
# Idempotent by slug, in three ways that matter (2026-11-20):
#
#   · a fact whose TEXT is unchanged is not rewritten, even though its `approved_at` rolls over
#     each day — the stamps are stripped before the comparison, so an unchanged night is a zero
#     diff and a zero commit (measured fault: ~1,300 files rewritten nightly and never committed);
#   · a fact whose source document is gone is RETIRED BY MOVING into `approved/_retired/` (Rule 11
#     — the home-sync door refuses a deletion of a tracked path, and the law is not weakened for a
#     generated mirror), so the retirement is visible in history as a rename;
#   · a non-dry run SHIPS its own output through the one home door
#     (`bin/vault/home-sync.sh ship "<message>" hodd/identity/assistant/approved`, named path only),
#     so the home is clean by morning instead of being cleaned by hand. A no-change night stages
#     nothing and says so; a failed ship prints its reason and exits non-zero.
#
# `--dry-run` writes nothing and ships nothing. `--no-ship` writes the facts but leaves the commit
# unmade, for a hand run or a test.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The repo root, found by walking up to the tree that holds .pi and RULES — never counted in
# "../", because this shelf was moved once (bin/assistant/ -> systems/skirnir/, plan 149) and
# 25 scripts kept the old depth, so every $ROOT/bin/... pointed into systems/ instead (2026-11-02).
ROOT="$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"

DRY=0
SHIP=1
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --no-ship) SHIP=0 ;;
    -h|--help) sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'learn-home: unknown argument %s (try --help)\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

# shellcheck disable=SC1091
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root HOME_R 2>/dev/null || true
[ -n "${HOME_R:-}" ] || { printf 'learn-home: the hoard is unresolved\n' >&2; exit 2; }
SHELF="hodd/identity/assistant/approved"
DEST="$HOME_R/$SHELF"
mkdir -p "$DEST" 2>/dev/null || exit 3

# The counts the python pass reports travel back through a file, not through stdout: the summary
# is a TOON row a sharp eye reads, and parsing it back would be a second, brittle contract.
COUNTS="$(mktemp)"
trap 'rm -f "$COUNTS"' EXIT

ROOT_DIR="$ROOT" HOME_Q="$HOME_R" DEST_Q="$DEST" DRY_Q="$DRY" COUNTS_Q="$COUNTS" python3 - <<'PY'
import glob, os, re, time

root, home, dest = (os.environ[k] for k in ("ROOT_DIR", "HOME_Q", "DEST_Q"))
dry = os.environ["DRY_Q"] == "1"
counts_path = os.environ["COUNTS_Q"]
today = time.strftime("%Y-%m-%d")
# The marker is the HISTORICAL path on purpose: 1,552 copies in the home carry this exact line, and
# the retire pass finds its own copies by it. Moving the door (plan 149) is not a reason to rewrite
# the whole shelf for a path, so the marker stays stable and says only "this copy is learn-home's".
STAMP = "generated_by: bin/assistant/learn-home.sh"
# The two lines that roll over with the clock. They are compared away: same text, same fact.
STAMPS = ("generated_at:", "approved_at:")
produced: list[str] = []
written: list[str] = []
unchanged = 0
retired: list[str] = []


def clean(text: str) -> str:
    text = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"[*_`|]", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")[:90]


def without_stamps(text: str) -> str:
    """The text a fact is judged by: everything but the two lines the clock rewrites."""
    return "".join(line for line in text.splitlines(True) if not line.startswith(STAMPS))


def fact(title: str, claim: str, source: str) -> None:
    global unchanged
    claim = clean(claim)[:400]
    if len(claim) < 12:
        return
    name = slug(f"home-{title}")
    if name in produced:
        return
    produced.append(name)
    body = ("---\n"
            "approved_by: document\n"
            f"approved_at: {today}\n"
            "class: internal\naudience: owner\nverbatim: true\n"
            f"source: {source}\n{STAMP}\n"
            f"generated_at: {time.strftime('%Y-%m-%dT%H:%M:%S%z')}\n"
            "---\n"
            f"{claim}\n")
    path = os.path.join(dest, name + ".md")
    if os.path.exists(path):
        try:
            with open(path, encoding="utf-8", errors="replace") as fh:
                old = fh.read()
        except OSError:
            old = ""
        if old and without_stamps(old) == without_stamps(body):
            unchanged += 1
            return
    if dry:
        written.append(name)
        return
    with open(path, "w") as fh:
        fh.write(body)
    written.append(name)


def rel(path: str) -> str:
    """Provenance, never spoken: the home's own path if it is in the home, else the repo's."""
    if not path.startswith(home):
        return os.path.relpath(path, root)
    try:
        return os.path.relpath(path, home)
    except ValueError:
        return os.path.basename(path)


# ── the home's documents: ONE fact per document, from its own heading ─────────────────────────
# Not from INDEX.md's prose. The first attempt parsed that page with a regex and produced facts
# like "The Allfather's home holds Last updated — 2026-09-20" — noise that would make him talk
# about the wrong things while looking thorough. A document proves its own title; that is all a
# shelf fact needs, and it cannot rot the way a hand-written index line does.
def doc_fact(path: str) -> None:
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            head_text = fh.read(4000)
    except OSError:
        return
    title, status = "", ""
    for line in head_text.splitlines():
        if not title and line.startswith("# "):
            title = line[2:].strip()
        m = re.search(r"\*\*Status:\*\*\s*([a-z][a-z ,-]{2,40})", line, re.I)
        if m and not status:
            status = m.group(1).strip().rstrip(".")
        if title and status:
            break
    if not title or len(title) < 4:
        return
    title = re.sub(r"^plan\s+\d+\s*[—–:-]\s*", "", title, flags=re.I)
    fact(f"doc {rel(path)}", f"{clean(title)}" + (f" — status {status}" if status else "") + ".",
         rel(path))


docs = []
for base in (os.path.join(home, "hodd"),):
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = [d for d in dirnames if d not in ("node_modules", ".git", "__pycache__")]
        for name in filenames:
            if name.endswith(".md") and name != "INDEX.md":
                docs.append(os.path.join(dirpath, name))
# NO CAP (2026-11-19). This loop used to read `sorted(docs)[:400]`, and the retire pass below
# deletes every copy whose document this pass did not produce — so the 401st document onward was
# deleted from the home on every run, silently. Measured: 74 restored copies of living documents
# (all under hodd/docs/, sorted late) were deleted that way. Every document is produced now.
for path in sorted(docs):
    doc_fact(path)

# ── the house law, by title ───────────────────────────────────────────────────────────────────
for path in sorted(glob.glob(os.path.join(root, "RULES", "[0-9]*.md"))):
    title = ""
    for line in open(path, encoding="utf-8", errors="replace"):
        if line.startswith("# "):
            title = line[2:].strip()
            break
    if title:
        fact(f"rule {os.path.basename(path)[:2]}", f"House law: {title}.", rel(path))

# ── the plan ledger: number · title · status ────────────────────────────────────────────────
plans = glob.glob(os.path.join(home, "svartalfaheim", "*", "projects", "*", "plans", "[0-9]*.md"))
plans += glob.glob(os.path.join(home, "svartalfaheim", "*", "workspace", "*", "plans", "[0-9]*.md"))
for path in sorted(plans):
    head_text = open(path, encoding="utf-8", errors="replace").read(2500)
    title = ""
    for line in head_text.splitlines():
        if line.startswith("# "):
            title = line[2:].strip()
            break
    status = ""
    m = re.search(r"\*\*Status:\*\*\s*([a-z][a-z -]{2,30})", head_text, re.I)
    if m:
        status = m.group(1).strip().lower()
    number = re.match(r"(\d+)", os.path.basename(path))
    if title and number:
        spoken = re.sub(r"^plan\s+\d+\s*[—–:-]\s*", "", title, flags=re.I)
        fact(f"plan {number.group(1)}",
             f"Plan {number.group(1)}: {spoken}" + (f" — status {status}" if status else "") + ".",
             rel(path))

# ── the home's own tools ────────────────────────────────────────────────────────────────────
doors = os.path.join(home, "hodd", "bin", "DOORS.md")
if os.path.exists(doors):
    for line in open(doors, encoding="utf-8"):
        m = re.match(r'^\s*"([^"]+)","([^"]+)"', line.strip())
        if m:
            fact(f"tool {m.group(1)}", f"The home's own tool {m.group(1)}: {m.group(2)}.",
                 rel(doors))

# ── a shelf fact per top-level home folder, so "what is in my home" has an answer ────────────
hodd = os.path.join(home, "hodd")
shelves = sorted(d for d in os.listdir(hodd) if os.path.isdir(os.path.join(hodd, d))
                 and not d.startswith(".")) if os.path.isdir(hodd) else []
if shelves:
    fact("the home",
         "The Allfather's home (YMIR_HOME) holds these shelves under hodd/: " + ", ".join(shelves) + ".",
         "hodd/")

# ── retire facts this pass no longer produces (the same discipline learn-house uses) ─────────
# RETIRED BY MOVING (2026-11-20). This pass used to `os.remove` the copy, and then the home-sync
# door would not ship it: `home-sync.sh ship` refuses a staged deletion of a tracked path (Rule 11),
# measured — while a directory path let the deletion through, which is a bypass, not a law. So a
# retired copy MOVES inside the generated shelf, into `approved/_retired/`, and git records a
# rename: the fact stops answering (kb-export reads only the top level) and the record survives.
# `_retired/` is never read back by this pass, so a copy retires once.
retire_dir = os.path.join(dest, "_retired")
for path in sorted(glob.glob(os.path.join(dest, "home-*.md"))):
    name = os.path.basename(path)[:-3]
    if name in produced:
        continue
    body = open(path, encoding="utf-8", errors="replace").read()
    if STAMP not in body:
        continue
    # A COPY DIES ONLY WHEN ITS SOURCE DOES (2026-11-19). Each copy carries `source:` in its front
    # matter; if that document still exists in the home, the copy is a live document's copy and is
    # never removed — so no future cap, filter or crash can drop the home's own record again.
    m = re.search(r"^source:\s*(\S+)\s*$", body, re.M)
    if m and os.path.exists(os.path.join(home, m.group(1))):
        continue
    retired.append(name)
    if dry:
        continue
    os.makedirs(retire_dir, exist_ok=True)
    target = os.path.join(retire_dir, name + ".md")
    if os.path.exists(target):
        # An older retirement already holds this name. Never overwrite a record: keep both.
        target = os.path.join(retire_dir, f"{name}-{int(time.time())}.md")
    os.replace(path, target)

with open(counts_path, "w") as fh:
    fh.write(f"written={len(written)}\nunchanged={unchanged}\nretired={len(retired)}\n")

print(f'learn-home{{written,unchanged,retired,dest,dry}}:"{len(written)}","{unchanged}",'
      f'"{len(retired)}","{dest}","{int(dry)}"')
if dry or len(written) <= 20:
    for name in written:
        print(f'  wrote "{name}"')
for name in retired:
    print(f'  retired "{name}"')
PY
rc=$?
[ "$rc" = 0 ] || { printf 'learn-home: the fact pass failed (rc=%s)\n' "$rc" >&2; exit "$rc"; }

WRITTEN=0; UNCHANGED=0; RETIRED=0
if [ -r "$COUNTS" ]; then
  WRITTEN="$(sed -n 's/^written=//p' "$COUNTS")"
  UNCHANGED="$(sed -n 's/^unchanged=//p' "$COUNTS")"
  RETIRED="$(sed -n 's/^retired=//p' "$COUNTS")"
fi
: "${WRITTEN:=0}" "${UNCHANGED:=0}" "${RETIRED:=0}"

# ── ship, or say plainly why not ─────────────────────────────────────────────────────────────
if [ "$DRY" = 1 ]; then
  printf 'learn-home{ship,status}:"skipped","dry-run"\n'
  exit 0
fi
if [ "$SHIP" = 0 ]; then
  printf 'learn-home{ship,status}:"skipped","--no-ship"\n'
  exit 0
fi

# The tree, not the counters, is what decides: a night that wrote nothing still ships the work a
# previous run left uncommitted, and a night that wrote facts identical to what the home already
# holds commits nothing at all.
git -C "$HOME_R" rev-parse --git-dir >/dev/null 2>&1 || {
  printf 'learn-home: %s is not a git repository, so nothing can be shipped\n' "$HOME_R" >&2
  exit 5
}
dirty="$(git -C "$HOME_R" status --porcelain -- "$SHELF" 2>/dev/null | wc -l | tr -d ' ')"
if [ -z "$dirty" ] || [ "$dirty" = 0 ]; then
  printf 'learn-home{ship,status,written,unchanged,retired}:"skipped","no-change",%s,%s,%s\n' \
    "$WRITTEN" "$UNCHANGED" "$RETIRED"
  exit 0
fi
msg="skirnir: the home map, regenerated ($WRITTEN written, $RETIRED retired)"
if ! bash "$ROOT/bin/vault/home-sync.sh" ship "$msg" "$SHELF"; then
  printf 'learn-home{ship,status,reason}:"failed","the home did not ship $SHELF — see home-sync above"\n' >&2
  exit 4
fi
printf 'learn-home{ship,status,path,written,retired}:"shipped","%s",%s,%s\n' \
  "$SHELF" "$WRITTEN" "$RETIRED"