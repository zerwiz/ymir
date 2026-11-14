#!/usr/bin/env bash
# nornir-job-private-scan.sh — the twice-daily sweep of the Ymir repository for things that belong in the home.
#
# Why it exists (his word, 2026-11-14): *"the ymirs repo are just the runtime and apps etc to be able to run ymirs
# functions and features"* — so a client name, a mailbox, a schedule, a plan, a key, an address or a private note in
# that repo is a leak, not a shortcut. This sweeps for them, and when it finds any it does not fix them itself: it
# writes the queue and sends an Eindri out, so the fix is a decision with an owner and the arm is told.
#
# Best practice it follows (read 2026-11-14): a pre-commit hook can be skipped with --no-verify and cannot see what is
# already in the tree; the server-side sweep is the safety net, it must run on the server's clock, and findings are
# reviewed by a person — every scanner has false positives, so this reports, it does not block.
#
#   nornir-job-private-scan.sh            sweep the working tree, write the queue, seat an errand on findings
#   nornir-job-private-scan.sh --report   same, print, do not seat
#   nornir-job-private-scan.sh --json     machine-readable
#
# Exit: 0 clean · 1 findings (the hotline) · 2 could not scan
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
REPO="${YMIR_REPO:-$HOME/ymir}"
HOME_DIR=""; declare -f ymir_home_root >/dev/null 2>&1 && ymir_home_root HOME_DIR 2>/dev/null
[ -n "$HOME_DIR" ] || { printf 'private-scan: the home could not be resolved — bin/vault/hoard-lib.sh is the one door\n' >&2; exit 2; }
QUEUE="$HOME_DIR/hodd/state/private-scan/queue.md"
REPORT_DIR="$HOME_DIR/hodd/state/private-scan"
LOG="$REPORT_DIR/scan.log"
MODE="${1:-}"

[ -d "$REPO/.git" ] || { printf 'private-scan: no repository at %s\n' "$REPO" >&2; exit 2; }
command -v rg >/dev/null 2>&1 || { printf 'private-scan: ripgrep is required\n' >&2; exit 2; }
mkdir -p "$REPORT_DIR"

# ── what is looked for ────────────────────────────────────────────────────────────────────────────────────────
# Each rule is a regex and a category. The categories mirror what belongs in the home instead of here.
#   SECRET   a credential — never in a public repo, in any form
#   ADDRESS  an IP, a tailnet name, a hostname, a home path — the machine's address is not public
#   PERSON   a mailbox or a phone number — private data, Rule 04
#   BUSINESS a client, company or project name under NDA — the NDA gate's list, applied to content too
#   PRIVATE  a plan, schedule, note or dump — a record, not runtime code
rules() {
  cat <<'RULES'
SECRET	sk-[A-Za-z0-9]{20,}
SECRET	oc_sk_[A-Za-z0-9]{10,}
SECRET	gh[pousr]_[A-Za-z0-9]{20,}
SECRET	AKIA[0-9A-Z]{16}
SECRET	xox[baprs]-[A-Za-z0-9-]{10,}
SECRET	-----BEGIN [A-Z ]*PRIVATE KEY-----
SECRET	AGE-SECRET-KEY-1[A-Z0-9]{10,}
SECRET	re_[A-Za-z0-9]{20,}
SECRET	eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.
ADDRESS	\b100\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\b
ADDRESS	\b192\.168\.[0-9]{1,3}\.[0-9]{1,3}\b
ADDRESS	\b10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\b
ADDRESS	[A-Za-z0-9-]+\.ts\.net
ADDRESS	/home/zerwiz[A-Za-z]*/
ADDRESS-LOW	[a-z0-9-]+\.zerwiz\.org
ADDRESS-LOW	/home/(alice|bob|tester|user|example|test)/
PERSON	[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.(?!test|example|invalid|local)\w{2,}
PERSON	\+?46[ -]?7[0-9]{1,2}[ -]?[0-9]{3}[ -]?[0-9]{2}[ -]?[0-9]{2}
RULES
}

# Names that identify a client, a company or a person are read from the home, never hardcoded in this public repo.
# `hodd/identity/nda-names.txt` — one name per line — is the NDA gate's own list; if it is absent, this rule is skipped
# and the sweep says so, because a silently missing rule is a false clean.
nda_file="$HOME_DIR/hodd/identity/nda-names.txt"
nda_rules=""
if [ -f "$nda_file" ]; then
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    nda_rules+="BUSINESS	(?i)\\b${name// /[ _-]}\\b"$'\n'
  done < "$nda_file"
else
  printf 'private-scan: note — no %s, so no BUSINESS names are checked this run\n' "$nda_file" >&2
fi

# A false positive must be written down, not silently tolerated: the allow file lives in the home (private) and holds
# one regex per line — each with a comment saying why it is safe. A finding that matches is still counted as `allow`.
allow_file="$HOME_DIR/hodd/state/private-scan/allow.txt"
findings=0
low=0
allowed=0
out="$REPORT_DIR/findings.txt"
: > "$out"

while IFS=$'\t' read -r cat pattern; do
  [ -z "${pattern:-}" ] && continue
  # exclude the guard itself, the docs that teach the patterns, and vendored/node_modules
  while IFS= read -r hit; do
    [ -z "$hit" ] && continue
    if [ -f "$allow_file" ] && printf '%s' "$hit" | grep -qvE '^\s*(#|$)' && \
       printf '%s' "$hit" | grep -qE -f <(grep -vE '^\s*(#|$)' "$allow_file") 2>/dev/null; then
      allowed=$((allowed+1)); continue
    fi
    printf '%s\t%s\n' "$cat" "$hit" >> "$out"
    case "$cat" in ADDRESS-LOW) low=$((low+1));; *) findings=$((findings+1));; esac
  done < <(rg --no-heading --line-number --color never -e "$pattern" \
             -g '!node_modules' -g '!.git' -g '!docs/fixes/**' \
             -g '!bin/gates/guards/**' -g '!.pi/**' -g '!*.lock' \
             -g '!docs/features/**' -g '!RULES/**' \
             -g '!assets/reference/**' -g '!**/dist/**' -g '!**/build/**' \
             -g '!.yggdrasil/**' -g '!docs/**' -g '!apps/*/tickets/**' \
             "$REPO" 2>/dev/null | sed "s|^$REPO/||" | head -40)
done < <( { rules; printf '%s' "$nda_rules"; } | sort -u )

stamp="$(date -u +%FT%TZ)"
if [ "$MODE" = "--json" ]; then
  python3 - "$out" "$stamp" <<'PY'
import json,sys,collections
rows=[l.rstrip('\n').split('\t',1) for l in open(sys.argv[1]) if l.strip()]
by=collections.Counter(r[0] for r in rows)
print(json.dumps({"at":sys.argv[2],"count":len(rows),"by_category":dict(by),
                  "findings":[{"category":c,"where":w} for c,w in rows]},indent=2))
PY
  [ "$findings" -gt 0 ] && exit 1 || exit 0
fi

printf '%s private-scan: %s high · %s low · %s allowed in %s\n' "$stamp" "$findings" "$low" "$allowed" "$REPO" >> "$LOG"

if [ "$findings" -eq 0 ]; then
  printf 'private-scan: clean — %s high, %s low (%s)\n' "$findings" "$low" "$stamp"
  exit 0
fi

# ── the queue and the errand ────────────────────────────────────────────────────────────────────────────────
{
  printf '## %s — %s finding(s)\n\n' "$stamp" "$findings"
  awk -F'\t' '{printf "- **%s** `%s`\n", $1, $2}' "$out"
  printf '\n'
} >> "$QUEUE"

if [ "$MODE" = "--report" ]; then
  cat "$out" | head -40
  printf '\nprivate-scan: %s finding(s) — queued at %s\n' "$findings" "$QUEUE"
  exit 1
fi

# One heavy thing at a time (home contract, law 7): a scan is cheap, but the errand it seats is not free — and a second
# sweep while an errand is already working would duplicate the triage. So: seat only when no private-scan seat lives.
if pgrep -f "yggdrasil/private-scan" >/dev/null 2>&1; then
  printf 'private-scan: %s finding(s) queued; an errand is already triaging — not seating another\n' "$findings"
  exit 1
fi

brief="$HOME_DIR/hodd/data/private-scan/brief.md"
mkdir -p "$(dirname "$brief")"
cat > "$brief" <<EOF
# private-scan — the twice-daily sweep found $findings thing(s) that belong in the home

**Sweep at** $stamp. **Findings:** $QUEUE (and $out).

Ymir's repository is the runtime and the apps — nothing private belongs in it. Your job:

1. Read every finding. For each one decide: **belongs in the home** (a record, a plan, a name, an address, a key) or
   **belongs in the repo** (a test fixture that is synthetic, a documented default, a pattern that only *matches* —
   false positives are expected and are the reason a person reads this).
2. Fix the ones that belong in the home, in the home: move the record to the right shelf under
   \`\$YMIR_HOME/hodd/\`, and remove it from the repository **by a commit** (never a bare delete: the repo is public and
   its history is permanent, so say in the commit what moved and why).
3. If a real secret was found: it is compromised the moment it is seen — say so in your report and name it for
   rotation. Do not paste the value anywhere.
4. Open ONE pull request with the fixes. Nothing merges without the Allfather.
5. Report to the arm in one message: what was found, what you moved, what you left and why, and what needs a human.

**Constraints:** do not run builds; this machine has 11 GB and it has died twice. No cron rows, no tunnels, no
compose changes. If a finding needs a decision you cannot make, put it in the report and stop.
EOF

printf 'private-scan: %s finding(s) — brief written, seating an errand\n' "$findings"
printf 'private-scan %s findings — see %s\n' "$findings" "$QUEUE"
( cd "$REPO" && bin/agents/einherjar-spawn.sh private-scan "$REPO" --mode direct-PR --harness pi \
    --model opencode-go/deepseek-v4.1-flash --force >>"$LOG" 2>&1 & )
exit 1
