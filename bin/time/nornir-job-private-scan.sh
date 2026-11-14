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
# ONE CAPABILITY, ONE IMPLEMENTATION (2026-11-14, plan 287 §6 and this sweep's own PR #732). The halves divide so, and
# each half has exactly one owner:
#   · THE OPERATOR'S OWN WORDS and the generic shapes — a person, a client, a company, a mail domain, a machine, a
#     real tailnet host, a concrete private address — are judged by ONE engine, `bin/gates/agnostic-audit.sh`, which
#     reads `hodd/identity/public-deny.txt` from the home and never prints it. This job CALLS that engine over
#     `origin/main` (fetched fresh) and folds its verdict into the queue; it does not re-spell the match itself. The
#     engine is also the pre-push and CI ward, judging only what a push adds.
#   · THE SECRETS — a key, a token, a private-key header — are shape, not list. Their GATE is `bin/gates/secret-scan.sh`
#     (gitleaks over the staged diff and over every PR and main; PR #733, which also generates its rules from the same
#     home list) with `bin/gates/guards/secret-guard.sh` beside it in CI. This sweep keeps the two SECRET shapes it had
#     as a second pair of eyes that needs no binary — belt and braces, at the clock's moment, never the gate.
#   · THE CONTENT OF A RECORD (a mailbox, a phone number) is this job's own two rules, which no list can know.
# A leaked word is therefore named in one place, on one clock, and a secret in another — and neither re-implements the
# other.
#
#   nornir-job-private-scan.sh            sweep the working tree, write the queue, seat an errand on findings
#   nornir-job-private-scan.sh --report   same, print, do not seat
#   nornir-job-private-scan.sh --json     machine-readable
#
# Exit: 0 clean · 1 findings (the hotline) · 2 could not scan
set -uo pipefail

# The tree and the home are RESOLVED, never guessed (Rule 07). Until 2026-11-14 this line carried
# `$HOME/Documents/ymirhome` as its own default — a second place that knew where the hoard lives, which is
# exactly what `defaults-guard` exists to refuse. A sweep with an unresolved home has nowhere private to
# write its queue and might write another operator's, so it refuses and says which door was missing.
REPO="${YMIR_REPO:-$HOME/ymir}"
# THE ONE RESOLVER (Rule 07): the home is ASKED, never guessed — a hardcoded fallback path is the drift that made
# four scripts disagree about where the hoard lives (defaults-guard, 2026-11-14). No home, no queue: said, not invented.
HOME_DIR="${YMIR_HOME:-}"
if [ -z "$HOME_DIR" ] && [ -r "$REPO/bin/vault/hoard-lib.sh" ]; then
  # shellcheck source=bin/vault/hoard-lib.sh
  . "$REPO/bin/vault/hoard-lib.sh" 2>/dev/null || true
  if declare -f ymir_home_root >/dev/null 2>&1; then ymir_home_root HOME_DIR 2>/dev/null || true; fi
fi
[ -n "$HOME_DIR" ] || { printf 'private-scan: no Ymir home resolves (YMIR_HOME unset, no hoard-lib) — the queue has nowhere to live\n' >&2; exit 2; }
QUEUE="$HOME_DIR/hodd/state/private-scan/queue.md"
REPORT_DIR="$HOME_DIR/hodd/state/private-scan"
LOG="$REPORT_DIR/scan.log"
MODE="${1:-}"

# A WORKTREE IS A CHECKOUT TOO (2026-11-14): `-d "$REPO/.git"` answered no for every Yggdrasil worktree, because a
# worktree's `.git` is a FILE that points at the shared gitdir — so the sweep refused to run on exactly the trees a
# worker forges in. The question is whether git can answer, not what the path is called.
git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || { printf 'private-scan: no repository at %s\n' "$REPO" >&2; exit 2; }
# A missing ripgrep skips THIS half by name; the engine still runs, because the names are the half that must not go
# unjudged (RULES/25: a clean skip is a pass, a false clean is not).
HAVE_RG=1
command -v rg >/dev/null 2>&1 || { HAVE_RG=0; printf 'private-scan: note — no ripgrep here, so the SECRET and mailbox rules are SKIPPED; the words of the home are still judged\n' >&2; }
mkdir -p "$REPORT_DIR"

# ── what is looked for ────────────────────────────────────────────────────────────────────────────────────────
# Each rule is a regex and a category. The categories mirror what belongs in the home instead of here.
#   SECRET   a credential — never in a public repo, in any form (the shape half; secret-guard.sh owns the gate)
#   PERSON   a mailbox or a phone number — private data, Rule 04
#   AGNOSTIC the operator's own words and every generic shape — judged by bin/gates/agnostic-audit.sh, below,
#            against `hodd/identity/public-deny.txt`: a person, a client, a company, a mail domain, a machine,
#            a real tailnet host, a concrete private address. This job does not spell any of them itself.
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
# ADDRESS, ADDRESS-LOW and BUSINESS used to be spelled here. They are not any more: the machines, the tailnet, the
# concrete private addresses and every name of the operator's are judged by bin/gates/agnostic-audit.sh against the
# home's own list, and two spellings of "a private address" is how one of them ends up wrong (the ward's own first
# spelling missed an entire private block for exactly this reason, 2026-11-14).
PERSON	[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.(?!test|example|invalid|local)\w{2,}
PERSON	\+?46[ -]?7[0-9]{1,2}[ -]?[0-9]{3}[ -]?[0-9]{2}[ -]?[0-9]{2}
RULES
}

# The names of people, clients and companies are read from the home by bin/gates/agnostic-audit.sh — the one engine —
# through `hodd/identity/public-deny.txt`. This job no longer keeps a second list (`nda-names.txt`), because a second
# list is a second truth and a silently missing one is a false clean.

# A false positive must be written down, not silently tolerated: the allow file lives in the home (private) and holds
# one regex per line — each with a comment saying why it is safe. A finding that matches is still counted as `allow`.
# THE ALLOW LIST LIVES IN config/, NOT state/ (carried from fix/agnostic-audit-job, 2026-11-14): `hodd/state/` is
# gitignored, so the REASON for every accepted finding would be lost on the next clone — and an allow list whose
# reasons are lost is an allow list nobody can audit. One path, and it is the one that travels.
allow_file="$HOME_DIR/hodd/config/private-scan-allow.txt"
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
    findings=$((findings+1))
  done < <(rg --no-heading --line-number --color never -e "$pattern" \
             -g '!node_modules' -g '!.git' -g '!docs/fixes/**' \
             -g '!bin/gates/guards/**' -g '!.pi/**' -g '!*.lock' \
             -g '!docs/features/**' -g '!RULES/**' \
             -g '!assets/reference/**' -g '!**/dist/**' -g '!**/build/**' \
             -g '!.yggdrasil/**' -g '!docs/**' -g '!apps/*/tickets/**' \
             "$REPO" 2>/dev/null | sed "s|^$REPO/||" | head -40)
done < <( { [ "$HAVE_RG" = 1 ] && rules || true; } | sort -u )

# ── the one engine: the operator's words, and every generic shape ────────────────────────────────────────────
# `bin/gates/agnostic-audit.sh` is the census of the whole tree (and `--ref` of a fetched one), the ward a push
# meets, and the only reader of `hodd/identity/public-deny.txt`. This job asks it, and folds its verdict into the
# same queue, so a person triaging the sweep sees one list of places to look — not two scanners disagreeing.
ENGINE="$REPO/bin/gates/agnostic-audit.sh"
engine_ref=""
if [ -n "${YMIR_AUDIT_REF:-}" ]; then
  engine_ref="$YMIR_AUDIT_REF"
elif git -C "$REPO" rev-parse -q --verify origin/main >/dev/null 2>&1; then
  engine_ref="origin/main"
fi
# FRESH, OR SAID ALOUD: the census must read what main holds now, not what this copy last pulled.
if [ -z "${YMIR_OFFLINE:-}" ] && git -C "$REPO" rev-parse -q --verify origin >/dev/null 2>&1; then
  git -C "$REPO" fetch --quiet origin main 2>/dev/null \
    || printf 'private-scan: note — the fetch failed; the engine judged the %s this copy already carries\n' "${engine_ref:-tree}" >&2
fi
if [ -r "$ENGINE" ]; then
  if [ -n "$engine_ref" ]; then
    # Every finding, not the first screenful: the engine caps its printed report for a person's terminal, and the
    # queue must carry them all (it was silently cutting at 200 and reporting 201, 2026-11-14).
    ag_out="$( cd "$REPO" && YMIR_AUDIT_MAX_REPORT=100000 bash "$ENGINE" --ref "$engine_ref" 2>&1 )" || true
  else
    ag_out="$( cd "$REPO" && YMIR_AUDIT_MAX_REPORT=100000 bash "$ENGINE" 2>&1 )" || true
  fi
  while IFS= read -r line; do
    where="$(printf '%s' "$line" | awk '{print $1}')"
    [ -n "$where" ] || continue
    printf 'AGNOSTIC\t%s\n' "$where" >> "$out"
    findings=$((findings+1))
  done < <(printf '%s\n' "$ag_out" | grep -E '^  [^ ].*:[0-9]+ ' | sed 's/^  //')
  printf '%s\n' "$ag_out" | grep -q 'NONE READ' && \
    printf 'private-scan: note — the home holds no deny list, so only the generic shapes were judged (hodd/identity/public-deny.txt)\n' >&2
else
  printf 'private-scan: note — no bin/gates/agnostic-audit.sh in %s, so the operator'"'"'s words were NOT judged this run\n' "$REPO" >&2
fi

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

# The operator hears it once, through the one hotline (plan 287 §6). It is reached ONLY on a finding: a clean run has
# already returned above, so a channel that says "still fine" twice a day can never exist.
if [ -r "$REPO/bin/notify/send.sh" ]; then
  bash "$REPO/bin/notify/send.sh" --source cron --severity MEDIUM \
    --key "private-scan:$(date +%F)" \
    --message "the public tree carries $findings thing(s) that belong in the home ($stamp); the queue is hodd/state/private-scan/queue.md" \
    >/dev/null 2>&1 || printf 'private-scan: the hotline could not be reached; the queue and the journal carry it\n' >&2
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
