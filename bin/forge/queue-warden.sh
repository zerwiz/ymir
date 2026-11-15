#!/usr/bin/env bash
# queue-warden.sh — PR HYGIENE: five open at most, the stale ones named, a conflicting branch
# re-cut onto main under a NEW name. It force-pushes nothing, closes nothing, and commits nothing
# with --no-verify.
#
# THE MERGE ROAD IS CLOSED EXCEPT ON THE HEART (the Allfather, 2026-11-14: "the heart handles the
# merging of the PRs … config/machines/<heart>/wardens.yaml is the only file that may say
# merge: on … every other machine's says merge: off, and the template ships merge: off"), where the
# heart is the machine `bin/skuld/role.sh` names heart — this file never spells a machine's name.
# Where the road is open, its ONLY door is bin/forge/merge-verdict.sh — one sha, one verdict, main
# green, branch current, no unexplained bypass (PR #747). Where it is closed, the door says so and
# never reaches a merge call.
#
# WHY THE OLD ROAD WAS THE FAULT (plan 290, 2026-11-14 11:38 CET — the heart's ruling): a dev
# machine's clock was deciding what reached main, under the operator's own GitHub login, with the
# whole-tree gate red and untested major bumps next in its queue. The record of what this door used
# to do, and why it stopped, is docs/fixes/forge/2026-11-14-the-warden-stopped-merging.md.
#
# Usage
#   queue-warden.sh run [--dry-run] [--pr N] [--cap N] [--stale-hours H] [--no-recut]
#   queue-warden.sh status                       # the policy it resolved, and the clock's state
#   queue-warden.sh --install-timer [--start]    # seat the unit; start it only if asked
#   queue-warden.sh --uninstall-timer | --timer-status
#   queue-warden.sh --version | --help
#
# The policy lives in the operator's home, one file per machine (plan 290 §3), and `enabled` is the
# per-machine opt-in:
#   $YMIR_HOME/config/machines/<machine>/wardens.yaml
#     queue-warden:
#       enabled: on|off        # off: no clock seats it, and a scheduled run refuses (a hand may still run it)
#       max_open_prs: 5
#       stale_hours: 48
#       identity: <name>       # the machine's own identity — never a person's login
#       token_ref: <VAULT_KEY> # the vault key holding THAT identity's token
#       merge: on|off          # only the heart's file says on
# A missing file is not a fault: the defaults below stand and the warden says which it used.
set -u
VERSION="2.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"

usage() { sed -n '2,36p' "$0" | sed 's/^# \{0,1\}//'; }

CMD="run"; DRY=0; PR_ONLY=""; CAP=""; STALE_HOURS=""; RECUT=1; START_TIMER=0; TIMER_ACTION=""
while [ $# -gt 0 ]; do
  case "$1" in
    run) CMD="run"; shift ;;
    status) CMD="status"; shift ;;
    --dry-run) DRY=1; shift ;;
    --pr) PR_ONLY="${2:-}"; shift 2 ;;
    --pr=*) PR_ONLY="${1#--pr=}"; shift ;;
    --cap) CAP="${2:-}"; shift 2 ;;
    --cap=*) CAP="${1#--cap=}"; shift ;;
    --stale-hours) STALE_HOURS="${2:-}"; shift 2 ;;
    --stale-hours=*) STALE_HOURS="${1#--stale-hours=}"; shift ;;
    --no-recut) RECUT=0; shift ;;
    --install-timer) TIMER_ACTION=install; shift ;;
    --start) START_TIMER=1; shift ;;
    --uninstall-timer) TIMER_ACTION=uninstall; shift ;;
    --timer-status) TIMER_ACTION=status; shift ;;
    -v|--version) printf '%s\n' "$VERSION"; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'queue-warden: unknown argument %s (try --help)\n' "$1" >&2; exit 2 ;;
  esac
done

# ── the home, and the machine this warden belongs to ─────────────────────────────────────────
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$ROOT/bin/vault/hoard-lib.sh" "$SCRIPT_DIR/../vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
HOME_DIR=""; ymir_home_root HOME_DIR 2>/dev/null || true
STATE=""; hoard_state_dir STATE 2>/dev/null || true
[ -n "$HOME_DIR" ] && [ -n "$STATE" ] || { printf 'queue-warden: home/state unresolved — a warden with no record must not act\n' >&2; exit 1; }
MACHINE="${YMIR_HOST:-$(hostname -s 2>/dev/null | tr 'A-Z' 'a-z')}"
[ -n "$MACHINE" ] || MACHINE="unknown"

# ── the policy: the SHARED reader first, so two wardens never hold two parsers ────────────────
# `bin/forge/warden-policy.py <door> <key>` is the library's door (wardens-own-only). While that
# door is not on this tree the warden reads the same file itself — six lines, one block — and says
# so on every pass (`policy_from`), so a fallback can never pass for the shared reader.
WARDENS="$HOME_DIR/config/machines/$MACHINE/wardens.yaml"
SHARED_READER="$ROOT/bin/forge/warden-policy.py"
POLICY_READER="local"
policy_get() {  # <key> — a scalar under this door's block; empty when absent
  [ -r "$WARDENS" ] || return 0
  if [ -f "$SHARED_READER" ]; then
    local v
    v="$(python3 "$SHARED_READER" queue-warden "$1" 2>/dev/null)" && { POLICY_READER="shared"; printf '%s' "$v"; return 0; }
    printf 'queue-warden: the shared policy reader refused queue-warden/%s — reading it here instead\n' "$1" >&2
  fi
  awk -v k="$1" '
    /^[^[:space:]#]/ { blk = ($1 == "queue-warden:") ; next }
    blk && $1 == k":" {
      v = $0; sub(/^[^:]*:[[:space:]]*/, "", v); sub(/[[:space:]]+#.*$/, "", v); print v; exit
    }' "$WARDENS" 2>/dev/null | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//"
}
[ -n "$CAP" ] || CAP="$(policy_get max_open_prs)"
[ -n "$CAP" ] || CAP=5
[ -n "$STALE_HOURS" ] || STALE_HOURS="$(policy_get stale_hours)"
[ -n "$STALE_HOURS" ] || STALE_HOURS=48
IDENTITY="$(policy_get identity)"; [ -n "$IDENTITY" ] || IDENTITY="unnamed"
TOKEN_REF="$(policy_get token_ref)"
ENABLED="$(policy_get enabled)"; [ -n "$ENABLED" ] || ENABLED="off"     # opt-in: silence is a NO
MERGE_POLICY="$(policy_get merge)"; [ -n "$MERGE_POLICY" ] || MERGE_POLICY="off"

# ── the machine's role, from the fleet registry (never a hostname written in this tree) ───────
ROLES="$(bash "$ROOT/bin/skuld/role.sh" resolve 2>/dev/null | head -1 || true)"
[ -n "$ROLES" ] || ROLES="unknown"

# ── the identity (plan 290 rule 4) ───────────────────────────────────────────────────────────
# The warden WRITES under the machine's own identity or not at all. A person's login on this box is
# never its hand: if the home names no credential, the re-cut is made locally and the push recorded.
MACHINE_TOKEN=""
if [ -n "$TOKEN_REF" ] && [ -r "$ROOT/bin/vault/hodd.sh" ]; then
  MACHINE_TOKEN="$(bash "$ROOT/bin/vault/hodd.sh" emit secrets/platform.env 2>/dev/null | python3 -c '
import shlex, sys
want = sys.argv[1]
for line in sys.stdin:
    line = line.strip()
    if not line.startswith("export "):
        continue
    name, _, value = line[len("export "):].partition("=")
    if name != want:
        continue
    try:
        print(shlex.split(value)[0] if value.strip() else "")
    except ValueError:
        print(value.strip().strip("\""))
    break' "$TOKEN_REF" 2>/dev/null || true)"
fi
CREDENTIAL="absent"
[ -n "$MACHINE_TOKEN" ] && CREDENTIAL="machine"
[ -n "$TOKEN_REF" ] || TOKEN_REF="-"

# ── the merge road: closed unless this machine's own file opens it AND it is the heart ────────
# The answer is a REASON, printed on every pass. A road that opens by omission is how a laptop's
# clock decided what reached main.
merge_road() {  # prints the reason; 0 = open
  [ "$MERGE_POLICY" = "on" ] || { printf 'closed: merge: off in this machine'"'"'s wardens file'; return 1; }
  case " $ROLES " in
    *" heart "*) ;;
    *) printf 'closed: merge: on, but this machine'"'"'s role is %s — only the heart may merge' "$ROLES"; return 1 ;;
  esac
  [ -x "$ROOT/bin/forge/merge-verdict.sh" ] || { printf 'closed: the gate bin/forge/merge-verdict.sh is not on this tree'; return 1; }
  printf 'open: the heart, through bin/forge/merge-verdict.sh'
  return 0
}

# ── the clock (a user timer; seated only when asked, started only when asked) ────────────────
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
SERVICE="queue-warden.service"; TIMER="queue-warden.timer"
if [ -n "$TIMER_ACTION" ]; then
  case "$TIMER_ACTION" in
    install)
      # the unit is the register's (.agents/config/units.yaml: queue-warden) and the one writer
      # renders it against the PINNED runtime, never the tree this door ran from (plan 269)
      bash "$ROOT/bin/engine/units.sh" write queue-warden --no-restart >/dev/null \
        || { printf 'queue-warden: units.sh could not write the unit\n' >&2; exit 1; }
      systemctl --user daemon-reload 2>/dev/null || true
      # SEATING IS NOT STARTING. A warden's clock is a decision the operator (or the heart) makes
      # for this machine (plan 290 rule 1); `--start` is that decision and nothing else is.
      if [ "$START_TIMER" = 1 ] && [ "$ENABLED" = "on" ]; then
        systemctl --user enable --now "$TIMER" 2>&1 | tail -2 || true
        STARTED="started (--start)"
      else
        systemctl --user disable "$TIMER" >/dev/null 2>&1 || true
        if [ "$ENABLED" = "on" ]; then
          STARTED="seated, stopped — pass --start to run it"
        else
          STARTED="not seated for a clock: enabled is off for this machine"
        fi
      fi
      printf 'timer[4]{unit,interval,state,why}\n  "%s","10min","%s","%s"\n' "$UNIT_DIR/$TIMER" "$STARTED" \
        "$(systemctl --user is-active "$TIMER" 2>/dev/null | head -1 || true)"
      exit 0 ;;
    uninstall)
      systemctl --user disable --now "$TIMER" >/dev/null 2>&1 || true
      rm -f "$UNIT_DIR/$SERVICE" "$UNIT_DIR/$TIMER"
      systemctl --user daemon-reload 2>/dev/null || true
      printf 'timer[2]{unit,state}\n  "%s","removed"\n' "$UNIT_DIR/$TIMER"
      exit 0 ;;
    status)
      printf 'timer[3]{unit,active,enabled}\n  "%s","%s","%s"\n' "$UNIT_DIR/$TIMER" \
        "$(systemctl --user is-active "$TIMER" 2>/dev/null | head -1 || true)" \
        "$(systemctl --user is-enabled "$TIMER" 2>/dev/null | head -1 || true)"
      exit 0 ;;
  esac
fi

timer_state() {
  local a e
  a="$(systemctl --user is-active "$TIMER" 2>/dev/null | head -1 || true)"
  e="$(systemctl --user is-enabled "$TIMER" 2>/dev/null | head -1 || true)"
  printf '%s/%s' "${a:-absent}" "${e:-absent}"
}

MERGE_ROAD="$(merge_road || true)"; MERGE_OPEN=0
merge_road >/dev/null 2>&1 && MERGE_OPEN=1

if [ "$CMD" = "status" ]; then
  printf 'queue-warden[12]{host,role,identity,credential,cap,stale_hours,recut,enabled,policy_from,reader,timer,merge}\n'
  printf '  "%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' "$MACHINE" "$ROLES" "$IDENTITY" "$CREDENTIAL" \
    "$CAP" "$STALE_HOURS" "$([ "$RECUT" = 1 ] && echo on || echo off)" "$ENABLED" \
    "$([ -r "$WARDENS" ] && echo "home/config/machines/$MACHINE/wardens.yaml" || echo defaults)" \
    "$POLICY_READER" "$(timer_state)" "$MERGE_ROAD"
  exit 0
fi

# ── the opt-in: a SCHEDULED pass on a machine that has not opted in refuses, loudly ──────────
# `INVOCATION_ID` is set by systemd and by nothing else, so the door can tell a clock from a hand.
# A hand may always run a pass — that is how a human inspects the queue — and the refusal does not.
if [ "$ENABLED" != "on" ] && [ -n "${INVOCATION_ID:-}" ] && [ "$DRY" = 0 ]; then
  printf 'queue-warden[2]{host,enabled,why}\n'
  printf '  "%s","%s","%s"\n' "$MACHINE" "$ENABLED" "this machine has not opted in (enabled is off in its wardens file) — no clock may run a warden here"
  exit 0
fi

# ── the reading: gh is a LENS here, never a hand ─────────────────────────────────────────────
command -v gh >/dev/null 2>&1 || { printf 'queue-warden: gh missing — a warden that cannot read a PR says nothing\n' >&2; exit 1; }
if [ "$CREDENTIAL" = "machine" ]; then
  export GH_TOKEN="$MACHINE_TOKEN"
fi
if ! gh auth status >/dev/null 2>&1; then
  printf 'queue-warden: no GitHub door on this machine (gh auth status failed) — refusing rather than reporting nothing\n' >&2
  exit 1
fi
READ_AS="$(gh api user -q .login 2>/dev/null || echo unknown)"
[ "$CREDENTIAL" = "machine" ] && READ_AS="$IDENTITY ($READ_AS)"

# ── the notices (append-only; a notice is never a close) ─────────────────────────────────────
NOTICES="$STATE/queue-warden.notices.log"
STATUS="$STATE/queue-warden.status"
mkdir -p "$STATE" 2>/dev/null || true
STAMP_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
notices=()
notice() {  # <pr> <branch> <kind> <action>
  notices+=("$1|$2|$3|$4")
  printf '%s\t%s\t%s\t%s\t%s\n' "$STAMP_ISO" "$1" "$2" "$3" "$4" >>"$NOTICES" 2>/dev/null || true
}

# ── the re-cut: a NEW branch off the PR's head, rebased onto main, never their branch ────────
# A rebase rewrites history, so it is done on a name nobody owns yet. Their branch is read, never
# written: no force, no --no-verify, no `git add -A`. The push happens only under the machine's own
# identity; without one the re-cut is made and the push is recorded as owed.
recut_one() {  # <pr> <branch>
  local n="$1" branch="$2" slug new wt ok=1 err
  slug="$(printf '%s' "$branch" | tr -c 'a-zA-Z0-9._-' '-' | sed -e 's/^-*//' -e 's/-*$//')"
  new="rehygiene/${n}-${slug}-onto-main-$(date -u +%Y%m%d)"
  if git -C "$ROOT" show-ref --verify --quiet "refs/heads/$new"; then
    notice "$n" "$branch" "recut" "already re-cut today as $new"
    return 0
  fi
  if [ "$DRY" = 1 ]; then
    recut_made=$((recut_made + 1))
    notice "$n" "$branch" "recut" "dry-run: would rebase origin/$branch onto origin/main as $new"
    return 0
  fi
  wt="$ROOT/.yggdrasil/qw-recut-$n"
  if [ -e "$wt" ]; then
    notice "$n" "$branch" "recut" "not re-cut — $wt already stands; this warden never clears another hand's tree"
    return 0
  fi
  if ! git -C "$ROOT" fetch origin --prune >/dev/null 2>&1; then
    notice "$n" "$branch" "recut" "not re-cut — origin could not be fetched"
    return 0
  fi
  if ! git -C "$ROOT" worktree add "$wt" --detach "origin/$branch" >/dev/null 2>&1; then
    notice "$n" "$branch" "recut" "not re-cut — the branch could not be seated in a worktree"
    return 0
  fi
  if git -C "$wt" switch -c "$new" >/dev/null 2>&1; then
    if ! err="$(git -C "$wt" rebase origin/main 2>&1)"; then
      git -C "$wt" rebase --abort >/dev/null 2>&1 || true
      ok=0
    fi
  else
    ok=0; err="the new branch could not be cut"
  fi
  git -C "$ROOT" worktree remove --force "$wt" >/dev/null 2>&1 || true
  if [ "$ok" != 1 ]; then
    notice "$n" "$branch" "recut" "not re-cut — two hands disagree in the same file ($(printf '%s' "$err" | grep -m1 -E '^CONFLICT|fatal:|error:' | cut -c1-90))"
    return 0
  fi
  recut_made=$((recut_made + 1))
  if [ "$CREDENTIAL" != "machine" ]; then
    notice "$n" "$branch" "recut" "re-cut locally as $new — push owed: git push origin $new (the home names no machine identity)"
    return 0
  fi
  if err="$(git -C "$ROOT" push origin "refs/heads/$new:refs/heads/$new" 2>&1)"; then
    recut_pushed=$((recut_pushed + 1))
    notice "$n" "$branch" "recut" "re-cut onto main and pushed as $new — open a PR from it when the helm says so"
  else
    notice "$n" "$branch" "recut" "re-cut locally as $new but the push was refused by the wards: $(printf '%s' "$err" | grep -m1 -E 'refus|reject|error|denied' | cut -c1-90)"
  fi
  return 0
}

# ── the merge act: the heart's only, and only through the gate ───────────────────────────────
# Called ONLY when merge_road answered open. The gate is authoritative: a NO is a NO, an "I cannot
# tell" is a NO (merge-verdict exits 2), and nothing here overrides the wards.
merge_one() {  # <pr> <branch>
  local n="$1" branch="$2" flag reason
  if [ -f "$ROOT/bin/forge/merge-method.sh" ]; then
    # shellcheck disable=SC1091
    . "$ROOT/bin/forge/merge-method.sh"
    flag="$(merge_flag_for_pr "$n" 2>/dev/null || true)"
    if type refuse_squash_of_gather >/dev/null 2>&1; then
      refuse_squash_of_gather "$n" "${flag:---squash}" || { notice "$n" "$branch" "merge-refused" "a gathered batch is never squashed"; return 0; }
    fi
  fi
  [ -n "$flag" ] || flag="--squash"
  if [ "$DRY" = 1 ]; then
    notice "$n" "$branch" "merge" "dry-run: the road is open; would ask merge-verdict.sh, then merge with $flag"
    return 0
  fi
  if ! reason="$(bash "$ROOT/bin/forge/merge-verdict.sh" "$n" 2>&1)"; then
    notice "$n" "$branch" "merge-refused" "merge-verdict.sh said NO: $(printf '%s' "$reason" | tail -1 | cut -c1-110)"
    return 0
  fi
  if gh pr merge "$n" "$flag" --delete-branch >/tmp/qw-mergepr-$n.log 2>&1; then
    merges=$((merges + 1))
    notice "$n" "$branch" "merged" "merged with $flag after merge-verdict.sh said yes"
    bash "$ROOT/bin/records/runes-append.sh" engine merge \
      --message "queue-warden merged PR $n on $MACHINE (merge-verdict.sh: yes)" >/dev/null 2>&1 || true
  else
    notice "$n" "$branch" "merge-refused" "gh refused the merge: $(tail -1 /tmp/qw-mergepr-$n.log 2>/dev/null | cut -c1-90)"
  fi
  return 0
}

# ── the open PRs ─────────────────────────────────────────────────────────────────────────────
rows="$(gh pr list --state open --limit 100 \
  --json number,headRefName,createdAt,mergeable,isDraft,author \
  --template '{{range .}}{{.number}}{{"\t"}}{{.headRefName}}{{"\t"}}{{.createdAt}}{{"\t"}}{{.mergeable}}{{"\t"}}{{.isDraft}}{{"\t"}}{{.author.login}}{{"\n"}}{{end}}' 2>/dev/null)" \
  || { printf 'queue-warden: gh pr list failed — nothing read, so nothing claimed\n' >&2; exit 1; }
[ -n "$PR_ONLY" ] && rows="$(printf '%s\n' "$rows" | awk -F'\t' -v n="$PR_ONLY" '$1 == n')"

now_epoch="$(date -u +%s)"
age_hours() {  # <iso>
  local e
  e="$(date -u -d "$1" +%s 2>/dev/null)" || { printf '0'; return; }
  printf '%s' "$(( (now_epoch - e) / 3600 ))"
}

open=0; stale=0; conflicting=0; recut_made=0; recut_pushed=0; merges=0
declare -a order=()
while IFS=$'\t' read -r num branch created mergeable draft author; do
  [ -n "${num:-}" ] || continue
  open=$((open + 1))
  age="$(age_hours "$created")"
  order+=("$age|$num|$branch")
  if [ "$draft" = "true" ]; then
    notice "$num" "$branch" "draft" "left alone — a draft is not asked for"
    continue
  fi
  if [ "$mergeable" = "CONFLICTING" ]; then
    conflicting=$((conflicting + 1))
    case "$branch" in
      main|master|rehygiene/*)
        notice "$num" "$branch" "conflicting" "not re-cut — a protected or already-re-cut branch" ;;
      dependabot/*)
        notice "$num" "$branch" "conflicting" "not re-cut — a bot's branch is the bot's to tend" ;;
      *)
        case "$author" in
          *"[bot]")
            notice "$num" "$branch" "conflicting" "not re-cut — a bot's branch is the bot's to tend" ;;
          *)
            if [ "$RECUT" = 1 ]; then
              recut_one "$num" "$branch"
            else
              notice "$num" "$branch" "conflicting" "re-cut skipped (--no-recut); rebase onto origin/main is owed"
            fi ;;
        esac ;;
    esac
  elif [ "$MERGE_OPEN" = 1 ]; then
    merge_one "$num" "$branch"
  fi
  if [ "$age" -ge "$STALE_HOURS" ]; then
    stale=$((stale + 1))
    notice "$num" "$branch" "stale" "open ${age}h — flagged; the helm decides, this warden never closes"
  fi
done <<<"$rows"

# ── the cap: reported, never enforced by closing another hand's work ─────────────────────────
over=0
[ "$open" -gt "$CAP" ] && over=$((open - CAP))
if [ "$over" -gt 0 ]; then
  while IFS='|' read -r age num branch; do
    [ -n "${num:-}" ] || continue
    notice "$num" "$branch" "over-cap" "open ${age}h — ${over} beyond the cap of ${CAP}; review it, do not merge it blind"
  done < <(printf '%s\n' "${order[@]}" | sort -t'|' -k1,1nr | head -n "$over")
fi

# ── the pass, written down ───────────────────────────────────────────────────────────────────
{
  printf 'stamp\t%s\n' "$STAMP_ISO"
  printf 'host\t%s\n' "$MACHINE"
  printf 'role\t%s\n' "$ROLES"
  printf 'identity\t%s\n' "$IDENTITY"
  printf 'credential\t%s\n' "$CREDENTIAL"
  printf 'read_as\t%s\n' "$READ_AS"
  printf 'enabled\t%s\n' "$ENABLED"
  printf 'policy_from\t%s\n' "$POLICY_READER"
  printf 'cap\t%s\n' "$CAP"
  printf 'open\t%s\n' "$open"
  printf 'merge_road\t%s\n' "$MERGE_ROAD"
  printf 'merges\t%s\n' "$merges"
} >"$STATUS" 2>/dev/null || true

printf 'warden-pass[12]{host,role,read_as,credential,identity,cap,open,over_cap,stale,conflicting,merges,merge_road}\n'
printf '  "%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' "$MACHINE" "$ROLES" "$READ_AS" \
  "$CREDENTIAL" "$IDENTITY" "$CAP" "$open" "$over" "$stale" "$conflicting" "$merges" "$MERGE_ROAD"
if [ "${#notices[@]}" -gt 0 ]; then
  printf 'notice[4]{pr,branch,kind,action}\n'
  for n in "${notices[@]}"; do
    IFS='|' read -r p b k a <<<"$n"
    printf '  "%s","%s","%s","%s"\n' "$p" "$b" "$k" "$a"
  done
fi
printf 'recut[3]{made,pushed_with_machine_identity,notes}\n'
printf '  "%s","%s","%s"\n' "$recut_made" "$recut_pushed" "${#notices[@]}"
[ "$DRY" = 1 ] && printf 'dry-run: nothing written to GitHub, nothing merged, no branch touched\n'
exit 0
