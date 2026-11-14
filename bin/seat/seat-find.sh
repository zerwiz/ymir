#!/usr/bin/env bash
# seat-find.sh — find the agent by its WORK, not by its tab title.
#
#   bin/seat/seat-find.sh "<words>" [--lines N] [--any] [--all] [--exclude <pane>]
#
# WHY (plan 293 part 6). On 2026-11-14 the helm briefed the wrong worker because its tab said
# the right thing; the operator had to stop it, and the runbook gained a paragraph
# ("find the right agent by its work, not its label"). A tab title is what someone typed when
# the pane was opened; the screen is what the agent actually knows. So this door reads every
# live agent pane's recent output and names the panes that printed the words.
#
#   * every word must appear (AND) — `--any` asks for any of them;
#   * case is ignored, and a word is matched LITERALLY (a hook, not a regex);
#   * the caller's OWN pane is skipped, because the words it searches for are usually in its
#     own scrollback (the runbook's measured case: the operator had just pasted them there).
#     `--all` includes it, `--exclude <pane>` skips one more;
#   * a pane that cannot be read is counted and named in the help line, never dropped quietly.
#
# Report (TOON, one row per matching pane, newest match first within a pane):
#   seat-find[2]{pane,agent,status,match,line,title}:
#     "<pane>","pi","working","quillfern ledger","…the quillfern ledger was signed…","<title>"
#
# Exit: 0 at least one pane printed the words · 1 none did · 2 usage · 3 herdr cannot answer.
set -u
SELF="$(basename "$0")"
have() { command -v "$1" >/dev/null 2>&1; }
have herdr || { printf '%s: herdr not on PATH\n' "$SELF" >&2; exit 3; }

WORDS=""; LINES="${SEAT_FIND_LINES:-400}"; MODE=all_words; INCLUDE_SELF=0; EXCLUDE=""
POS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --lines)   LINES="${2-}"; shift 2 ;;
    --any)     MODE=any_word; shift ;;
    --all)     INCLUDE_SELF=1; shift ;;
    --exclude) EXCLUDE="${2-}"; shift 2 ;;
    -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
    --) shift; POS+=("$@"); break ;;
    *) POS+=("$1"); shift ;;
  esac
done
QUERY="${POS[*]:-}"
[ -n "$QUERY" ] || { printf '%s: usage: %s "<words>" [--lines N] [--any] [--all]\n' "$SELF" "$SELF" >&2; exit 2; }

# The caller's own pane. HERDR_PANE_ID is what a pane exports; `herdr pane current` answers a
# shell that does not carry it (a cron row, a test). Both are probed, never assumed.
OWN="${HERDR_PANE_ID:-}"
if [ -z "$OWN" ]; then
  OWN="$(timeout 8 herdr pane current 2>/dev/null | python3 -c 'import json,sys
try: print(((json.load(sys.stdin).get("result") or {}).get("pane") or {}).get("pane_id") or "")
except Exception: print("")' 2>/dev/null)"
fi
[ "$INCLUDE_SELF" = 1 ] && OWN=""

PANE_LIST="$(timeout 15 herdr pane list 2>/dev/null)" || { printf '%s: herdr did not answer\n' "$SELF" >&2; exit 3; }

PANE_LIST="$PANE_LIST" QUERY="$QUERY" MODE="$MODE" LINES="$LINES" OWN="$OWN" EXCLUDE="$EXCLUDE" \
  python3 - "$SELF" <<'PY'
import json, os, re, subprocess, sys

self_name = sys.argv[1]
query = os.environ.get("QUERY", "")
mode = os.environ.get("MODE", "all_words")
lines = int(os.environ.get("LINES") or 400)
own = os.environ.get("OWN", "")
exclude = os.environ.get("EXCLUDE", "")
words = [w for w in re.split(r'\s+', query.strip()) if w]
need = 1 if mode == "any_word" else len(words)

raw = os.environ.get("PANE_LIST", "")
try:
    panes = (json.loads(raw).get("result") or {}).get("panes") or []
except Exception:
    print(f'sit: {self_name} could not read `herdr pane list`')
    raise SystemExit(3)

agents = [p for p in panes if p.get("agent")]
skipped_self = 0
unreadable = []
hits = []

for p in agents:
    pane = p.get("pane_id") or ""
    if not pane or pane == exclude or pane == own:
        skipped_self += 1 if pane == own else 0
        continue
    try:
        out = subprocess.run(['herdr', 'pane', 'read', pane, '--lines', str(lines)],
                             capture_output=True, text=True, timeout=25)
    except Exception:
        unreadable.append(pane)
        continue
    if out.returncode != 0:
        unreadable.append(pane)
        continue
    text = out.stdout
    low = text.lower()
    found = [w for w in words if w.lower() in low]
    if len(found) < need:
        continue
    line = ""
    for ln in reversed(text.splitlines()):
        s = ln.strip()
        if not s:
            continue
        if any(w.lower() in s.lower() for w in found):
            line = s
            break
    line = re.sub(r'[\s│┃|]+$', '', line)[:160].replace('"', "'")
    hits.append({
        "pane": pane,
        "agent": p.get("agent") or "?",
        "status": p.get("agent_status") or "unknown",
        "match": " ".join(found),
        "line": line,
        "title": (p.get("terminal_title_stripped") or "")[:60].replace('"', "'"),
    })

print(f'seat-find[{len(hits)}]{{pane,agent,status,match,line,title}}:')
for h in hits:
    print('  "%s","%s","%s","%s","%s","%s"' % (h["pane"], h["agent"], h["status"], h["match"], h["line"], h["title"]))
if own:
    print(f'help: own pane {own} was skipped — `--all` includes it')
if unreadable:
    print(f'help: {len(unreadable)} agent pane(s) could not be read ({", ".join(unreadable)}) — counted, not dropped')
if not agents:
    print('sit: no agent stands in any pane of this herdr — nothing to search')
raise SystemExit(0 if hits else 1)
PY
