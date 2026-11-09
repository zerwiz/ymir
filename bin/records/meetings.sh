#!/usr/bin/env bash
# meetings.sh — one report over every meeting the house has, whatever recorded it.
#
# WHY: transcripts, minutes and promises live in per-meeting folders that nobody indexes, so
# "what came out of my calls" had no answer that was not a filesystem dig. This is the door.
#
#   meetings.sh list [--since YYYY-MM-DD]     one row per meeting: date · title · source · transcript? · minutes? · promises
#   meetings.sh show <id-or-path>             the folder, the transcript, the minutes, the promises, in words
#   meetings.sh totals [--since YYYY-MM-DD]   the four numbers he reads in a brief
#   meetings.sh json [--since YYYY-MM-DD]     the same rows, machine-readable (the one index, one shape)
#   meetings.sh brief  [--since YYYY-MM-DD]   the ONE line the 07:00 daily brief carries
#   meetings.sh plans <id-or-path>            the plans a meeting produced, by `from_meeting:` in the header
#   meetings.sh state <id-or-path>            the meeting's own pipeline state (finished, or stopped at a step)
#
# THE INDEX IS DERIVED FROM THE FOLDERS, never a second record: delete this door and nothing
# is lost. Nothing here writes a meeting; a meeting's own record is its folder, and its own
# state is the `.state` file the ladder writes beside it (plan 228 §3 · F2).
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"
HOARD="${YMIR_HOARD:-}"
if [ -z "$HOARD" ]; then
  # shellcheck disable=SC1091
  . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
  ymir_home_root _home 2>/dev/null || true
  HOARD="${_home:-${YMIR_HOME:-}}/hodd"
  # The home is RESOLVED, never guessed (Rule 07): a seat whose resolver cannot answer is told
  # so. The literal fallback that stood here named one machine's path, so a seat without the
  # hoard in that exact place read an empty shelf and called it "no meetings".
  [ -n "${_home:-${YMIR_HOME:-}}" ] || {
    printf 'error: the home is unresolved — set YMIR_HOME, or run from a checkout\n' >&2
    printf 'help: bin/vault/hoard-lib.sh must be able to answer\n' >&2
    exit 2
  }
fi
HOME_DIR="$(dirname "$HOARD")"
SINCE="1970-01-01"
CMD="${1:-list}"; shift || true
while [ $# -gt 0 ]; do case "$1" in --since) SINCE=${2-}; shift 2 ;; *) break ;; esac; done
EXTRA="${1:-}"

rows() {  # <since> — one TSV row per meeting folder, derived from the folder itself
  python3 - "$HOME_DIR" "$SINCE" "$EXTRA" <<'PY'
import datetime, json, os, re, subprocess, sys

home, since, key = sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else ""

ledgers = []
base = os.path.join(home, "svartalfaheim")
for root, dirs, files in os.walk(base):
    depth = root[len(base):].count(os.sep)
    if depth > 4:
        dirs[:] = []
        continue
    dirs[:] = [d for d in dirs if d not in (".git", "node_modules")]
    if os.path.basename(root) == "plans":
        ledgers.append(root)


def plan_rows():
    """Every plan header that names a meeting: `from_meeting: <id>` in the first 20 lines."""
    rows = []
    for ledger in ledgers:
        try:
            names = os.listdir(ledger)
        except OSError:
            continue
        for name in names:
            if not name.endswith(".md"):
                continue
            path = os.path.join(ledger, name)
            try:
                with open(path, encoding="utf-8", errors="replace") as fh:
                    head = [next(fh, "") for _ in range(20)]
            except OSError:
                continue
            for line in head:
                m = re.match(r"^\s*\**from_meeting\**\s*:\s*`?([^`\s]+)`?", line.strip())
                if m:
                    rows.append((m.group(1), name))
                    break
    return rows


PLAN_ROWS = plan_rows()


def count_section(text, wanted):
    """Count the bullets in a markdown section whose heading names <wanted>."""
    total, inside = 0, False
    for line in text.splitlines():
        if re.match(r"^#{1,6}\s", line):
            inside = any(w in line.lower() for w in wanted)
            continue
        if inside and re.match(r"^\s*[-*]\s+", line):
            # `- none in the transcript` is the ABSENCE of a thing, said out loud; a
            # count that reports it as one decision is the kind of green this house pays for.
            if re.search(r"\bnone\b|\bnothing\b", line, re.I):
                continue
            total += 1
    return total


def read(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError:
        return ""


def pick(folder, names, contains=None):
    try:
        entries = sorted(os.listdir(folder))
    except OSError:
        return ""
    for name in names:
        if name in entries:
            return os.path.join(folder, name)
    if contains:
        for name in entries:
            if name.endswith(".md") and contains in name.lower():
                return os.path.join(folder, name)
    return ""


for root, dirs, files in os.walk(home):
    dirs[:] = [d for d in dirs if d not in (".git", "node_modules", "node_modules")]
    if "meeting.json" not in files:
        continue
    path = os.path.join(root, "meeting.json")
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            d = json.load(fh)
    except Exception:
        d = {}
    when = (d.get("started_at") or d.get("start") or d.get("date") or "")[:10]
    if when and when < since:
        continue
    mid = d.get("id") or os.path.basename(root)
    if key and key not in mid and key not in root:
        continue
    transcript = pick(root, ["transcript.md", "by-house.md"], contains="transcript")
    if not transcript:
        for name in sorted(files):
            if name.endswith((".txt", ".md")) and "transcript" in name.lower():
                transcript = os.path.join(root, name)
                break
    minutes = pick(root, ["minutes.md"], contains="minutes")
    decisions = pick(root, ["decisions.md"])
    actions = pick(root, ["actions.md"], contains="action")
    mtext = read(minutes)
    n_dec = count_section(read(decisions) or mtext, ("decision",))
    if actions:
        text = read(actions)
    else:
        text = mtext
    n_prom = len(re.findall(r"^\s*[-*]\s*\[ \]", text, flags=re.M))
    if n_prom == 0 and text is not mtext:
        n_prom = count_section(mtext, ("promise", "action"))
    state = ""
    st_path = os.path.join(root, ".state")
    if os.path.isfile(st_path):
        state = read(st_path).strip().splitlines()[0] if read(st_path).strip() else ""
    if not state:
        state = str(d.get("state") or "")
    people = d.get("attendees") or d.get("participants") or []
    if isinstance(people, list):
        people = ", ".join((p.get("email") or p.get("name") or "") if isinstance(p, dict) else str(p)
                           for p in people if p)
    people = re.sub(r"\s+", " ", str(people))[:80]
    plans = [p for p in PLAN_ROWS if p[0] == mid]
    audio = ""
    for name in sorted(files):
        if name.endswith((".wav", ".m4a", ".ogg", ".mp3", ".webm")):
            audio = name
            break
    if not audio and os.path.isdir(os.path.join(root, "audio")):
        sub = sorted(os.listdir(os.path.join(root, "audio")))
        audio = sub[0] if sub else ""
    print("\t".join([
        when or "?", (str(d.get("title") or "untitled")).replace("\t", " ")[:60],
        "%s/%s" % (d.get("source") or "?", d.get("platform") or "-"),
        "yes" if transcript else "no", "yes" if minutes else "no",
        str(n_prom), str(n_dec), str(len(plans)), (",".join(p[1] for p in plans) or "-"),
        mid, root, state or "-", people or "-",
        os.path.relpath(minutes, home) if minutes else "-",
        os.path.relpath(transcript, home) if transcript else "-",
        audio or "-",
    ]))
PY
}

# The row's columns, named once.
FIELDS="when,title,source,transcript,minutes,promises,decisions,plans,plan_files,id,folder,state,people,minutes_file,transcript_file,audio"

case "$CMD" in
  list)
    printf 'meetings[16]{%s}:\n' "$FIELDS"
    n=0
    while IFS=$'\t' read -r when title src tr mn prom dec plans planfiles id folder state people minf trf audio; do
      [ -n "$when" ] || continue
      printf '  "%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' \
        "$when" "$title" "$src" "$tr" "$mn" "$prom" "$dec" "$plans" "$planfiles" "$id" "$folder" "$state" "$people" "$minf" "$trf" "$audio"
      n=$((n+1))
    done <<< "$(rows)"
    printf 'count: %s\n' "$n" ;;
  totals)
    n=0; withtr=0; withmn=0; prom=0; dec=0; stopped=0
    while IFS=$'\t' read -r when title src tr mn p d plans planfiles id folder state people minf trf audio; do
      [ -n "$when" ] || continue
      n=$((n+1)); [ "$tr" = yes ] && withtr=$((withtr+1)); [ "$mn" = yes ] && withmn=$((withmn+1))
      prom=$((prom + p)); dec=$((dec + d))
      case "$state" in stopped*) stopped=$((stopped+1)) ;; esac
    done <<< "$(rows)"
    printf 'meetings_totals[7]{meetings,with_transcript,with_minutes,promises_outstanding,decisions,stopped,since}:\n  "%s","%s","%s","%s","%s","%s","%s"\n' \
      "$n" "$withtr" "$withmn" "$prom" "$dec" "$stopped" "$SINCE" ;;
  brief)
    python3 - "$(rows)" "$SINCE" <<'PY'
import datetime, sys
rows = [l.split("\t") for l in sys.argv[1].splitlines() if l.strip()]
since = sys.argv[2]
if not rows:
    print("meetings: none on the shelf — no call has produced a record yet")
    raise SystemExit(0)
yesterday = (datetime.date.today() - datetime.timedelta(days=1)).isoformat()
today = datetime.date.today().isoformat()
recent = [r for r in rows if r[0] in (today, yesterday)]
scope = recent or rows
prom = sum(int(r[5]) for r in scope)
dec = sum(int(r[6]) for r in scope)
plans = sum(int(r[7]) for r in scope)
stopped = sum(1 for r in scope if r[11].startswith("stopped"))
where = "yesterday and today" if recent else "on the shelf"
line = "meetings: %d %s — %d decision(s), %d promise(s), %d plan(s) touched" % (
    len(scope), where, dec, prom, plans)
if stopped:
    line += " · %d stopped before the minutes" % stopped
print(line)
PY
    ;;
  json)
    python3 - "$(rows)" "$FIELDS" <<'PY'
import json, sys
keys = sys.argv[2].split(",")
out = []
for line in sys.argv[1].splitlines():
    if not line.strip():
        continue
    vals = line.split("\t")
    row = dict(zip(keys, vals))
    # `-` is the sentinel for an absent field: a bare empty field cannot ride a
    # tab-separated record through `IFS=$'\\t' read` (tab is whitespace to read, so
    # consecutive tabs collapse and every later column shifts one to the left).
    if row.get("plan_files") == "-":
        row["plan_files"] = ""
    for k in ("promises", "decisions", "plans"):
        try: row[k] = int(row.get(k) or 0)
        except ValueError: row[k] = 0
    for k in ("transcript", "minutes"):
        row[k] = row.get(k) == "yes"
    row["stopped_at"] = row["state"][len("stopped at"):].strip() if row["state"].startswith("stopped at") else ""
    row["finished"] = bool(row["minutes"]) and not row["stopped_at"]
    out.append(row)
print(json.dumps(out, ensure_ascii=False, indent=2))
PY
    ;;
  plans)
    [ -n "$EXTRA" ] || { printf 'error: plans needs a meeting id\n' >&2; exit 2; }
    found=0
    while IFS=$'\t' read -r when title src tr mn p d plans planfiles id folder state people minf trf audio; do
      [ -n "$when" ] || continue
      case "$id$folder" in *"$EXTRA"*)
        found=1
        if [ -n "$planfiles" ]; then
          printf 'plans[%s]{from_meeting,plan}:\n' "$(printf '%s\n' "$planfiles" | tr ',' '\n' | grep -c . || true)"
          # `read` never assigns an UNTERMINATED last line: without the `|| [ -n "$f" ]`
          # half the loop's one row is silently dropped and the report reads `plans[1]`
          # above nothing. (The fleet learned this once already — see learnings, 2026-11-05.)
          printf '%s\n' "$planfiles" | tr ',' '\n' | while IFS= read -r f || [ -n "$f" ]; do
            [ -n "$f" ] && printf '  "%s","%s"\n' "$id" "$f"
          done
        else
          printf 'meeting %s produced no plan yet — no plan header names it (from_meeting: %s)\n' "$id" "$id"
        fi ;;
      esac
    done <<< "$(rows)"
    [ "$found" = 1 ] || { printf 'error: no meeting matches %s\n' "$EXTRA" >&2; exit 1; } ;;
  state)
    [ -n "$EXTRA" ] || { printf 'error: state needs a meeting id\n' >&2; exit 2; }
    found=0
    while IFS=$'\t' read -r when title src tr mn p d plans planfiles id folder state people minf trf audio; do
      [ -n "$when" ] || continue
      case "$id$folder" in *"$EXTRA"*)
        found=1
        printf 'meeting_state[4]{id,state,finished,stopped_at}:\n  "%s","%s","%s","%s"\n' \
          "$id" "$state" "$([ "$mn" = yes ] && [ "${state#stopped}" = "$state" ] && echo yes || echo no)" \
          "$([ "${state#stopped at }" != "$state" ] && printf '%s' "${state#stopped at }" || echo -)" ;;
      esac
    done <<< "$(rows)"
    [ "$found" = 1 ] || { printf 'error: no meeting matches %s\n' "$EXTRA" >&2; exit 1; } ;;
  show)
    key="${EXTRA:-}"; [ -n "$key" ] || { printf 'error: show needs an id or a folder\n' >&2; exit 2; }
    while IFS=$'\t' read -r when title src tr mn p d plans planfiles id folder state people minf trf audio; do
      case "$id$folder" in *"$key"*)
        printf 'meeting:\n  id: %s\n  when: %s\n  title: %s\n  source: %s\n  folder: %s\n  transcript: %s\n  minutes: %s\n  promises: %s\n  decisions: %s\n  plans: %s\n  state: %s\n  people: %s\n' \
          "$id" "$when" "$title" "$src" "$folder" "$tr" "$mn" "$p" "$d" "${planfiles:--}" "$state" "$people"
        ls "$folder" 2>/dev/null | sed 's/^/  file: /' ;;
      esac
    done <<< "$(rows)" ;;
  *) printf 'usage: meetings.sh list|show <id>|totals|json|brief|plans <id>|state <id> [--since YYYY-MM-DD]\n' >&2; exit 2 ;;
esac
