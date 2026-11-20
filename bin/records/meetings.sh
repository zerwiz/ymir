#!/usr/bin/env bash
# meetings.sh — one report over every meeting the house has, whatever recorded it.
#
# WHY: transcripts, minutes and promises live in per-meeting folders that nobody indexes, so
# "what came out of my calls" had no answer that was not a filesystem dig. This is the door.
#
#   meetings.sh list [--since YYYY-MM-DD]     one row per meeting: date · title · source · transcript? · minutes? · promises
#   meetings.sh show <id-or-path>             the folder, the transcript, the minutes, the promises, in words
#   meetings.sh totals [--since YYYY-MM-DD]   the four numbers he reads in a brief
#
# The index is DERIVED from the folders, never a second record: delete this door and nothing is lost.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"
HOARD="${YMIR_HOARD:-}"
[ -n "$HOARD" ] || { . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null; HOARD="${YMIR_HOARD:-$HOME/Documents/ymirhome/hodd}"; }
SINCE="1970-01-01"
CMD="${1:-list}"; shift || true
while [ $# -gt 0 ]; do case "$1" in --since) SINCE=${2-}; shift 2 ;; *) shift ;; esac; done

rows() {
  find "${YMIR_HOME_ROOT:-$(dirname "$HOARD")}" -name meeting.json -not -path "*/node_modules/*" 2>/dev/null | while IFS= read -r f; do
    python3 - "$f" "$SINCE" <<'PY'
import json, os, sys
path, since = sys.argv[1], sys.argv[2]
try: d = json.load(open(path))
except Exception: sys.exit(0)
when = (d.get("started_at") or d.get("start") or d.get("date") or "")[:10]
if when and when < since: sys.exit(0)
folder = os.path.dirname(path)
tr = os.path.exists(os.path.join(folder, "transcript.md")) or os.path.exists(os.path.join(folder, "by-house.md"))
mn = any(n.startswith("minutes") or n.startswith("minut") for n in os.listdir(folder)) if os.path.isdir(folder) else False
prom = 0
for name in os.listdir(folder):
    if name.endswith(".md"):
        try: prom += open(os.path.join(folder, name), encoding="utf-8", errors="replace").read().lower().count("- [ ]")
        except OSError: pass
people = d.get("attendees") or d.get("participants") or []
if isinstance(people, list):
    people = ", ".join((p.get("email") or p.get("name") or "") if isinstance(p, dict) else str(p) for p in people)[:60]
print("\t".join([when or "?", (d.get("title") or "untitled")[:48], (d.get("source") or "?") + "/" + (d.get("platform") or "-"),
                 "yes" if tr else "no", "yes" if mn else "no", str(prom), folder]))
PY
  done | sort -r
}

case "$CMD" in
  list)
    printf 'meetings[6]{date,title,source,transcript,minutes,promises}:\n'
    n=0
    while IFS=$'\t' read -r when title src tr mn prom folder; do
      [ -n "$when" ] || continue
      printf '  "%s","%s","%s","%s","%s","%s"\n' "$when" "$title" "$src" "$tr" "$mn" "$prom"; n=$((n+1))
    done <<< "$(rows)"
    printf 'count: %s\n' "$n" ;;
  totals)
    n=0; withtr=0; withmn=0; prom=0
    while IFS=$'\t' read -r when title src tr mn p folder; do
      [ -n "$when" ] || continue
      n=$((n+1)); [ "$tr" = yes ] && withtr=$((withtr+1)); [ "$mn" = yes ] && withmn=$((withmn+1)); prom=$((prom + p))
    done <<< "$(rows)"
    printf 'meetings_totals[5]{meetings,with_transcript,with_minutes,promises_outstanding,since}:\n  "%s","%s","%s","%s","%s"\n' "$n" "$withtr" "$withmn" "$prom" "$SINCE" ;;
  show)
    key="${1:-}"; [ -n "$key" ] || { printf 'error: show needs an id or a folder\n' >&2; exit 2; }
    while IFS=$'\t' read -r when title src tr mn p folder; do
      case "$folder" in *"$key"*) printf 'meeting:\n  when: %s\n  title: %s\n  source: %s\n  folder: %s\n  transcript: %s\n  minutes: %s\n  promises: %s\n' "$when" "$title" "$src" "$folder" "$tr" "$mn" "$p"; ls "$folder" | sed 's/^/  file: /' ;; esac
    done <<< "$(rows)" ;;
  *) printf 'usage: meetings.sh list|show <id>|totals [--since YYYY-MM-DD]\n' >&2; exit 2 ;;
esac
