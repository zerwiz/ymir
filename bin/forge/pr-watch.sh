#!/usr/bin/env bash
# pr-watch.sh — TELL HIM a PR arrived. A watcher that only queues a wake tells nobody.
#
# WHY (the Allfather, 2026-11-11, at 01:00): *"WHY DONT WE GET TO KNOW FROM THE GITHUB THAT PRS ARE
# THERE?? DONT WE HAVE ANY FUNCING WATCHERS?"* We had one — `review-watch` — and it raised an ask into
# the arm's queue. An ask is not a notification: it waits for a drain, and the drain happens when the
# arm wakes for another reason. So a PR could sit for eight hours and the operator never heard the door.
#
# This door speaks on the channel he actually reads, and it stays quiet otherwise:
#   new PR            → one line: number · author · title · CI state
#   still open > 1h   → one line per PR per HOUR (not per minute)
#   merged / closed   → one line, then forgotten
#   nothing changed   → silence (a chatty watcher is ignored, which is worse than none)
#
# Usage: pr-watch.sh [--dry-run] [--hours N] [--status]
# Exit: 0 ran · 1 a fault (named) · 2 usage.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
H=""; declare -f ymir_home_root >/dev/null 2>&1 && ymir_home_root H 2>/dev/null
STATE="${H:-$HOME/Documents/ymirhome}/state"; mkdir -p "$STATE"
SEEN="$STATE/pr-watch.json"; REPO="${PR_WATCH_REPO:-zerwiz/ymir}"
DRY=0; HOURS=1; STATUS=0
while [ $# -gt 0 ]; do case "$1" in --dry-run) DRY=1; shift;; --hours) HOURS="${2:-1}"; shift 2;; --status) STATUS=1; shift;; *) shift;; esac; done
# ── the clock ──────────────────────────────────────────────────────────────────────────────────
# A watcher nobody starts is a watcher that never speaks. `--install-timer` seats a user unit that
# runs this door every 5 minutes, so a PR is announced within minutes of arriving, with or without
# anyone remembering to look.
if [ "${1-}" = "--install-timer" ]; then
  U="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"; mkdir -p "$U"
  cat >"$U/pr-watch.service" <<UNIT
[Unit]
Description=pr-watch — tell the operator a PR arrived

[Service]
Type=oneshot
WorkingDirectory=$ROOT
ExecStart=/usr/bin/env bash $ROOT/bin/forge/pr-watch.sh
UNIT
  cat >"$U/pr-watch.timer" <<UNIT
[Unit]
Description=pr-watch — every 5 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
AccuracySec=30s
Unit=pr-watch.service

[Install]
WantedBy=timers.target
UNIT
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user enable --now pr-watch.timer >/dev/null 2>&1 || true
  printf 'pr-watch-timer[2]{unit,state}:\n  "%s","%s"\n' "$U/pr-watch.timer" "$(systemctl --user is-active pr-watch.timer 2>/dev/null)"
  exit 0
fi

command -v gh >/dev/null 2>&1 || { printf 'pr-watch: gh missing\n' >&2; exit 1; }
NOW=$(date +%s)
prs=$(gh pr list --repo "$REPO" --state open --json number,title,author,mergeStateStatus,createdAt,headRefName 2>/dev/null) || { printf 'pr-watch: gh pr list failed for %s\n' "$REPO" >&2; exit 1; }
[ -n "$prs" ] || prs='[]'
python3 - "$SEEN" "$NOW" "$HOURS" "$DRY" "$STATUS" "$REPO" <<PY
import json,sys,os,subprocess,datetime
seen_path,now,hours,dry,status,repo = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]=='1', sys.argv[5]=='1', sys.argv[6]
prs = json.loads('''$prs''')
seen = {}
if os.path.exists(seen_path):
    try: seen = json.load(open(seen_path))
    except Exception: seen = {}
out = []
for p in prs:
    n = str(p['number']); created = int(datetime.datetime.strptime(p['createdAt'], '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=datetime.timezone.utc).timestamp())
    age_h = (now - created) / 3600
    s = seen.get(n, {})
    ci = 'green' if p['mergeStateStatus'] in ('CLEAN','UNSTABLE') else p['mergeStateStatus'].lower()
    if not s.get('announced'):
        out.append(f"new PR #{n} by {p['author']['login']}: {p['title'][:80]} — CI {ci}, open {age_h:.0f}h")
        s['announced'] = True
    elif age_h >= hours:
        last = s.get('last_nag', 0)
        if now - last >= 3600:
            out.append(f"PR #{n} still open after {age_h:.0f}h: {p['title'][:70]} — CI {ci}")
            s['last_nag'] = now
    s['title'] = p['title']; seen[n] = s
for n in list(seen):
    if n not in {str(p['number']) for p in prs}:
        out.append(f"PR #{n} left the queue (merged or closed): {seen.pop(n).get('title','')[:70]}")
if status:
    print(f"pr-watch[1]{{repo,open,would_say}}:\n  \"{repo}\",\"{len(prs)}\",\"{len(out)}\"")
if out and not dry:
    body = "\n".join("• " + l for l in out)
    subprocess.run([os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),'bin/notify/send.sh'), '--to', 'telegram', body], check=False)
json.dump(seen, open(seen_path,'w'), indent=1)
print("\n".join(out) if out else "pr-watch: nothing new (silence is the healthy signal)")
PY
