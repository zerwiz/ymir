#!/usr/bin/env bash
# issue-watch.sh — READ THE ISSUES, and close the ones that are already solved.
#
# WHY (the Allfather, 2026-11-11): *"are nobody reading the issues and solving them?"* He was right:
# `pr-watch` watched pull requests and nothing at all watched issues, so the house's own red-main issue
# (#657) sat unread while every gate it named was being fixed by hand in another window.
#
# What this door does, every five minutes:
#   a NEW issue              → one line to the operator: number · title · labels · age
#   an issue labelled main-red → if `bin/gates/ci-verify.sh` is GREEN, comment why and CLOSE it
#                                (that is not a guess: the issue's own text says a green run closes it)
#                              → if it is still red, comment the first failing gate, so the issue is alive
#   everything else          → announced once, then left to a human (a machine does not guess an intent)
#   nothing changed          → silence
#
# Usage: issue-watch.sh [--dry-run] [--status] [--install-timer]
# Exit: 0 ran · 1 a fault (named) · 2 usage.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"
. "$ROOT/bin/vault/hoard-lib.sh"
STATE=""; hoard_state_dir STATE; mkdir -p "$STATE"
SEEN="$STATE/issue-watch.json"; REPO="${ISSUE_WATCH_REPO:-zerwiz/ymir}"
DRY=0; STATUS=0
ORIG=("$@")
while [ $# -gt 0 ]; do case "$1" in --dry-run) DRY=1; shift;; --status) STATUS=1; shift;; *) shift;; esac; done
for _a in "${ORIG[@]}"; do
  if [ "$_a" = "--install-timer" ]; then
    U="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"; mkdir -p "$U"
    printf '[Unit]\nDescription=issue-watch — read the issues\n\n[Service]\nType=oneshot\nWorkingDirectory=%s\nExecStart=/usr/bin/env bash %s/bin/forge/issue-watch.sh\n' "$ROOT" "$ROOT" >"$U/issue-watch.service"
    printf '[Unit]\nDescription=issue-watch — every 5 minutes\n\n[Timer]\nOnBootSec=4min\nOnUnitActiveSec=5min\nAccuracySec=30s\nUnit=issue-watch.service\n\n[Install]\nWantedBy=timers.target\n' >"$U/issue-watch.timer"
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable --now issue-watch.timer >/dev/null 2>&1 || true
    printf 'issue-watch-timer[2]{unit,state}:\n  "%s","%s"\n' "$U/issue-watch.timer" "$(systemctl --user is-active issue-watch.timer 2>/dev/null)"
    exit 0
  fi
done
command -v gh >/dev/null 2>&1 || { printf 'issue-watch: gh missing\n' >&2; exit 1; }

issues=$(gh issue list --repo "$REPO" --state open --json number,title,labels,createdAt 2>/dev/null) \
  || { printf 'issue-watch: gh issue list failed for %s\n' "$REPO" >&2; exit 1; }
[ -n "$issues" ] || issues='[]'

say() {  # <message> <target>
  [ "$DRY" = 1 ] && return 0
  bash "$ROOT/bin/notify/send.sh" --source engine --severity HIGH --message "$1" \
    --key "issue-watch-$(printf '%s' "$1" | sha1sum | cut -c1-12)" ${2:+--target "$2"} >/dev/null 2>&1
}

python3 - "$SEEN" "$DRY" "$STATUS" <<PY > /tmp/iw.out
import json,sys,os,datetime
seen_path, dry, status = sys.argv[1], sys.argv[2]=='1', sys.argv[3]=='1'
issues = json.loads('''$issues''')
seen = {}
if os.path.exists(seen_path):
    try: seen = json.load(open(seen_path))
    except Exception: seen = {}
now = datetime.datetime.now(datetime.timezone.utc)
lines = []
for it in issues:
    n = str(it['number']); labels = [l['name'] for l in it.get('labels') or []]
    created = datetime.datetime.strptime(it['createdAt'], '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=datetime.timezone.utc)
    age_h = (now - created).total_seconds()/3600
    if not seen.get(n, {}).get('announced'):
        lines.append(f"issue #{n} {it['title'][:80]} — {','.join(labels) or 'no label'}, open {age_h:.0f}h")
        seen[n] = {'announced': True, 'title': it['title'], 'labels': labels}
print("\\n".join(lines) if lines else "issue-watch: nothing new")
json.dump(seen, open(seen_path,'w'), indent=1)
PY
head -50 /tmp/iw.out | while IFS= read -r line; do [ -n "$line" ] || continue; printf '%s\n' "$line"; case "$line" in issue\ #*) say "$line" "issue:$(printf '%s' "$line" | sed -E 's/^issue #([0-9]+).*/\1/')";; esac; done
[ "$STATUS" = 1 ] && printf 'issue-watch[1]{repo,open}:\n  "%s","%s"\n' "$REPO" "$(printf '%s' "$issues" | python3 -c 'import json,sys;print(len(json.load(sys.stdin)))')"

# ── the red-main issue: close it when the tree it names is green ─────────────────────────────────
if printf '%s' "$issues" | grep -q 'main-red\|main is red'; then
  n=$(printf '%s' "$issues" | python3 -c '
import json,sys
for i in json.load(sys.stdin):
    if any(l["name"]=="main-red" for l in (i.get("labels") or [])) or "main is red" in i["title"].lower():
        print(i["number"]); break')
  if [ -n "$n" ] && [ "$DRY" = 0 ]; then
    if timeout 900 bash "$ROOT/bin/gates/ci-verify.sh" >/tmp/iw-ci.log 2>&1; then
      gh issue comment "$n" --repo "$REPO" --body "main is green again (\`bin/gates/ci-verify.sh\` PASS at $(git -C "$ROOT" rev-parse --short HEAD)). Closing, as this issue's own text asks." >/dev/null 2>&1
      gh issue close "$n" --repo "$REPO" >/dev/null 2>&1 && say "issue #$n closed: main is green again" "issue:$n"
    else
      first=$(grep -m1 '"FAIL"' /tmp/iw-ci.log | cut -c1-160)
      gh issue comment "$n" --repo "$REPO" --body "Still red. First failing gate: ${first:-see the run}" >/dev/null 2>&1
    fi
  fi
fi
