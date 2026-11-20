#!/usr/bin/env bash
# snotra-ingest.sh — ingest transcripts from external sources into the meeting pipeline.
#
#   snotra-ingest.sh list    <source> [--since YYYY-MM-DD] [--until YYYY-MM-DD]
#   snotra-ingest.sh fetch   <source> <meeting-id> [--outdir <dir>]
#   snotra-ingest.sh sources  # list available sources
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd)"
ACTION="${1:-sources}"
SOURCE="${2:-}"
shift 2 2>/dev/null || true

case "$ACTION" in
  sources)
    echo "Available transcript sources:"
    echo "  knit      — Unified API (Gong, Chorus, Fireflies, Fathom, Meet, Teams)"
    echo "  read-ai   — Read AI REST API"
    echo "  fathom    — Fathom REST API"
    echo "  zoom      — Zoom Cloud Recording API"
    echo "  teams     — Microsoft Teams (Graph API)"
    echo "  meet      — Google Meet (Workspace API)"
    echo "  gong      — Gong REST API"
    echo "  otter     — Otter.ai REST API"
    ;;
  list)
    [ -n "$SOURCE" ] || { echo "usage: snotra-ingest.sh list <source> [--since YYYY-MM-DD] [--until YYYY-MM-DD]" >&2; exit 2; }
    python3 - "$ROOT" "$SOURCE" "$@" <<'PY'
import sys, json
from pathlib import Path
root, source = sys.argv[1], sys.argv[2]
sys.path.insert(0, f"{root}/bin/time/snotra")
from transcript_ingest import source_for
since = until = None
args = sys.argv[3:]
i = 0
while i < len(args):
    if args[i] == "--since" and i+1 < len(args):
        since = args[i+1]; i += 2; continue
    if args[i] == "--until" and i+1 < len(args):
        until = args[i+1]; i += 2; continue
    i += 1
src = source_for(source)
meetings = src.list_meetings(since=since, until=until)
for m in meetings:
    print(f"{m['id']}\t{m.get('started_at','')}\t{m.get('title','')}\t{m.get('source','')}")
PY
    ;;
  fetch)
    MEETING_ID="${1:-}"
    [ -n "$SOURCE" ] && [ -n "$MEETING_ID" ] || { echo "usage: snotra-ingest.sh fetch <source> <meeting-id> [--outdir <dir>]" >&2; exit 2; }
    shift 1
    OUTDIR="${2:-.}"
    python3 - "$ROOT" "$SOURCE" "$MEETING_ID" "$OUTDIR" <<'PY'
import sys, json
from pathlib import Path
root, source, mid, outdir = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
sys.path.insert(0, f"{root}/bin/time/snotra")
from transcript_ingest import source_for
src = source_for(source)
transcript = src.get_transcript(mid)
out = Path(outdir)
out.mkdir(parents=True, exist_ok=True)
outfile = out / f"{source}-{mid}.json"
outfile.write_text(json.dumps(transcript, indent=2, ensure_ascii=False), encoding="utf-8")
print(f"fetched\t{outfile}")
PY
    ;;
  *) echo "usage: snotra-ingest.sh sources|list|fetch" >&2; exit 2 ;;
esac