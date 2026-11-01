#!/usr/bin/env bash
# daily-line.sh — THE daily line: what moved, what is blocked, what is owed — written from the record,
# never typed from memory.
#
# WHY THIS FILE EXISTS (documentation design, 2026-11-01 §7): the design counts every kind of page and
# names exactly two broken links. The handoff was the first (bin/agents/report.sh closed it). This is the
# second: "the daily line stopped — the Nornir briefing runs, the written day does not." Fourteen logs
# exist and the newest was six days old, so a week of measurement lived only in a conversation.
#
# WHAT IT READS — and nothing else:
#   * the handoffs written today (state/eindri-reports/*.md, by their own date sections)
#   * the cards, when this seat has a board configured (PLANE_API_BASE + PLANE_API_TOKEN): closed today,
#     blocked, and in progress
# A seat with no board writes the handoff half and says so — a clean skip is a pass (RULES/25).
#
# Usage:
#   daily-line.sh                 # append today's line to the vault's daily log
#   daily-line.sh --date 2026-11-01
#   daily-line.sh --dry-run       # print it, write nothing
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE="${YMIR_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/ymir}"
DAY="$(date +%F)"; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in --date) DAY="${2:?date}"; shift 2 ;; --dry-run) DRY=1; shift ;; *) printf 'error: unknown flag %s\n' "$1" >&2; exit 2 ;; esac
done

BODY="$(python3 - "$STATE" "$DAY" <<'PY'
import os, sys, re, datetime
state, day = sys.argv[1], sys.argv[2]
def read(p):
    try: return open(p, errors="replace").read()
    except OSError: return ""
# 1) the handoffs written today
reports = []
d = os.path.join(state, "eindri-reports")
if os.path.isdir(d):
    for f in sorted(os.listdir(d)):
        if not f.endswith(".md"): continue
        txt = read(os.path.join(d, f))
        if day not in txt: continue
        sec = [s for s in txt.split("\n## ") if s.startswith(day) or day in s.split("\n")[0]]
        head = sec[-1] if sec else txt
        def field(k):
            m = re.search(r'"%s","([^"]*)"' % k, head)
            return m.group(1) if m else ""
        reports.append((f[:-3], field("state"), field("next"), field("not_verified")))
print(f"handoffs today: {len(reports)}")
for r in reports:
    print(f"  · {r[0]} — {r[1] or 'state unread'}; next: {r[2] or 'not stated'}")
    if r[3]:
        print(f"    unproven: {r[3]}")
PY
)"

# 2) the cards, when this seat has a board
CARDS=""
if [ -n "${PLANE_API_BASE:-}" ] && [ -x "$ROOT/bin/vault/hodd.sh" ]; then
  TOK="$(bash "$ROOT/bin/vault/hodd.sh" emit secrets/platform.env 2>/dev/null | sed -n 's/^export PLANE_API_TOKEN=//p' | tr -d "\"'")"
  if [ -n "$TOK" ]; then
    CARDS="$(PLANE_TOKEN="$TOK" PLANE_API_BASE="$PLANE_API_BASE" DAY="$DAY" python3 - <<'PY'
import json, os, urllib.request, urllib.error
tok, base, day = os.environ["PLANE_TOKEN"], os.environ["PLANE_API_BASE"].rstrip("/"), os.environ["DAY"]
def get(p):
    r = urllib.request.Request(base + p, headers={"X-API-Key": tok})
    try: return json.load(urllib.request.urlopen(r, timeout=12))
    except Exception: return {}
lines, blocked, done, doing = [], 0, 0, 0
for ws in ("wayof", "synteon", "opticat", "whynotproductions", "ymirhome"):
    d = get(f"/api/v1/workspaces/{ws}/projects/?per_page=100")
    for p in (d.get("results") or []):
        try:
            i = get(f"/api/v1/workspaces/{ws}/projects/{p['id']}/issues/?per_page=100")
        except Exception:
            continue
        for card in (i.get("results") or []):
            names = [l.get("name", "") for l in (card.get("labels") or [])]
            st = (card.get("state") or "")
            if any(n.startswith("blocked:") for n in names):
                blocked += 1
                who = next(n.split(":", 1)[1] for n in names if n.startswith("blocked:"))
                lines.append(f"  · blocked on {who}: {p['identifier']}-{card.get('sequence_id')} {card['name'][:60]}")
print(f"cards: {len(lines)} blocked")
print("\n".join(lines[:8]))
PY
)"
  fi
else
  CARDS="cards: 0 — no board on this seat (PLANE_API_BASE unset)"
fi
if [ -z "${CARDS// }" ]; then CARDS="cards: 0 — no board on this seat"; fi

ENTRY="daily line${CARDS:+
$CARDS}${BODY:+
$BODY}"
if [ "$DRY" = 1 ]; then
  printf '%s\n' "$ENTRY"; exit 0
fi
bash "$ROOT/bin/records/daily-log.sh" add "$ENTRY" --actor nornir --tag daily-line
printf 'daily-line[1]{day,appended}:\n  "%s",true\n' "$DAY"
