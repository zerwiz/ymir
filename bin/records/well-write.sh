#!/usr/bin/env bash
# well-write.sh — the road writes the well, and a write is never lost (plan 350, part E; RULES/20).
#
# The well was written when an agent remembered to. This door is what the ROAD calls at the moments
# plan 350 names — an errand's end, a judge's verdict, a merge, a fix note — so the episode is written
# whether or not anybody remembered. A write the well does not take NOW is appended to a queue and
# retried; it is never dropped, and the queue only grows (a retried line is marked done by a second,
# append-only file, never by rewriting the first).
#
#   well-write.sh observe "<text>" [--store episodic|semantic|procedural] [--tags a,b] [--task T]
#                 [--source S] [--shape behaviour|commitment|decision] [--key K]
#                                         write one episode now, or queue it (exit 0 either way;
#                                         `--key` makes a write idempotent: a key already written is skipped)
#   well-write.sh merged <n> [--repo owner/name]
#                                         one episode for a merged PR, and one procedural episode per
#                                         fix note it adds under docs/fixes/ (the cause and the fix)
#   well-write.sh flush                   retry every queued write; prints how many landed
#   well-write.sh pending                 how many writes wait in the queue
#
# Env: WELL_WRITE_DOOR (default bin/records/mimir.sh) · WELL_WRITE_STATE (default <state>/well-write).
# Exit: 0 written or queued · 1 neither (the state cannot be written) · 2 usage.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
case "${1:-}" in -h|--help|'') sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
if [ -z "${WELL_WRITE_STATE:-}" ]; then
  _ov="${BROKK_STATE_OVERRIDE:-}"
  [ -n "$_ov" ] && [ "$_ov" = "${BROKK_MACHINE_STATE_DIR:-}" ] && _ov=""
  _st="${_ov:-${YMIR_STATE_DIR:-}}"
  if [ -z "$_st" ]; then
    # shellcheck disable=SC1091
    . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null && hoard_state_dir _st 2>/dev/null
  fi
  [ -n "${_st:-}" ] || { printf 'well-write: the state dir did not resolve\n' >&2; exit 1; }
  WELL_WRITE_STATE="$_st/well-write"
fi
export WELL_WRITE_STATE
export WELL_WRITE_DOOR="${WELL_WRITE_DOOR:-$ROOT/bin/records/mimir.sh}"
exec python3 - "$@" <<'PY'
import fcntl, hashlib, json, os, re, subprocess, sys, time
from pathlib import Path

STATE = Path(os.environ["WELL_WRITE_STATE"])
QUEUE, DONE, KEYS = STATE / "queue.jsonl", STATE / "done.jsonl", STATE / "keys.jsonl"
DOOR = os.environ["WELL_WRITE_DOOR"]


def append(path: Path, obj: dict) -> None:
    STATE.mkdir(parents=True, exist_ok=True)
    with open(path, "a", encoding="utf-8") as fh:
        fcntl.flock(fh, fcntl.LOCK_EX)
        fh.write(json.dumps(obj, ensure_ascii=False) + "\n")


def lines(path: Path) -> list[dict]:
    out = []
    if path.exists():
        for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
            try:
                out.append(json.loads(raw))
            except ValueError:
                pass
    return out


def write(entry: dict) -> bool:
    argv = [DOOR, "observe", entry["text"]]
    for flag in ("store", "tags", "task", "source", "shape"):
        if entry.get(flag):
            argv += ["--" + flag, entry[flag]]
    argv.append("--force")
    try:
        done = subprocess.run(argv, capture_output=True, text=True, timeout=30, stdin=subprocess.DEVNULL)
        return done.returncode == 0
    except Exception:
        return False


def observe(entry: dict) -> str:
    key = entry.get("key", "")
    if key and any(k.get("key") == key for k in lines(KEYS)):
        return "skipped (already written)"
    entry.setdefault("id", hashlib.sha1((entry["text"] + str(time.time())).encode()).hexdigest()[:12])
    entry.setdefault("ts", int(time.time()))
    if key:
        append(KEYS, {"key": key, "id": entry["id"], "ts": entry["ts"]})
    if write(entry):
        return "written"
    append(QUEUE, entry)
    return "queued"


def parse(args: list[str]) -> dict:
    entry, text, i = {"store": "episodic"}, [], 0
    while i < len(args):
        a = args[i]
        if a.startswith("--") and i + 1 < len(args):
            entry[a[2:]] = args[i + 1]
            i += 2
            continue
        text.append(a)
        i += 1
    entry["text"] = " ".join(" ".join(text).split())
    return entry


def gh(*args: str) -> str:
    try:
        return subprocess.run(["gh", *args], capture_output=True, text=True, timeout=60).stdout
    except Exception:
        return ""


def fix_lesson(md: str) -> str:
    title = next((l.lstrip("# ").strip() for l in md.splitlines() if l.startswith("# ")), "")
    m = re.search(r"^##\s+What was wrong\s*\n+(.+?)(\n##|\Z)", md, re.S | re.M)
    wrong = " ".join((m.group(1) if m else "").split())[:500]
    m = re.search(r"^##\s+What was built\s*\n+(.+?)(\n##|\Z)", md, re.S | re.M)
    built = " ".join((m.group(1) if m else "").split())[:400]
    return f"Fix: {title}. Cause: {wrong} The fix: {built}".strip()


def merged(args: list[str]) -> int:
    if not args:
        print("well-write: merged needs a PR number", file=sys.stderr)
        return 2
    n, repo = args[0], ""
    if "--repo" in args:
        repo = args[args.index("--repo") + 1]
    rr = ["-R", repo] if repo else []
    try:
        pr = json.loads(gh("pr", "view", n, *rr, "--json", "title,mergeCommit,files,headRepository,url") or "{}")
    except ValueError:
        pr = {}
    title = pr.get("title") or f"PR #{n}"
    url = pr.get("url") or f"#{n}"
    sha = ((pr.get("mergeCommit") or {}).get("oid")) or ""
    print(f"merge: {observe({'text': f'Merged {url}: {title}', 'store': 'episodic', 'tags': 'merge,pr', 'source': 'merge-door', 'key': f'merge:{url}'})}")
    slug = repo or (url.split("github.com/")[1].rsplit("/pull/", 1)[0] if "github.com/" in url else "")
    for f in pr.get("files") or []:
        path = f.get("path", "")
        if not (path.startswith("docs/fixes/") and path.endswith(".md")) or f.get("deletions", 0) and not f.get("additions"):
            continue
        md = ""
        if slug and sha:
            md = gh("api", "-H", "Accept: application/vnd.github.raw", f"repos/{slug}/contents/{path}?ref={sha}")
        if not md:
            continue
        print(f"fix-note {path}: {observe({'text': fix_lesson(md), 'store': 'procedural', 'tags': 'fix-note', 'source': 'merge-door', 'task': path, 'key': f'fix:{slug}:{path}'})}")
    return 0


def flush() -> int:
    done = {d.get("id") for d in lines(DONE)}
    landed = left = 0
    for e in lines(QUEUE):
        if e.get("id") in done:
            continue
        if write(e):
            append(DONE, {"id": e["id"], "ts": int(time.time())})
            done.add(e["id"])
            landed += 1
        else:
            left += 1
    print(f"well-write-flush[1]{{landed,left}}:\n  {landed},{left}")
    return 0


def pending() -> int:
    done = {d.get("id") for d in lines(DONE)}
    n = sum(1 for e in lines(QUEUE) if e.get("id") not in done)
    print(f"well-write-pending[1]{{queued}}:\n  {n}")
    return 0


verb, rest = sys.argv[1], sys.argv[2:]
if verb == "observe":
    e = parse(rest)
    if not e["text"]:
        print("well-write: observe needs a text", file=sys.stderr)
        sys.exit(2)
    print(f"well-write: {observe(e)}")
    sys.exit(0)
if verb == "merged":
    sys.exit(merged(rest))
if verb == "flush":
    sys.exit(flush())
if verb == "pending":
    sys.exit(pending())
print(f"well-write: unknown verb {verb}", file=sys.stderr)
sys.exit(2)
PY
