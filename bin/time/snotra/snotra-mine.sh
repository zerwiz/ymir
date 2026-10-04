#!/usr/bin/env bash
# snotra-mine.sh — mine decisions and action items out of a transcript.
#
# A transcript is a wall of talk. What a meeting is FOR is two short lists: what
# was decided, and who owes what next. This reads a transcript and writes those
# lists beside it, every line carrying its own verbatim quote (and its timestamp
# when the transcript has one) so the Allfather can jump straight to the moment.
#
# The mining is MECHANICAL and says so: commitment cues are matched, then the
# quote is reproduced from the transcript, never paraphrased and never invented.
# There is no speaker diarization — whisper does not tell us who spoke — so
# owners are left unnamed and the honest limit is written into the header.
#
# Usage:
#   snotra-mine.sh <transcript> <out-actions.md> [minutes-file]
#   snotra-mine.sh --version
#
# Env:
#   SNOTRA_MINE_MAX_DECISIONS  cap on decisions (default 25)
#   SNOTRA_MINE_MAX_ACTIONS    cap on action items (default 40)
#   SNOTRA_MINE_MAX_QUOTE      longest quote kept, chars (default 240)
#   SNOTRA_MINE_EXCLUDE_RE     sentences that are never a commitment, however
#                              they are phrased (default: the openers — greetings
#                              and "let's get started" — which a bare cue would
#                              otherwise mine as work)
#
# Exit: 0 mined (a file is always written, even when empty), 1 usage/IO error.
set -u

VERSION="1.0.0"
case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

[ $# -ge 2 ] || { printf 'error: need <transcript> <out-actions.md> [minutes-file]\nhelp: bin/snotra-mine.sh <transcript> <out> [minutes]\n' >&2; exit 1; }
TRANSCRIPT="$1"
OUT="$2"
MINUTES="${3:-}"
MAX_DECISIONS="${SNOTRA_MINE_MAX_DECISIONS:-25}"
MAX_ACTIONS="${SNOTRA_MINE_MAX_ACTIONS:-40}"
MAX_QUOTE="${SNOTRA_MINE_MAX_QUOTE:-240}"
# A greeting or a kick-off is not an action item. Without this, the bare "let's"
# cue mines "Good morning, let's get started" as work nobody owes.
EXCLUDE_RE="${SNOTRA_MINE_EXCLUDE_RE:-^\s*(good (morning|afternoon|evening)|hi|hello|hey|okay|ok)\b|let(\x27| u)s (get started|begin|start|kick off|jump in)\b}"

[ -r "$TRANSCRIPT" ] || { printf 'error: transcript not readable: %s\n' "$TRANSCRIPT" >&2; exit 1; }
OUT_DIR="$(dirname "$OUT")"
mkdir -p "$OUT_DIR" 2>/dev/null || true

# The cue vocabularies. Deliberately small and literal: a cue that matches
# nothing is better than a cue that invents a commitment. Overridable so a home
# can tune its own room's idiom without forking the script.
DECISION_RE="${SNOTRA_DECISION_RE:-(we|I) (decided|agreed|confirmed|approved|settled)|the decision is|decision: |we(\x27| a)re going with|we will go with|let(\x27| u)s go with|final answer|it(\x27| i)s decided|sign(ed)? off on}"
ACTION_RE="${SNOTRA_ACTION_RE:-(I|we)(\x27| w)ill |(I|we) will |we need to |I need to |need(s)? to |let(\x27| u)s |follow(ing)? up|I(\x27| w)ill send|send (you|him|her|them|the)|share the|schedule (a|the)|set up a|make sure|can you |could you |please |you should |action item|to-?do|by (monday|tuesday|wednesday|thursday|friday|saturday|sunday|next week|end of)}"

python3 - "$TRANSCRIPT" "$OUT" "$MINUTES" "$MAX_DECISIONS" "$MAX_ACTIONS" "$MAX_QUOTE" "$DECISION_RE" "$ACTION_RE" "$EXCLUDE_RE" <<'PY'
import os
import re
import sys

(transcript, out, minutes, max_dec, max_act, max_quote, dec_re, act_re, exc_re) = sys.argv[1:10]
max_dec, max_act, max_quote = int(max_dec), int(max_act), int(max_quote)

# ONE reader for both timestamped shapes: whisper.cpp's plain-text line
#   [00:00:01.000 --> 00:00:04.000]   the words
# and an SRT block (a bare index line, then `00:00:01,000 --> 00:00:04,000`,
# then the words on the lines below). Either way the words that follow a stamp
# belong to it, and a bare index line is not talk.
TS_ANY = re.compile(
    r"^\s*(?:\[(\d{2}:\d{2}:\d{2})(?:[.,]\d+)?\s*-->[^\]]*\]"
    r"|(\d{2}:\d{2}:\d{2}),\d{3}\s*-->\s*\d{2}:\d{2}:\d{2},\d{3}\s*)\s*(.*)$")
with open(transcript, encoding="utf-8", errors="replace") as fh:
    raw = fh.read()

segments = []
cur_ts, cur_buf = None, []
for line in raw.splitlines():
    m = TS_ANY.match(line)
    if m:
        if cur_ts is not None or cur_buf:
            segments.append((cur_ts or "", " ".join(cur_buf).strip()))
        cur_ts = m.group(1) or m.group(2)
        cur_buf = [m.group(3)] if m.group(3).strip() else []
        continue
    s = line.strip()
    if not s or s.isdigit():
        continue
    cur_buf.append(s)
if cur_ts is not None or cur_buf:
    segments.append((cur_ts or "", " ".join(cur_buf).strip()))
segments = [(ts, text) for ts, text in segments if text]
if not segments:
    segments = [("", raw.strip())]

# Split each segment into sentences so a long whisper paragraph yields clean cues.
sentences = []
for ts, text in segments:
    parts = re.split(r"(?<=[.!?])\s+", text)
    for p in parts:
        p = p.strip()
        if p:
            sentences.append((ts, p))

DEC = re.compile(dec_re, re.IGNORECASE)
ACT = re.compile(act_re, re.IGNORECASE)
EXCLUDE = re.compile(exc_re, re.IGNORECASE) if exc_re else None

def quote(text):
    text = re.sub(r"\s+", " ", text).strip()
    if len(text) > max_quote:
        text = text[:max_quote].rstrip() + " …"
    return text

def mine(pattern, cap):
    seen = set()
    out_rows = []
    for ts, text in sentences:
        if EXCLUDE is not None and EXCLUDE.search(text):
            continue
        if not pattern.search(text):
            continue
        key = text.lower()[:120]
        if key in seen:
            continue
        seen.add(key)
        out_rows.append((ts, quote(text)))
        if len(out_rows) >= cap:
            break
    return out_rows

decisions = mine(DEC, max_dec)
actions = mine(ACT, max_act)

date = __import__("datetime").date.today().isoformat()
lines = []
lines.append("# Mined from the meeting — decisions and actions")
lines.append("")
if minutes:
    lines.append("**Source minutes:** `%s`" % os.path.basename(minutes))
lines.append("**Source transcript:** `%s`" % os.path.basename(transcript))
lines.append("**Mined:** %s by Snotra's miner, mechanically (commitment cues + verbatim quotes)." % date)
lines.append("**Trust:** every quote below is reproduced verbatim from the transcript. The transcript is")
lines.append("machine speech-to-text, so wording may be imperfect; where a line is ambiguous it is kept")
lines.append("as it was said, never repaired. There is no speaker diarization — owners are NOT known, so")
lines.append("no owner is assigned. Nothing here is invented.")
lines.append("")
lines.append("---")
lines.append("")
lines.append("## Decisions (%d)" % len(decisions))
lines.append("")
if decisions:
    for ts, text in decisions:
        prefix = "`@%s` " % ts if ts else ""
        lines.append("- %s%s" % (prefix, text))
else:
    lines.append("_(no decision cues matched)_")
lines.append("")
lines.append("## Action Items (%d)" % len(actions))
lines.append("")
if actions:
    for ts, text in actions:
        prefix = "`@%s` " % ts if ts else ""
        lines.append("- %s%s" % (prefix, text))
else:
    lines.append("_(no action cues matched)_")
lines.append("")
lines.append("---")
lines.append("*Mined by Snotra — the meeting ear*")
lines.append("")

tmp = out + ".tmp"
with open(tmp, "w", encoding="utf-8") as fh:
    fh.write("\n".join(lines))
os.replace(tmp, out)
print("snotra-mine: %d decisions, %d actions -> %s" % (len(decisions), len(actions), out))
PY
